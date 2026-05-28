package database

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sync"
	"time"

	"Deck/internal/models"

	_ "github.com/mattn/go-sqlite3"
)

const (
	schemaVersion = 5
	busyTimeout   = 5000
	mmapSize      = 134217728
	queryTimeout  = 30 * time.Second
)

type DB struct {
	db     *sql.DB
	dbPath string
	mu     sync.RWMutex
	closed bool
}

func NewDB(dbPath string) (*DB, error) {
	dir := filepath.Dir(dbPath)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return nil, fmt.Errorf("create db directory: %w", err)
	}

	dsn := fmt.Sprintf("%s?_busy_timeout=%d", dbPath, busyTimeout)
	db, err := sql.Open("sqlite3", dsn)
	if err != nil {
		return nil, fmt.Errorf("open database: %w", err)
	}

	db.SetMaxOpenConns(1)

	ctx, cancel := context.WithTimeout(context.Background(), queryTimeout)
	defer cancel()

	pragmas := []string{
		"PRAGMA journal_mode=WAL",
		"PRAGMA synchronous=NORMAL",
		"PRAGMA mmap_size=134217728",
		"PRAGMA cache_size=-2000",
		"PRAGMA foreign_keys=ON",
		"PRAGMA temp_store=MEMORY",
	}
	for _, p := range pragmas {
		if _, err := db.ExecContext(ctx, p); err != nil {
			db.Close()
			return nil, fmt.Errorf("set pragma %q: %w", p, err)
		}
	}

	d := &DB{db: db, dbPath: dbPath}

	if err := d.runMigrations(ctx); err != nil {
		db.Close()
		return nil, fmt.Errorf("run migrations: %w", err)
	}

	return d, nil
}

func (d *DB) Close() error {
	d.mu.Lock()
	defer d.mu.Unlock()
	if d.closed {
		return nil
	}
	d.closed = true
	return d.db.Close()
}

func (d *DB) runMigrations(ctx context.Context) error {
	var currentVersion int
	if err := d.db.QueryRowContext(ctx, "PRAGMA user_version").Scan(&currentVersion); err != nil {
		return fmt.Errorf("read user_version: %w", err)
	}

	if currentVersion >= schemaVersion {
		return nil
	}

	type migration struct {
		version int
		stmts   []string
	}

	migrations := []migration{
		{
			1,
			[]string{
				`CREATE TABLE IF NOT EXISTS ClipboardHistory (
					id INTEGER PRIMARY KEY AUTOINCREMENT,
					unique_id TEXT NOT NULL,
					type TEXT NOT NULL,
					item_type TEXT NOT NULL DEFAULT 'text',
					data BLOB,
					timestamp INTEGER NOT NULL,
					app_path TEXT DEFAULT '',
					app_name TEXT DEFAULT '',
					custom_title TEXT DEFAULT '',
					search_text TEXT DEFAULT '',
					tag_id INTEGER DEFAULT -1,
					UNIQUE(unique_id)
				)`,
			},
		},
		{
			2,
			[]string{
				`CREATE VIRTUAL TABLE IF NOT EXISTS ClipboardHistory_fts USING fts5(
					search_text, app_name, custom_title,
					content=ClipboardHistory, content_rowid=id
				)`,
			},
		},
		{
			3,
			[]string{
				`CREATE TRIGGER IF NOT EXISTS ClipboardHistory_ai AFTER INSERT ON ClipboardHistory BEGIN
					INSERT INTO ClipboardHistory_fts(rowid, search_text, app_name, custom_title)
					VALUES (new.id, new.search_text, new.app_name, new.custom_title);
				END`,
				`CREATE TRIGGER IF NOT EXISTS ClipboardHistory_ad AFTER DELETE ON ClipboardHistory BEGIN
					INSERT INTO ClipboardHistory_fts(ClipboardHistory_fts, rowid, search_text, app_name, custom_title)
					VALUES('delete', old.id, old.search_text, old.app_name, old.custom_title);
				END`,
				`CREATE TRIGGER IF NOT EXISTS ClipboardHistory_au AFTER UPDATE ON ClipboardHistory BEGIN
					INSERT INTO ClipboardHistory_fts(ClipboardHistory_fts, rowid, search_text, app_name, custom_title)
					VALUES('delete', old.id, old.search_text, old.app_name, old.custom_title);
					INSERT INTO ClipboardHistory_fts(rowid, search_text, app_name, custom_title)
					VALUES (new.id, new.search_text, new.app_name, new.custom_title);
				END`,
				`INSERT INTO ClipboardHistory_fts(ClipboardHistory_fts) VALUES('rebuild')`,
			},
		},
		{
			4,
			[]string{
				`ALTER TABLE ClipboardHistory ADD COLUMN blob_path TEXT DEFAULT ''`,
				`ALTER TABLE ClipboardHistory ADD COLUMN is_temporary INTEGER DEFAULT 0`,
				`ALTER TABLE ClipboardHistory ADD COLUMN is_encrypted INTEGER DEFAULT 0`,
			},
		},
		{
			5,
			[]string{
				`ALTER TABLE ClipboardHistory ADD COLUMN preview_data BLOB`,
				`ALTER TABLE ClipboardHistory ADD COLUMN source_anchor TEXT DEFAULT ''`,
				`ALTER TABLE ClipboardHistory ADD COLUMN content_length INTEGER DEFAULT 0`,
				`ALTER TABLE ClipboardHistory ADD COLUMN received_from_lan INTEGER DEFAULT 0`,
			},
		},
	}

	tx, err := d.db.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("begin migration tx: %w", err)
	}
	defer tx.Rollback()

	for _, m := range migrations {
		if m.version <= currentVersion {
			continue
		}
		for _, stmt := range m.stmts {
			if _, err := tx.ExecContext(ctx, stmt); err != nil {
				return fmt.Errorf("migration v%d: %w", m.version, err)
			}
		}
		if _, err := tx.ExecContext(ctx, fmt.Sprintf("PRAGMA user_version = %d", m.version)); err != nil {
			return fmt.Errorf("set user_version %d: %w", m.version, err)
		}
	}

	return tx.Commit()
}

func (d *DB) InsertItem(item *models.ClipboardItem) (int64, error) {
	d.mu.Lock()
	defer d.mu.Unlock()

	ctx, cancel := context.WithTimeout(context.Background(), queryTimeout)
	defer cancel()

	sourceAnchor := "{}"
	if item.SourceAnchor != nil {
		b, err := json.Marshal(item.SourceAnchor)
		if err == nil {
			sourceAnchor = string(b)
		}
	}

	var id int64
	err := d.db.QueryRowContext(ctx, `
		INSERT INTO ClipboardHistory (
			unique_id, type, item_type, data, preview_data, timestamp,
			app_path, app_name, custom_title, source_anchor, search_text,
			content_length, tag_id, blob_path, is_temporary, is_encrypted, received_from_lan
		) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
		ON CONFLICT(unique_id) DO UPDATE SET
			type=excluded.type,
			item_type=excluded.item_type,
			data=excluded.data,
			preview_data=excluded.preview_data,
			timestamp=excluded.timestamp,
			app_path=excluded.app_path,
			app_name=excluded.app_name,
			source_anchor=excluded.source_anchor,
			search_text=excluded.search_text,
			content_length=excluded.content_length,
			blob_path=excluded.blob_path,
			is_temporary=excluded.is_temporary,
			is_encrypted=excluded.is_encrypted,
			received_from_lan=excluded.received_from_lan
		RETURNING id`,
		item.UniqueId, string(item.PasteboardType), string(item.ItemType), item.Data,
		item.PreviewData, item.Timestamp, item.AppPath, item.AppName, item.CustomTitle,
		sourceAnchor, item.SearchText, item.ContentLength, item.TagID, item.BlobPath,
		boolToInt(item.IsTemporary), boolToInt(item.IsEncrypted), boolToInt(item.ReceivedFromLAN),
	).Scan(&id)
	if err != nil {
		return 0, fmt.Errorf("insert item: %w", err)
	}
	return id, nil
}

func (d *DB) GetItems(offset, limit int, tagID int) ([]*models.ClipboardItem, error) {
	d.mu.RLock()
	defer d.mu.RUnlock()

	ctx, cancel := context.WithTimeout(context.Background(), queryTimeout)
	defer cancel()

	query := `SELECT id, unique_id, type, item_type, data, preview_data, timestamp,
		app_path, app_name, custom_title, source_anchor, search_text,
		content_length, tag_id, blob_path, is_temporary, is_encrypted, received_from_lan
		FROM ClipboardHistory`
	args := []any{}

	if tagID != 0 {
		query += " WHERE tag_id = ?"
		args = append(args, tagID)
	}

	query += " ORDER BY timestamp DESC LIMIT ? OFFSET ?"
	args = append(args, limit, offset)

	rows, err := d.db.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("get items: %w", err)
	}
	defer rows.Close()

	return scanItems(rows)
}

func (d *DB) GetItemByID(id int64) (*models.ClipboardItem, error) {
	d.mu.RLock()
	defer d.mu.RUnlock()

	ctx, cancel := context.WithTimeout(context.Background(), queryTimeout)
	defer cancel()

	row := d.db.QueryRowContext(ctx, `
		SELECT id, unique_id, type, item_type, data, preview_data, timestamp,
		app_path, app_name, custom_title, source_anchor, search_text,
		content_length, tag_id, blob_path, is_temporary, is_encrypted, received_from_lan
		FROM ClipboardHistory WHERE id = ?`, id)

	return scanItem(row)
}

func (d *DB) DeleteItem(id int64) error {
	d.mu.Lock()
	defer d.mu.Unlock()

	ctx, cancel := context.WithTimeout(context.Background(), queryTimeout)
	defer cancel()

	_, err := d.db.ExecContext(ctx, "DELETE FROM ClipboardHistory WHERE id = ?", id)
	if err != nil {
		return fmt.Errorf("delete item: %w", err)
	}
	return nil
}

func (d *DB) DeleteAllItems() error {
	d.mu.Lock()
	defer d.mu.Unlock()

	ctx, cancel := context.WithTimeout(context.Background(), queryTimeout)
	defer cancel()

	tx, err := d.db.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("begin delete all tx: %w", err)
	}
	defer tx.Rollback()

	if _, err := tx.ExecContext(ctx, "DELETE FROM ClipboardHistory"); err != nil {
		return fmt.Errorf("delete all items: %w", err)
	}
	if _, err := tx.ExecContext(ctx, "INSERT INTO ClipboardHistory_fts(ClipboardHistory_fts) VALUES('rebuild')"); err != nil {
		return fmt.Errorf("rebuild fts: %w", err)
	}

	return tx.Commit()
}

func (d *DB) SearchItems(query string, limit int) ([]*models.ClipboardItem, error) {
	d.mu.RLock()
	defer d.mu.RUnlock()

	ctx, cancel := context.WithTimeout(context.Background(), queryTimeout)
	defer cancel()

	items, err := d.searchFTS(ctx, query, limit)
	if err != nil {
		return d.searchItemsLike(ctx, query, limit)
	}
	return items, nil
}

func (d *DB) searchFTS(ctx context.Context, query string, limit int) ([]*models.ClipboardItem, error) {
	rows, err := d.db.QueryContext(ctx, `
		SELECT ch.id, ch.unique_id, ch.type, ch.item_type, ch.data, ch.preview_data, ch.timestamp,
			ch.app_path, ch.app_name, ch.custom_title, ch.source_anchor, ch.search_text,
			ch.content_length, ch.tag_id, ch.blob_path, ch.is_temporary, ch.is_encrypted, ch.received_from_lan
		FROM ClipboardHistory_fts fts
		JOIN ClipboardHistory ch ON ch.id = fts.rowid
		WHERE ClipboardHistory_fts MATCH ?
		ORDER BY ch.timestamp DESC
		LIMIT ?`,
		query, limit,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	return scanItems(rows)
}

func (d *DB) searchItemsLike(ctx context.Context, query string, limit int) ([]*models.ClipboardItem, error) {
	pattern := "%" + query + "%"

	rows, err := d.db.QueryContext(ctx, `
		SELECT id, unique_id, type, item_type, data, preview_data, timestamp,
			app_path, app_name, custom_title, source_anchor, search_text,
			content_length, tag_id, blob_path, is_temporary, is_encrypted, received_from_lan
		FROM ClipboardHistory
		WHERE search_text LIKE ? OR app_name LIKE ? OR custom_title LIKE ?
		ORDER BY timestamp DESC
		LIMIT ?`,
		pattern, pattern, pattern, limit,
	)
	if err != nil {
		return nil, fmt.Errorf("search items like: %w", err)
	}
	defer rows.Close()

	return scanItems(rows)
}

func (d *DB) UpdateCustomTitle(id int64, title string) error {
	d.mu.Lock()
	defer d.mu.Unlock()

	ctx, cancel := context.WithTimeout(context.Background(), queryTimeout)
	defer cancel()

	_, err := d.db.ExecContext(ctx,
		"UPDATE ClipboardHistory SET custom_title = ? WHERE id = ?",
		title, id,
	)
	if err != nil {
		return fmt.Errorf("update custom title: %w", err)
	}
	return nil
}

func (d *DB) UpdateTagID(id int64, tagID int) error {
	d.mu.Lock()
	defer d.mu.Unlock()

	ctx, cancel := context.WithTimeout(context.Background(), queryTimeout)
	defer cancel()

	_, err := d.db.ExecContext(ctx,
		"UPDATE ClipboardHistory SET tag_id = ? WHERE id = ?",
		tagID, id,
	)
	if err != nil {
		return fmt.Errorf("update tag id: %w", err)
	}
	return nil
}

func (d *DB) GetItemCount() (int, error) {
	d.mu.RLock()
	defer d.mu.RUnlock()

	ctx, cancel := context.WithTimeout(context.Background(), queryTimeout)
	defer cancel()

	var count int
	err := d.db.QueryRowContext(ctx, "SELECT COUNT(*) FROM ClipboardHistory").Scan(&count)
	if err != nil {
		return 0, fmt.Errorf("get item count: %w", err)
	}
	return count, nil
}

func (d *DB) TogglePin(id int64) error {
	d.mu.Lock()
	defer d.mu.Unlock()

	ctx, cancel := context.WithTimeout(context.Background(), queryTimeout)
	defer cancel()

	_, err := d.db.ExecContext(ctx,
		"UPDATE ClipboardHistory SET tag_id = CASE WHEN tag_id = -2 THEN -1 ELSE -2 END WHERE id = ?",
		id,
	)
	if err != nil {
		return fmt.Errorf("toggle pin: %w", err)
	}
	return nil
}

func (d *DB) GetItemsByType(itemType models.ClipItemType, offset, limit int) ([]*models.ClipboardItem, error) {
	d.mu.RLock()
	defer d.mu.RUnlock()

	ctx, cancel := context.WithTimeout(context.Background(), queryTimeout)
	defer cancel()

	rows, err := d.db.QueryContext(ctx, `
		SELECT id, unique_id, type, item_type, data, preview_data, timestamp,
			app_path, app_name, custom_title, source_anchor, search_text,
			content_length, tag_id, blob_path, is_temporary, is_encrypted, received_from_lan
		FROM ClipboardHistory
		WHERE item_type = ?
		ORDER BY timestamp DESC
		LIMIT ? OFFSET ?`,
		string(itemType), limit, offset,
	)
	if err != nil {
		return nil, fmt.Errorf("get items by type: %w", err)
	}
	defer rows.Close()

	return scanItems(rows)
}

func (d *DB) Backup() error {
	d.mu.Lock()
	defer d.mu.Unlock()

	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	if _, err := d.db.ExecContext(ctx, "PRAGMA wal_checkpoint(TRUNCATE)"); err != nil {
		return fmt.Errorf("checkpoint for backup: %w", err)
	}

	src, err := os.Open(d.dbPath)
	if err != nil {
		return fmt.Errorf("open db for backup: %w", err)
	}
	defer src.Close()

	bakPath := d.dbPath + ".bak"
	dst, err := os.Create(bakPath)
	if err != nil {
		return fmt.Errorf("create backup file: %w", err)
	}
	defer dst.Close()

	if _, err := io.Copy(dst, src); err != nil {
		os.Remove(bakPath)
		return fmt.Errorf("copy db for backup: %w", err)
	}

	return dst.Sync()
}

func (d *DB) CheckIntegrity() error {
	d.mu.RLock()
	defer d.mu.RUnlock()

	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	var result string
	err := d.db.QueryRowContext(ctx, "PRAGMA integrity_check").Scan(&result)
	if err != nil {
		return fmt.Errorf("integrity check: %w", err)
	}
	if result != "ok" {
		return fmt.Errorf("integrity check failed: %s", result)
	}
	return nil
}

func scanItem(row *sql.Row) (*models.ClipboardItem, error) {
	var item models.ClipboardItem
	var pasteboardType, itemType, sourceAnchor string
	var isTemporary, isEncrypted, receivedFromLAN int

	err := row.Scan(
		&item.ID, &item.UniqueId, &pasteboardType, &itemType,
		&item.Data, &item.PreviewData, &item.Timestamp,
		&item.AppPath, &item.AppName, &item.CustomTitle, &sourceAnchor,
		&item.SearchText, &item.ContentLength, &item.TagID, &item.BlobPath,
		&isTemporary, &isEncrypted, &receivedFromLAN,
	)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, nil
		}
		return nil, fmt.Errorf("scan item: %w", err)
	}

	item.PasteboardType = models.PasteboardType(pasteboardType)
	item.ItemType = models.ClipItemType(itemType)
	item.IsTemporary = isTemporary != 0
	item.IsEncrypted = isEncrypted != 0
	item.ReceivedFromLAN = receivedFromLAN != 0

	if sourceAnchor != "" && sourceAnchor != "{}" {
		var anchor models.SourceAnchor
		if json.Unmarshal([]byte(sourceAnchor), &anchor) == nil {
			item.SourceAnchor = &anchor
		}
	}

	return &item, nil
}

func scanItems(rows *sql.Rows) ([]*models.ClipboardItem, error) {
	var items []*models.ClipboardItem

	for rows.Next() {
		var item models.ClipboardItem
		var pasteboardType, itemType, sourceAnchor string
		var isTemporary, isEncrypted, receivedFromLAN int

		err := rows.Scan(
			&item.ID, &item.UniqueId, &pasteboardType, &itemType,
			&item.Data, &item.PreviewData, &item.Timestamp,
			&item.AppPath, &item.AppName, &item.CustomTitle, &sourceAnchor,
			&item.SearchText, &item.ContentLength, &item.TagID, &item.BlobPath,
			&isTemporary, &isEncrypted, &receivedFromLAN,
		)
		if err != nil {
			return nil, fmt.Errorf("scan item row: %w", err)
		}

		item.PasteboardType = models.PasteboardType(pasteboardType)
		item.ItemType = models.ClipItemType(itemType)
		item.IsTemporary = isTemporary != 0
		item.IsEncrypted = isEncrypted != 0
		item.ReceivedFromLAN = receivedFromLAN != 0

		if sourceAnchor != "" && sourceAnchor != "{}" {
			var anchor models.SourceAnchor
			if json.Unmarshal([]byte(sourceAnchor), &anchor) == nil {
				item.SourceAnchor = &anchor
			}
		}

		items = append(items, &item)
	}

	return items, rows.Err()
}

func boolToInt(b bool) int {
	if b {
		return 1
	}
	return 0
}
