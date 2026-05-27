# TODO (Clipboard + Deck-Style Drawer)

Status: in progress.

## Features Checklist

- [x] Clipboard capture (text/url/image/files) + source app metadata
- [x] Drawer UI (clean-room Deck/PastePal-inspired) + edge position (top/bottom/left/right)
- [x] Global shortcut `Cmd+Shift+V` to toggle clipboard drawer
- [x] Persist clipboard history to disk (alongside notes storage)
- [x] App icons per clipboard item (source pictos)
- [x] Image thumbnails + lightbox
- [x] File preview + QuickLook
- [x] Search + basic type filters (All/Text/URL/Image/Files)
- [x] Pins + lock (non-expiring) + per-item delete actions
- [x] Purge logic (max items + max age days), respecting pinned/locked

## Remaining Features

1. Keyboard navigation
   - Arrow keys: move selection left/right across cards
   - Enter: copy selected item to clipboard
   - Cmd+Enter: convert selected item to a note (with template)
   - Esc: close the drawer
   - Optional: Cmd+F focuses search

2. Source actions + privacy controls
   - Delete all items from a specific source app
   - Pause capture (already exists) and improve UI state/feedback
   - Blacklist/whitelist apps (source bundle IDs)
   - UI to manage allow/block mode and list

3. Source grouping (Deck-like)
   - Group items by source app (sections)
   - Per-section header with app icon + name + count
   - Ability to collapse/expand sections

4. Limits + purge UI
   - Settings UI for:
     - max items
     - max age (days)
     - optional "keep pinned/locked forever" (already implied by logic)
   - Expose "purge now" action

5. Rich previews
   - URL preview:
     - title
     - favicon
     - optional snippet
     - caching + async fetch
   - Text preview:
     - long text scroll
     - better truncation rules
   - Images:
     - lightbox polish (zoom/pan optional)
   - Files:
     - QuickLook polish (multi-file navigation)

6. Export / Sync (optional)
   - Export clipboard history (JSON)
   - Import clipboard history (JSON)
   - Optional: sync strategy (later)

7. Convert-to-note template
   - Auto title generation (first line or heuristics)
   - Include metadata (source app, timestamp, type)
   - Optional tags

8. UI polish (clean-room Deck look)
   - Bottom bar: tag pills / category chips (as per `design/PastePal_CleanRoom.html`)
   - Consistent spacing, shadows, borders
   - Drawer edge positions: ensure correct behavior for left/right edges
