package clipboard

import (
	"Deck/internal/models"
	"sync"
	"time"
)

type Monitor struct {
	lastChangeCount int64
	interval        time.Duration
	onChange        func(*models.ClipboardItem)
	stopCh          chan struct{}
	mu              sync.Mutex
	running         bool
	paused          bool
}

func NewMonitor(interval time.Duration) *Monitor {
	return &Monitor{
		interval: interval,
		stopCh:   make(chan struct{}),
	}
}

func (m *Monitor) SetOnChange(fn func(*models.ClipboardItem)) {
	m.onChange = fn
}

func (m *Monitor) Start() {
	m.mu.Lock()
	if m.running {
		m.mu.Unlock()
		return
	}
	m.running = true
	m.lastChangeCount = GetChangeCount()
	m.mu.Unlock()

	go m.poll()
}

func (m *Monitor) Stop() {
	m.mu.Lock()
	defer m.mu.Unlock()
	if !m.running {
		return
	}
	m.running = false
	close(m.stopCh)
}

func (m *Monitor) Pause() {
	m.mu.Lock()
	m.paused = true
	m.mu.Unlock()
}

func (m *Monitor) Resume() {
	m.mu.Lock()
	m.paused = false
	m.lastChangeCount = GetChangeCount()
	m.mu.Unlock()
}

func (m *Monitor) poll() {
	ticker := time.NewTicker(m.interval)
	defer ticker.Stop()

	for {
		select {
		case <-m.stopCh:
			return
		case <-ticker.C:
			m.mu.Lock()
			if m.paused {
				m.mu.Unlock()
				continue
			}
			m.mu.Unlock()

			count := GetChangeCount()
			if count != m.lastChangeCount {
				m.lastChangeCount = count
				item := m.captureItem()
				if item != nil && m.onChange != nil {
					m.onChange(item)
				}
			}
		}
	}
}

func (m *Monitor) captureItem() *models.ClipboardItem {
	_, appName, appPath := GetFrontmostApp()

	text := GetStringData()

	var itemType models.ClipItemType
	var pasteType models.PasteboardType
	var data []byte
	var searchText string

	if HasImageData() {
		imgData := GetImageData()
		if len(imgData) > 0 {
			itemType = models.ClipTypeImage
			pasteType = models.PasteTypeImagePNG
			data = imgData
			searchText = "[Image]"
		}
	} else if fileURL := GetFileURLData(); fileURL != "" {
		itemType = models.ClipTypeFile
		pasteType = models.PasteTypeFileURL
		data = []byte(fileURL)
		searchText = fileURL
	} else if text != "" {
		pasteType = models.PasteTypeText
		data = []byte(text)
		searchText = text
		itemType = models.DetectClipItemType(text, models.PasteTypeText)
	} else {
		return nil
	}

	if len(data) == 0 {
		return nil
	}

	item := &models.ClipboardItem{
		PasteboardType: pasteType,
		ItemType:       itemType,
		Data:           data,
		SearchText:     searchText,
		ContentLength:  len(searchText),
		Timestamp:      time.Now().Unix(),
		AppPath:        appPath,
		AppName:        appName,
		TagID:          -1,
	}
	item.UniqueId = item.ComputeUniqueID()

	return item
}
