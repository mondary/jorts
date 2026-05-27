# JortsMacOS

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
  - `JortsMacOS/` for app source
  - `submodules/jorts` for upstream inspiration
  - `releases/` for artifacts

## 🧠 Usage
- Dev run: `./JortsMacOS/run-dev.sh`
- Open command palette: `Cmd+K`
- Open preferences: `Cmd+,`
- Default storage folder: `~/Documents/JortsMacOS/`

## ⚙️ Settings
- General preferences (language, storage, import/export).
- Shortcut preferences (modifier + key).
- Inline calculator on/off.

## 🧾 Commands
- `./JortsMacOS/run-dev.sh`: build + package + run
- `swift build`: SwiftPM build

## 📦 Build & Package
- `JortsMacOS/script/build_and_run.sh` rebuilds the local `.app` bundle.
- SwiftPM target path: `JortsMacOS/macos/JortsMac`.

## 🧪 Install (Antigravity)
- Not used for this project at this stage.

## 🧾 Changelog
- `d06eea4`: major repository layout refactor (`JortsMacOS/`, `submodules/jorts`, `releases`).
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
