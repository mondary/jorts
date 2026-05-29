# TODO (Clipboard + Deck-Style Drawer)
## 🔥 V2 - MAJOR UPDATE

Status: in progress.

## Features Checklist

- [x] Clipboard capture (text/url/image/files) + source app metadata
- [x] Drawer UI (clean-room Deck/PastePal-inspired) + edge position (top/bottom/left/right)
- [x] Global shortcut `Cmd+Shift+V` to toggle clipboard drawer
- [x] Keyboard navigation + shortcuts (left/right, Enter, Cmd+Enter, Esc, Cmd+F)
- [x] PKClipboard standard window: keyboard navigation (left/right/up/down + Enter)
- [x] PKClipboard standard window: `Esc` closes the standard window
- [x] PKClipboard standard window: shortcut badges limited to first 9 cards (`⌘1...⌘9`)
- [x] PKClipboard standard window: safer top/bottom layout during resize (reduced clipping)
- [x] PKClipboard standard window: default size set to `1200x1000`
- [x] PKClipboard standard window: functional clickable pagination
- [x] PKClipboard standard window: dynamic items-per-page based on visible grid size
- [x] Clipboard windows: hide note windows on open to prevent overlap/focus conflicts
- [x] Clipboard drawer panel: key/main focus enabled to prevent split typing
- [x] Clipboard drawer + PKClipboard: `Cmd+C` copies selected card to system pasteboard
- [x] Shortcut added for PKClipboard standard window (`Cmd+Option+V`)
- [x] Persist clipboard history to disk (alongside notes storage)
- [x] App icons per clipboard item (source pictos)
- [x] Image thumbnails shown entirely (no crop) + lightbox
- [x] File preview + QuickLook
- [x] Color clipboard cards for hex values (`#RGB`, `#RRGGBB`, `#RRGGBBAA`)
- [x] Color previews with Hex/RGB/HSL/OKLCH values
- [x] Search + basic type filters (All/Text/URL/Image/Files/Color)
- [x] Pins + lock (non-expiring) + per-item delete actions
- [x] Purge logic (max items + max age days), respecting pinned/locked
- [x] Enter pastes into previous app (Cmd+V injection best-effort)
- [x] One-line footer/actions/tags layout in drawer cards
- [x] Esc behavior in 2 steps:
  - first Esc resets filters/category/selection to default latest item
  - second Esc closes drawer
- [x] Click outside drawer closes drawer
- [x] Menu bar entry to open clipboard drawer (`Afficher le tiroir presse-papiers`)
- [x] Sticky note metadata stored at end of Markdown file (`<!-- JORTS_META ... -->`)

## Remaining Features

1. Source actions + privacy controls
   - Delete all items from a specific source app
   - Pause capture (already exists) and improve UI state/feedback
   - Blacklist/whitelist apps (source bundle IDs)
   - UI to manage allow/block mode and list

2. Source grouping (Deck-like)
   - Group items by source app (sections)
   - Per-section header with app icon + name + count
   - Ability to collapse/expand sections

3. Limits + purge UI
   - Settings UI for:
     - max items
     - max age (days)
     - optional "keep pinned/locked forever" (already implied by logic)
   - Expose "purge now" action

4. Rich previews
   - [x] Image preview:
     - full image visible inside the card
     - filename kept on one line
   - [x] Color preview:
     - large swatch
     - Hex/RGB/HSL/OKLCH conversions
     - legacy text clipboard items that are hex values render as color cards
   - [x] URL preview:
     - title
     - favicon
     - snippet/description
     - preview image thumbnail
     - caching + async refresh
   - [ ] Text preview:
     - long text scroll
     - better truncation rules
   - [ ] Images:
      - lightbox polish (zoom/pan optional)
   - [ ] Files:
      - QuickLook polish (multi-file navigation)

5. Export / Sync (optional)
   - Export clipboard history (JSON)
   - Import clipboard history (JSON)
   - Optional: sync strategy (later)

6. Convert-to-note template
   - Auto title generation (first line or heuristics)
   - Include metadata (source app, timestamp, type)
   - Optional tags

7. UI polish (clean-room Deck look)
   - Bottom bar: tag pills / category chips (as per `design/PastePal_CleanRoom.html`)
   - Consistent spacing, shadows, borders
   - Drawer edge positions: ensure correct behavior for left/right edges

## External References (Features To Consider)

These are feature checklists from the 4 sources you cited, mapped into our TODO. Some are explicitly out-of-scope (license / cross-platform / heavy infra), but listed here so we don't forget them.

### Deck (yuzeguitarist/Deck)
- [x] Capture colors from hex values (`#RGB`, `#RRGGBB`, `#RRGGBBAA`)
- [ ] Capture more types: rich text, links beyond current URL metadata citeturn1view0
- [ ] Advanced search:
  - regex search citeturn1view0
  - semantic search (on-device embeddings) citeturn1view0
  - slash rules (filter by app/date/type include/exclude) citeturn1view0
- [ ] Per-item custom titles citeturn1view0
- [ ] Tags + smart categories citeturn1view0
- [ ] Context-aware ordering (rank items by current app relevance) citeturn1view0
- [ ] Smart rules / automation:
  - condition+action workflows citeturn1view0
  - JavaScript script plugins citeturn1view0
- [ ] OCR background extraction (multi-language) citeturn1view0
- [ ] Templates library (cursor-position paste, color-coded templates) citeturn1view0
- [ ] Text transformations (format/minify JSON, Base64, URL encode/decode, case conversions, etc.) citeturn1view0
- [ ] IDE source anchors (file path + line number + jump back) citeturn1view0
- [ ] Link preview + QR generation citeturn1view0
- [ ] Link cleaner (strip tracking params) citeturn1view0
- [ ] Instant calculation on copied expressions citeturn1view0
- [ ] Smart text detection (emails/urls/phone/code/jwt/...) citeturn1view0
- [ ] Privacy/security:
  - Touch ID/Face ID gate for opening panel citeturn1view0
  - sensitive data filtering (Luhn/bank cards etc.) citeturn1view0
  - window-aware protection (pause capture for sensitive windows) citeturn1view0
  - hide panel during screen sharing/recording citeturn1view0
- [ ] Workflow:
  - queue mode (paste sequence) citeturn1view0
  - optional Vim mode citeturn1view0
  - typing paste (type out content) citeturn1view0
  - CLI bridge for automation citeturn1view0
- [ ] Migration from other apps + usage stats + auto update checks citeturn1view0
- [ ] Sharing/sync:
  - LAN sharing (AES-GCM + TOTP) citeturn1view0
  - direct IP peer connection citeturn1view0

### ClipPocket (Dhahd/ClipPocket)
- [ ] Confirm/port any missing basics if present there:
  - type detection, search, pins, privacy-first local storage citeturn1view2

### PasteClip (minsang-alt/PasteClip)
- [ ] Confirm/port any missing basics if present there:
  - minimal “Paste-like” UX citeturn1view1

### CopyCat Clipboard (raj457036/CopyCat-Clipboard)
- [ ] Unlimited history + multi-device concurrency citeturn0search0
- [ ] Cross-device sync (Android/Windows/macOS/iOS/Linux) citeturn0search0
- [ ] Collections (categorized groups; collection items don't expire) citeturn0search0
- [ ] Categorical search citeturn0search0
- [ ] Security: encryption + optional end-to-end encryption citeturn0search0
- [ ] Smart paste (paste directly into apps) citeturn0search0
- [ ] Titles/descriptions on clips citeturn0search0
- [ ] Customization/theming + drag&drop + extensive keyboard shortcuts citeturn0search0
