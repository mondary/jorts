package models

import (
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"strings"
	"time"
)

type ClipItemType string

const (
	ClipTypeText     ClipItemType = "text"
	ClipTypeRichText ClipItemType = "richText"
	ClipTypeImage    ClipItemType = "image"
	ClipTypeFile     ClipItemType = "file"
	ClipTypeURL      ClipItemType = "url"
	ClipTypeColor    ClipItemType = "color"
	ClipTypeCode     ClipItemType = "code"
)

type PasteboardType string

const (
	PasteTypeText      PasteboardType = "public.utf8-plain-text"
	PasteTypeHTML      PasteboardType = "public.html"
	PasteTypeRTF       PasteboardType = "public.rtf"
	PasteTypeImagePNG  PasteboardType = "public.png"
	PasteTypeImageTIFF PasteboardType = "public.tiff"
	PasteTypeImageJPEG PasteboardType = "public.jpeg"
	PasteTypeFileURL   PasteboardType = "public.file-url"
	PasteTypeURL       PasteboardType = "public.url"
	PasteTypeColor     PasteboardType = "com.apple.cocoa.pasteboard.promised-file-url"
)

type SourceAnchor struct {
	FilePath   string `json:"filePath"`
	LineNumber int    `json:"lineNumber"`
}

type ClipboardItem struct {
	ID              int64          `json:"id"`
	UniqueId        string         `json:"uniqueId"`
	PasteboardType  PasteboardType `json:"pasteboardType"`
	ItemType        ClipItemType   `json:"itemType"`
	Data            []byte         `json:"-"`
	PreviewData     []byte         `json:"-"`
	BlobPath        string         `json:"blobPath,omitempty"`
	Timestamp       int64          `json:"timestamp"`
	AppPath         string         `json:"appPath"`
	AppName         string         `json:"appName"`
	CustomTitle     string         `json:"customTitle,omitempty"`
	SourceAnchor    *SourceAnchor  `json:"sourceAnchor,omitempty"`
	SearchText      string         `json:"searchText"`
	ContentLength   int            `json:"contentLength"`
	TagID           int            `json:"tagId"`
	IsTemporary     bool           `json:"isTemporary"`
	IsEncrypted     bool           `json:"isEncrypted"`
	ReceivedFromLAN bool           `json:"receivedFromLan"`
}

func (c *ClipboardItem) ComputeUniqueID() string {
	h := sha256.Sum256(c.Data)
	return hex.EncodeToString(h[:])
}

func (c *ClipboardItem) GetDisplayText() string {
	if c.CustomTitle != "" {
		return c.CustomTitle
	}
	text := c.SearchText
	if len(text) > 500 {
		text = text[:500]
	}
	return text
}

func (c *ClipboardItem) GetTimeSince() string {
	t := time.Unix(c.Timestamp, 0)
	d := time.Since(t)
	switch {
	case d.Minutes() < 1:
		return "just now"
	case d.Minutes() < 60:
		return fmt.Sprintf("%.0fm ago", d.Minutes())
	case d.Hours() < 24:
		return fmt.Sprintf("%.0fh ago", d.Hours())
	case d.Hours() < 48:
		return "yesterday"
	default:
		return t.Format("Jan 2")
	}
}

func DetectClipItemType(data string, pasteType PasteboardType) ClipItemType {
	text := strings.TrimSpace(data)
	if text == "" {
		if strings.HasPrefix(string(pasteType), "public.png") ||
			strings.HasPrefix(string(pasteType), "public.tiff") ||
			strings.HasPrefix(string(pasteType), "public.jpeg") {
			return ClipTypeImage
		}
		if pasteType == PasteTypeFileURL {
			return ClipTypeFile
		}
		return ClipTypeText
	}

	if looksLikeColor(text) {
		return ClipTypeColor
	}
	if looksLikeURL(text) {
		return ClipTypeURL
	}
	if looksLikeCode(text) {
		return ClipTypeCode
	}
	if pasteType == PasteTypeHTML || pasteType == PasteTypeRTF {
		return ClipTypeRichText
	}
	return ClipTypeText
}

func looksLikeURL(s string) bool {
	return strings.HasPrefix(s, "http://") || strings.HasPrefix(s, "https://") ||
		strings.HasPrefix(s, "ftp://") || strings.HasPrefix(s, "www.")
}

func looksLikeColor(s string) bool {
	if len(s) == 7 && s[0] == '#' {
		return isHexString(s[1:])
	}
	if len(s) == 4 && s[0] == '#' {
		return isHexString(s[1:])
	}
	return false
}

func isHexString(s string) bool {
	for _, c := range s {
		if !((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')) {
			return false
		}
	}
	return true
}

func looksLikeCode(s string) bool {
	codeIndicators := []string{"func ", "function ", "class ", "import ", "package ", "var ", "const ", "if (", "for (", "while (", "{", "=>", "->", "public ", "private "}
	count := 0
	for _, ind := range codeIndicators {
		if strings.Contains(s, ind) {
			count++
		}
	}
	return count >= 2
}
