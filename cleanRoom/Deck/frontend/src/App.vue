<script setup lang="ts">
import { ref, onMounted, onUnmounted, computed, nextTick } from 'vue'
import {
  GetClipboardItems, SearchClipboard, PasteItem, PasteItemAsPlainText,
  DeleteItem, DeleteAllItems, TogglePin, GetItemCount, SetPaused, IsPaused,
  GetClipboardItemsByType, GetClipboardItemsByTag, GetItemData,
  UpdateCustomTitle, ApplyTransform, GetTransforms, GetTags
} from '../wailsjs/go/main/App'
import { EventsOn } from '../wailsjs/runtime/runtime'

const items = ref<any[]>([])
const selectedId = ref<number | null>(null)
const searchQuery = ref('')
const activeTag = ref<number>(1)
const isPaused = ref(false)
const showPreview = ref(false)
const previewData = ref<string>('')
const transforms = ref<any[]>([])
const tags = ref<any[]>([])
const itemCount = ref(0)
const listRef = ref<HTMLElement | null>(null)
const queueMode = ref(false)
const queueItems = ref<number[]>([])

const selectedItem = computed(() => items.value.find(i => i.id === selectedId.value))

const tagColors: Record<number, string> = {
  1: '#636366',
  2: '#007AFF',
  3: '#30D158',
  4: '#BF5AF2',
  '-2': '#FF453A',
}

const typeIcons: Record<string, string> = {
  text: 'T',
  richText: 'Aa',
  image: '🖼',
  file: '📁',
  url: '🔗',
  color: '🎨',
  code: '</>',
}

const cardSize = 200
const cardHeaderSize = 40
const cardContentSize = 150
const cardSpace = 16
const panelCornerRadius = 28
const topBarHeight = 44

async function loadItems() {
  try {
    let result: any[]
    if (searchQuery.value) {
      result = await SearchClipboard(searchQuery.value) as any
    } else if (activeTag.value === -2) {
      result = await GetClipboardItemsByTag(-2, 0, 100) as any
    } else if (activeTag.value > 1 && activeTag.value <= 4) {
      const typeMap: Record<number, string> = { 2: 'text', 3: 'image', 4: 'file' }
      result = await GetClipboardItemsByType(typeMap[activeTag.value], 0, 100) as any
    } else {
      result = await GetClipboardItems(0, 100) as any
    }
    items.value = result || []
    if (items.value.length > 0 && !selectedId.value) {
      selectItem(items.value[0].id)
    }
    updateCount()
  } catch (e) {
    console.error('loadItems:', e)
  }
}

async function updateCount() {
  try { itemCount.value = await GetItemCount() as any } catch {}
}

async function selectItem(id: number) {
  selectedId.value = id
  if (showPreview.value) {
    try { previewData.value = await GetItemData(id) as any } catch { previewData.value = '' }
  }
}

async function pasteItem(id: number, asPlain = false) {
  try {
    if (asPlain) await PasteItemAsPlainText(id)
    else await PasteItem(id)
  } catch (e) { console.error(e) }
}

async function deleteItem(id: number) {
  try {
    await DeleteItem(id)
    if (selectedId.value === id) {
      selectedId.value = items.value.length > 1 ? items.value[0]?.id || null : null
    }
    await loadItems()
  } catch (e) { console.error(e) }
}

async function togglePin(id: number) {
  await TogglePin(id)
  await loadItems()
}

async function togglePause() {
  const next = !isPaused.value
  await SetPaused(next)
  isPaused.value = next
}

function setTag(tagId: number) {
  activeTag.value = tagId
  selectedId.value = null
  loadItems()
}

async function handleSearch() {
  selectedId.value = null
  await loadItems()
  if (items.value.length > 0) selectItem(items.value[0].id)
}

function clearSearch() {
  searchQuery.value = ''
  loadItems()
}

function togglePreview() {
  if (!selectedId.value) return
  showPreview.value = !showPreview.value
  if (showPreview.value && selectedItem.value) {
    GetItemData(selectedItem.value.id).then(d => { previewData.value = d as any }).catch(() => {})
  }
}

function toggleQueueMode() {
  queueMode.value = !queueMode.value
  if (!queueMode.value) queueItems.value = []
}

async function addToQueue(id: number) {
  if (!queueItems.value.includes(id)) {
    queueItems.value.push(id)
  }
}

function handleKeydown(e: KeyboardEvent) {
  const isInputFocused = document.activeElement?.tagName === 'INPUT'

  if (e.key === 'Escape') {
    if (searchQuery.value) { clearSearch(); return }
    showPreview.value = false
    return
  }

  if (e.key === ' ' && !isInputFocused) {
    e.preventDefault()
    togglePreview()
    return
  }

  if (e.key === 'ArrowRight' || (e.key === 'l' && !isInputFocused)) {
    e.preventDefault()
    navigateRight()
    return
  }
  if (e.key === 'ArrowLeft' || (e.key === 'h' && !isInputFocused)) {
    e.preventDefault()
    navigateLeft()
    return
  }
  if (e.key === 'ArrowDown' || (e.key === 'j' && !isInputFocused)) {
    e.preventDefault()
    if (isInputFocused) {
      (document.activeElement as HTMLInputElement)?.blur()
      if (items.value.length > 0) selectItem(items.value[0].id)
    }
    return
  }
  if (e.key === 'ArrowUp' && isInputFocused) {
    return
  }

  if (e.key === 'Enter' && selectedId.value && !isInputFocused) {
    e.preventDefault()
    if (queueMode.value) {
      addToQueue(selectedId.value)
    } else {
      pasteItem(selectedId.value)
    }
    return
  }

  if (e.key === 'Delete' || e.key === 'Backspace') {
    if (selectedId.value && !isInputFocused) {
      e.preventDefault()
      deleteItem(selectedId.value)
    }
    return
  }

  if (e.key === 'p' && !isInputFocused && !e.metaKey && !e.ctrlKey) {
    e.preventDefault()
    togglePin(selectedId.value!)
    return
  }

  if (e.key >= '1' && e.key <= '9' && (e.metaKey || e.ctrlKey)) {
    e.preventDefault()
    const idx = parseInt(e.key) - 1
    if (items.value[idx]) pasteItem(items.value[idx].id)
    return
  }

  if (e.key === 'q' && (e.metaKey || e.ctrlKey) && e.altKey) {
    e.preventDefault()
    toggleQueueMode()
    return
  }

  if (e.key === '/' && !isInputFocused) {
    e.preventDefault()
    document.querySelector<HTMLInputElement>('.search-input')?.focus()
    return
  }
}

function navigateRight() {
  const idx = items.value.findIndex(i => i.id === selectedId.value)
  if (idx < items.value.length - 1) {
    selectItem(items.value[idx + 1].id)
    scrollToCard(idx + 1)
  }
}

function navigateLeft() {
  const idx = items.value.findIndex(i => i.id === selectedId.value)
  if (idx > 0) {
    selectItem(items.value[idx - 1].id)
    scrollToCard(idx - 1)
  }
}

function scrollToCard(idx: number) {
  const el = document.querySelector(`[data-card-idx="${idx}"]`)
  el?.scrollIntoView({ behavior: 'smooth', block: 'nearest', inline: 'center' })
}

function handleWheel(e: WheelEvent) {
  const container = listRef.value
  if (!container) return
  e.preventDefault()
  container.scrollLeft += e.deltaY
}

onMounted(async () => {
  transforms.value = await GetTransforms() as any
  tags.value = await GetTags() as any
  isPaused.value = await IsPaused() as any
  await loadItems()
  EventsOn('clipboard:added', () => { if (!isPaused.value) loadItems() })
  document.addEventListener('keydown', handleKeydown)
})

onUnmounted(() => {
  document.removeEventListener('keydown', handleKeydown)
})
</script>

<template>
  <div class="deck-panel">
    <div class="panel-topbar">
      <div class="topbar-left">
        <div class="search-field">
          <span class="search-icon">🔍</span>
          <input
            class="search-input"
            v-model="searchQuery"
            @input="handleSearch"
            placeholder="Search clipboard..."
            spellcheck="false"
          />
          <button v-if="searchQuery" class="search-clear" @click="clearSearch">✕</button>
        </div>
      </div>
      <div class="topbar-tags">
        <button
          v-for="tag in tags"
          :key="tag.id"
          class="tag-pill"
          :class="{ active: activeTag === tag.id }"
          @click="setTag(tag.id)"
        >
          {{ tag.name }}
        </button>
      </div>
      <div class="topbar-actions">
        <button class="topbar-btn" @click="toggleQueueMode" :class="{ active: queueMode }" title="Queue Mode (⌥⌘Q)">
          Q
        </button>
        <button class="topbar-btn" @click="togglePause" :class="{ active: isPaused }" title="Pause">
          {{ isPaused ? '▶' : '⏸' }}
        </button>
      </div>
    </div>

    <div class="card-scroll-area">
      <div class="card-container" ref="listRef" @wheel.prevent="handleWheel">
        <div
          v-for="(item, idx) in items"
          :key="item.id"
          :data-card-idx="idx"
          class="clip-card"
          :class="{ selected: item.id === selectedId, pinned: item.isPinned, 'in-queue': queueItems.includes(item.id) }"
          @click="selectItem(item.id)"
          @dblclick="queueMode ? addToQueue(item.id) : pasteItem(item.id)"
          :style="{ width: cardSize + 'px', minWidth: cardSize + 'px', height: cardSize + 'px' }"
        >
          <div class="card-header">
            <div class="card-app-icon">{{ item.appName?.charAt(0) || '?' }}</div>
            <div class="card-meta">
              <span class="card-app-name">{{ item.appName }}</span>
              <span class="card-timestamp">{{ item.timeSince }}</span>
            </div>
            <div class="card-type-badge">{{ typeIcons[item.itemType] || 'T' }}</div>
          </div>
          <div class="card-content">
            <template v-if="item.itemType === 'image'">
              <div class="card-image-placeholder">🖼</div>
            </template>
            <template v-else-if="item.itemType === 'color'">
              <div class="card-color-swatch" :style="{ background: item.colorValue }"></div>
              <div class="card-color-label">{{ item.colorValue }}</div>
            </template>
            <template v-else-if="item.itemType === 'url'">
              <div class="card-url">{{ item.urlValue }}</div>
            </template>
            <template v-else-if="item.itemType === 'file'">
              <div class="card-file-name">{{ item.searchText }}</div>
            </template>
            <template v-else>
              <div class="card-text">{{ item.displayText }}</div>
            </template>
          </div>
          <div v-if="item.isPinned" class="card-pin-indicator">📌</div>
          <div v-if="queueItems.includes(item.id)" class="card-queue-badge">
            {{ queueItems.indexOf(item.id) + 1 }}
          </div>
        </div>

        <div v-if="items.length === 0" class="empty-cards">
          <div class="empty-icon">📋</div>
          <div class="empty-text">Copy something and press ⌘P</div>
        </div>
      </div>
    </div>

    <div class="panel-bottombar" v-if="queueMode">
      <div class="queue-status">
        <span class="queue-badge">Queue</span>
        <span class="queue-count">{{ queueItems.length }} items</span>
        <div class="queue-actions">
          <button class="queue-btn" @click="queueItems = []">Clear</button>
          <button class="queue-btn primary" @click="toggleQueueMode">Exit</button>
        </div>
      </div>
    </div>
    <div class="panel-bottombar ambient" v-else>
      <span class="bottom-hint">⌘P Close · ↵ Paste · Space Preview · ⌘1-9 Quick</span>
    </div>

    <div v-if="showPreview && selectedItem" class="preview-overlay" @click="showPreview = false">
      <div class="preview-card" @click.stop>
        <div class="preview-header-bar">
          <span class="preview-type">{{ selectedItem.itemType }}</span>
          <span class="preview-app">{{ selectedItem.appName }}</span>
          <button class="preview-close" @click="showPreview = false">✕</button>
        </div>
        <div class="preview-body">
          <div v-if="selectedItem.itemType === 'image'" class="preview-image-wrap">
            <img v-if="previewData?.startsWith('data:image')" :src="previewData" class="preview-img" />
            <div v-else class="preview-placeholder">[Image]</div>
          </div>
          <div v-else-if="selectedItem.itemType === 'color'" class="preview-color-wrap">
            <div class="preview-swatch" :style="{ background: selectedItem.colorValue }"></div>
            <div class="preview-color-val">{{ selectedItem.colorValue }}</div>
          </div>
          <pre v-else class="preview-text">{{ previewData || selectedItem.searchText }}</pre>
        </div>
        <div class="preview-footer">
          <span>{{ selectedItem.timeSince }}</span>
          <span>{{ selectedItem.contentLength }} chars</span>
          <div class="preview-actions">
            <button class="preview-act-btn" @click="pasteItem(selectedItem.id)">Paste</button>
            <button class="preview-act-btn" @click="pasteItem(selectedItem.id, true)">Plain</button>
            <button class="preview-act-btn" @click="togglePin(selectedItem.id)">
              {{ selectedItem.isPinned ? 'Unpin' : 'Pin' }}
            </button>
            <button class="preview-act-btn danger" @click="deleteItem(selectedItem.id); showPreview = false">Delete</button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
