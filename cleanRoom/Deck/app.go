package main

import (
	"Deck/internal/clipboard"
	"Deck/internal/database"
	"Deck/internal/export"
	"Deck/internal/hotkey"
	"Deck/internal/logger"
	"Deck/internal/models"
	"Deck/internal/security"
	"Deck/internal/smart"
	"Deck/internal/transform"
	"context"
	"encoding/base64"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/wailsapp/wails/v2/pkg/runtime"
)

type App struct {
	ctx         context.Context
	db          *database.DB
	monitor     *clipboard.Monitor
	hotkey      *hotkey.Hotkey
	paused      bool
	panelVisible bool
}

func NewApp() *App {
	return &App{}
}

func (a *App) startup(ctx context.Context) {
	a.ctx = ctx

	home, _ := os.UserHomeDir()
	dataDir := filepath.Join(home, "Library", "Application Support", "Deck")
	os.MkdirAll(dataDir, 0755)

	logDir := filepath.Join(dataDir, "Logs")
	logger.Init(logDir, logger.INFO)
	logger.Info("Deck starting up...")

	security.Init(dataDir)

	dbPath := filepath.Join(dataDir, "Deck.sqlite3")
	db, err := database.NewDB(dbPath)
	if err != nil {
		logger.Error("Failed to open database: %v", err)
		return
	}
	a.db = db
	logger.Info("Database opened at %s", dbPath)

	a.monitor = clipboard.NewMonitor(500 * time.Millisecond)
	a.monitor.SetOnChange(func(item *models.ClipboardItem) {
		sensitive := security.CheckSensitiveData(item.SearchText)
		if sensitive.IsCreditCard {
			logger.Info("Skipping sensitive data (credit card)")
			return
		}

		if len(item.Data) > 512*1024 {
			blobDir := filepath.Join(dataDir, "blobs")
			os.MkdirAll(blobDir, 0755)
			blobPath := filepath.Join(blobDir, item.UniqueId)
			os.WriteFile(blobPath, item.Data, 0644)
			item.BlobPath = blobPath
		}

		id, err := a.db.InsertItem(item)
		if err != nil {
			logger.Error("Failed to insert clipboard item: %v", err)
			return
		}
		logger.Info("Captured clipboard item %d (type: %s, app: %s)", id, item.ItemType, item.AppName)

		runtime.EventsEmit(a.ctx, "clipboard:added", map[string]interface{}{
			"id":        id,
			"itemType":  string(item.ItemType),
			"appName":   item.AppName,
			"preview":   item.GetDisplayText(),
			"timestamp": item.Timestamp,
		})
	})
	a.monitor.Start()
	logger.Info("Clipboard monitor started")

	a.hotkey = hotkey.New(hotkey.KeyP, hotkey.KeyCMD)
	a.hotkey.Register(func() {
		a.TogglePanel()
	})
	logger.Info("Global hotkey Cmd+P registered")
}

func (a *App) shutdown(ctx context.Context) {
	if a.monitor != nil {
		a.monitor.Stop()
	}
	if a.hotkey != nil {
		a.hotkey.Unregister()
	}
	if a.db != nil {
		a.db.Close()
	}
	logger.Info("Deck shut down")
}

func (a *App) TogglePanel() {
	if a.panelVisible {
		runtime.WindowHide(a.ctx)
		a.panelVisible = false
	} else {
		runtime.WindowShow(a.ctx)
		a.panelVisible = true
	}
}

func (a *App) GetClipboardItems(offset, limit int) ([]map[string]interface{}, error) {
	items, err := a.db.GetItems(offset, limit, -1)
	if err != nil {
		return nil, err
	}
	return a.itemsToJSON(items), nil
}

func (a *App) GetClipboardItemsByType(itemType string, offset, limit int) ([]map[string]interface{}, error) {
	items, err := a.db.GetItemsByType(models.ClipItemType(itemType), offset, limit)
	if err != nil {
		return nil, err
	}
	return a.itemsToJSON(items), nil
}

func (a *App) GetClipboardItemsByTag(tagID, offset, limit int) ([]map[string]interface{}, error) {
	items, err := a.db.GetItems(offset, limit, tagID)
	if err != nil {
		return nil, err
	}
	return a.itemsToJSON(items), nil
}

func (a *App) SearchClipboard(query string) ([]map[string]interface{}, error) {
	items, err := a.db.SearchItems(query, 50)
	if err != nil {
		return nil, err
	}
	return a.itemsToJSON(items), nil
}

func (a *App) GetClipboardItem(id int64) (map[string]interface{}, error) {
	item, err := a.db.GetItemByID(id)
	if err != nil {
		return nil, err
	}
	if item == nil {
		return nil, fmt.Errorf("item not found")
	}
	return a.itemToJSON(item), nil
}

func (a *App) GetItemData(id int64) (string, error) {
	item, err := a.db.GetItemByID(id)
	if err != nil || item == nil {
		return "", fmt.Errorf("item not found")
	}

	if item.ItemType == models.ClipTypeImage {
		var data []byte
		if item.BlobPath != "" {
			data, _ = os.ReadFile(item.BlobPath)
		} else {
			data = item.Data
		}
		if len(data) > 0 {
			mimeType := "image/png"
			return "data:" + mimeType + ";base64," + base64.StdEncoding.EncodeToString(data), nil
		}
		return "", nil
	}

	return string(item.Data), nil
}

func (a *App) DeleteItem(id int64) error {
	return a.db.DeleteItem(id)
}

func (a *App) DeleteAllItems() error {
	return a.db.DeleteAllItems()
}

func (a *App) PasteItem(id int64) error {
	item, err := a.db.GetItemByID(id)
	if err != nil || item == nil {
		return fmt.Errorf("item not found")
	}

	if item.ItemType == models.ClipTypeImage {
		var data []byte
		if item.BlobPath != "" {
			data, _ = os.ReadFile(item.BlobPath)
		} else {
			data = item.Data
		}
		if len(data) > 0 {
			clipboard.WriteClipboardImage(data)
		}
	} else {
		text := string(item.Data)
		clipboard.WriteClipboard(text)
	}

	a.panelVisible = false
	runtime.WindowHide(a.ctx)

	time.Sleep(100 * time.Millisecond)
	clipboard.SimulatePaste()

	return nil
}

func (a *App) PasteItemAsPlainText(id int64) error {
	item, err := a.db.GetItemByID(id)
	if err != nil || item == nil {
		return fmt.Errorf("item not found")
	}

	clipboard.WriteClipboard(item.SearchText)

	a.panelVisible = false
	runtime.WindowHide(a.ctx)

	time.Sleep(100 * time.Millisecond)
	clipboard.SimulatePaste()

	return nil
}

func (a *App) UpdateCustomTitle(id int64, title string) error {
	return a.db.UpdateCustomTitle(id, title)
}

func (a *App) UpdateTagID(id int64, tagID int) error {
	return a.db.UpdateTagID(id, tagID)
}

func (a *App) TogglePin(id int64) error {
	return a.db.TogglePin(id)
}

func (a *App) GetItemCount() (int, error) {
	return a.db.GetItemCount()
}

func (a *App) ApplyTransform(code string, text string) (string, error) {
	return transform.Apply(transform.TransformCode(code), text)
}

func (a *App) GetTransforms() []map[string]interface{} {
	result := make([]map[string]interface{}, len(transform.Transforms))
	for i, t := range transform.Transforms {
		result[i] = map[string]interface{}{
			"code":        string(t.Code),
			"name":        t.Name,
			"description": t.Description,
		}
	}
	return result
}

func (a *App) DetectContent(text string) map[string]interface{} {
	ct := smart.Detect(text)
	return map[string]interface{}{
		"isEmail":    ct.IsEmail,
		"isURL":      ct.IsURL,
		"isPhone":    ct.IsPhone,
		"isCode":     ct.IsCode,
		"isJWT":      ct.IsJWT,
		"isBase64":   ct.IsBase64,
		"isJSON":     ct.IsJSON,
		"isMath":     ct.IsMath,
		"isMarkdown": ct.IsMarkdown,
		"language":   ct.Language,
	}
}

func (a *App) ExportData(path string) error {
	items, err := a.db.GetItems(0, 100000, -1)
	if err != nil {
		return err
	}
	return export.ExportToFile(items, path)
}

func (a *App) ImportData(path string) error {
	items, err := export.ImportFromFile(path)
	if err != nil {
		return err
	}
	for _, item := range items {
		item.UniqueId = item.ComputeUniqueID()
		_, err := a.db.InsertItem(item)
		if err != nil {
			logger.Warn("Failed to import item: %v", err)
		}
	}
	return nil
}

func (a *App) SetPaused(paused bool) {
	a.paused = paused
	if paused {
		a.monitor.Pause()
	} else {
		a.monitor.Resume()
	}
}

func (a *App) IsPaused() bool {
	return a.paused
}

func (a *App) SetSecurityEnabled(enabled bool) {
	security.Default.SetEnabled(enabled)
}

func (a *App) IsSecurityEnabled() bool {
	return security.Default.IsEnabled()
}

func (a *App) CopyTextToClipboard(text string) {
	clipboard.WriteClipboard(text)
}

func (a *App) GetTags() []map[string]interface{} {
	tags := models.SystemTags
	result := make([]map[string]interface{}, len(tags))
	for i, t := range tags {
		result[i] = map[string]interface{}{
			"id":         t.ID,
			"name":       t.Name,
			"colorIndex": t.ColorIndex,
			"isSystem":   t.IsSystem,
		}
	}
	return result
}

func (a *App) GetSystemInfo() map[string]interface{} {
	count, _ := a.db.GetItemCount()
	return map[string]interface{}{
		"version":          "1.0.0",
		"itemCount":        count,
		"isPaused":         a.paused,
		"securityEnabled":  security.Default.IsEnabled(),
	}
}

func (a *App) itemsToJSON(items []*models.ClipboardItem) []map[string]interface{} {
	result := make([]map[string]interface{}, len(items))
	for i, item := range items {
		result[i] = a.itemToJSON(item)
	}
	return result
}

func (a *App) itemToJSON(item *models.ClipboardItem) map[string]interface{} {
	m := map[string]interface{}{
		"id":               item.ID,
		"uniqueId":         item.UniqueId,
		"pasteboardType":   string(item.PasteboardType),
		"itemType":         string(item.ItemType),
		"timestamp":        item.Timestamp,
		"appPath":          item.AppPath,
		"appName":          item.AppName,
		"customTitle":      item.CustomTitle,
		"searchText":       item.SearchText,
		"contentLength":    item.ContentLength,
		"tagId":            item.TagID,
		"isPinned":         item.TagID == -2,
		"isTemporary":      item.IsTemporary,
		"receivedFromLan":  item.ReceivedFromLAN,
		"displayText":      item.GetDisplayText(),
		"timeSince":        item.GetTimeSince(),
	}

	if item.ItemType == models.ClipTypeColor && len(item.Data) > 0 {
		m["colorValue"] = strings.TrimSpace(string(item.Data))
	}

	if item.ItemType == models.ClipTypeURL {
		m["urlValue"] = strings.TrimSpace(string(item.Data))
	}

	return m
}
