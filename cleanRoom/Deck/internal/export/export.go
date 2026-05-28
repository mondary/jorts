package export

import (
	"Deck/internal/models"
	"encoding/json"
	"fmt"
	"io"
	"os"
)

type ExportItem struct {
	UniqueId       string `json:"uniqueId"`
	PasteboardType string `json:"pasteboardType"`
	ItemType       string `json:"itemType"`
	Data           string `json:"data,omitempty"`
	Timestamp      int64  `json:"timestamp"`
	AppPath        string `json:"appPath"`
	AppName        string `json:"appName"`
	CustomTitle    string `json:"customTitle,omitempty"`
	SearchText     string `json:"searchText"`
	ContentLength  int    `json:"contentLength"`
	TagID          int    `json:"tagId"`
	IsPinned       bool   `json:"isPinned"`
}

type ExportFormat struct {
	Version string       `json:"version"`
	Count   int          `json:"count"`
	Items   []ExportItem `json:"items"`
}

func ExportToFile(items []*models.ClipboardItem, path string) error {
	f, err := os.Create(path)
	if err != nil {
		return fmt.Errorf("failed to create export file: %w", err)
	}
	defer f.Close()

	exportItems := make([]ExportItem, 0, len(items))
	for _, item := range items {
		ei := ExportItem{
			UniqueId:       item.UniqueId,
			PasteboardType: string(item.PasteboardType),
			ItemType:       string(item.ItemType),
			Data:           string(item.Data),
			Timestamp:      item.Timestamp,
			AppPath:        item.AppPath,
			AppName:        item.AppName,
			CustomTitle:    item.CustomTitle,
			SearchText:     item.SearchText,
			ContentLength:  item.ContentLength,
			TagID:          item.TagID,
			IsPinned:       item.TagID == -2,
		}
		exportItems = append(exportItems, ei)
	}

	format := ExportFormat{
		Version: "1.0",
		Count:   len(exportItems),
		Items:   exportItems,
	}

	encoder := json.NewEncoder(f)
	encoder.SetIndent("", "  ")
	return encoder.Encode(format)
}

func ImportFromFile(path string) ([]*models.ClipboardItem, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, fmt.Errorf("failed to open import file: %w", err)
	}
	defer f.Close()

	data, err := io.ReadAll(f)
	if err != nil {
		return nil, err
	}

	var format ExportFormat
	if err := json.Unmarshal(data, &format); err != nil {
		return nil, fmt.Errorf("failed to parse import file: %w", err)
	}

	items := make([]*models.ClipboardItem, 0, format.Count)
	for _, ei := range format.Items {
		item := &models.ClipboardItem{
			UniqueId:       ei.UniqueId,
			PasteboardType: models.PasteboardType(ei.PasteboardType),
			ItemType:       models.ClipItemType(ei.ItemType),
			Data:           []byte(ei.Data),
			Timestamp:      ei.Timestamp,
			AppPath:        ei.AppPath,
			AppName:        ei.AppName,
			CustomTitle:    ei.CustomTitle,
			SearchText:     ei.SearchText,
			ContentLength:  ei.ContentLength,
			TagID:          ei.TagID,
		}
		if ei.IsPinned {
			item.TagID = -2
		}
		items = append(items, item)
	}

	return items, nil
}
