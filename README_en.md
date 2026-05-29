# PKbrain

![Project icon](icon.png)

[🇬🇧 EN](README_en.md) · [🇫🇷 FR](README.md)

✨ Native macOS notes app inspired by Jorts, with inline calculation, command palette, and advanced shortcut management.

![Jorts Overview](https://github.com/elly-code/jorts/blob/main/data/screenshots/spread.png)
![Preferences Light](https://github.com/elly-code/jorts/blob/main/data/screenshots/preferences-light.png)
![Preferences Dark](https://github.com/elly-code/jorts/blob/main/data/screenshots/preferences-dark.png)
![Default Theme](https://github.com/elly-code/jorts/blob/main/data/screenshots/default.png)

## ✅ Features
- Native macOS port (SwiftUI/AppKit) inspired by Jorts.
- Command palette (`Cmd+K`) with:
  - title/content search
  - keyboard navigation
  - note opening
  - note creation
  - Preferences / About actions
- Editable keyboard shortcuts in preferences (modifier + key).
- Two configurable global shortcuts:
  - focus last note
  - create new note
- Live menu shortcut refresh when settings change.
- Inline calculator in notes:
  - real-time evaluation
  - per-line variables
  - unit conversions
  - expression parsing inside editor
- Automatic inline icons:
  - `developer-icons` catalog integration
  - icon insertion after recognized words
  - 300+ technical icons available
- Inline calculator toggle in settings.
- Enhanced editing engine:
  - list toggle
  - monospace toggle
  - zoom in/out/reset
  - typing effects
- Notes list window (active notes + trash).
- Restore notes from trash.
- Color/theme system:
  - color picker
  - automatic text contrast
  - color previews
- Global clipboard drawer:
  - captures text, URLs, images, files, and hex colors
  - persistent history in the storage folder
  - source app icon for each item
  - instant search + type filters
  - source, pinned, and recent filters
  - pins, lock, per-item delete
  - full keyboard navigation
  - `Enter` pastes into the previous app
  - `Cmd+Enter` converts the item to a note
  - full image preview without crop + lightbox
  - QuickLook for files
  - smart color preview with Hex/RGB/HSL/OKLCH
  - configurable drawer position: top, bottom, left, right
- Persistence/storage:
  - Markdown-first per-note storage
  - JSON sidecar note version history
  - legacy JSON -> Markdown migration
  - duplicate consolidation
  - canonicalization/cleanup
- Data operations:
  - import/export
  - duplicate/backup archiving
  - open storage folder in Finder
- Internationalization:
  - localized resources
  - runtime language selection in preferences
- Window management:
  - native floating command palette behavior
  - focus restoration after closing palette
- Native menu bar integration:
  - quick actions
  - settings/about/restart/quit access
- Repository refactor:
  - `PKbrain/` for app source
  - `submodules/jorts` for upstream inspiration
  - `submodules/developer-icons` for technical icon source assets
  - `releases/` for artifacts

## 🧠 Usage
- Dev run: `./PKbrain/run-dev.sh`
- Open command palette: `Cmd+K`
- Open preferences: `Cmd+,`
- Global shortcuts (defaults, configurable):
  - `Cmd+Shift+Space`: focus last note
  - `Ctrl+Shift+Space`: create new note
- Spotlight / Raycast / Alfred integration (URLs):
  - New note: `pkbrain://new`
  - Reopen last note: `pkbrain://last`
  - Show notes list: `pkbrain://list`
  - Open clipboard: `pkbrain://clipboard`
- Default storage folder: `~/Documents/PKbrain/`

### Clipboard drawer
- Toggle: `Cmd+Shift+V`
- Navigation: left/right arrows
- `Enter`: paste (best-effort) into previous app + close drawer
- `Cmd+Enter`: convert to note
- Filters: text, URL, image, file, color, source, pinned, recent
- Colors: copying `#2C3861` creates a color card with:
  - Hex: `#2C3861`
  - RGB: `44, 56, 97`
  - HSL: `226, 38, 28`
  - OKLCH: computed automatically

## ⚙️ Settings
- General preferences (language, storage, import/export).
- Shortcut preferences (modifier + key).
- Inline calculator on/off.
- Clipboard drawer position.

## 🧾 Commands
- `./PKbrain/run-dev.sh`: build + package + run
- `swift build`: SwiftPM build

## 📦 Build & Package
- `PKbrain/script/build_and_run.sh` rebuilds the local `.app` bundle.
- The test bundle is generated at `releases/PKbrain.app`.
- `PKbrain/dist` points to `../releases`.
- SwiftPM target path: `PKbrain/macos/PKbrain`.

## 🧪 Install (Antigravity)
- Not used for this project at this stage.

## 🧾 Changelog
- `182f57a`: inline icons added to notes.
- `d06eea4`: major repository layout refactor (`PKbrain/`, `submodules/jorts`, `releases`).
- `f9c95c5`: configurable global shortcuts + unified dev run + default storage updates.
- `45a7297`: new shortcuts + translation updates.
- `8e97ab3`: command palette added.
- `0aedc51`: inline calculation features added.

## 🔗 Links
- Upstream inspiration (Jorts): https://github.com/elly-code/jorts
- Calculation inspirations:
  - https://github.com/bornova/numara-calculator
  - https://github.com/teamxenox/caligator
- FR README: [README.md](README.md)
