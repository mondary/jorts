# JortsMacOS

Native macOS notes app inspired by [Jorts](https://github.com/elly-code/jorts).

This repository keeps a dedicated macOS implementation while tracking upstream Jorts separately.

## Repository Layout

- `submodules/jorts` — upstream Jorts source (Git submodule)
- `submodules/numi` — placeholder for future Numi source integration
- `JortsMacOS` — macOS app code (SwiftUI/AppKit)
- `releases` — release artifacts

## Build & Run (macOS)

```bash
./JortsMacOS/run-dev.sh
```

## Storage (default)

Notes are stored in:

```bash
~/Documents/JortsMacOS/
```

## What Is Added Beyond Original Jorts

This fork includes much more than a straight macOS port.

### Platform + UX

- Native SwiftUI/AppKit app lifecycle
- Native menu bar status item + dynamic menu entries
- Native preferences window with sections
- Native notes list window (active notes + trash)
- Native command palette window (`Cmd+K`)
- Native About panel wiring
- Restart action from UI

### Shortcut System

- Editable shortcut settings UI (modifiers + key)
- Shortcut persistence in app settings
- Menu shortcuts rebuilt live when settings change
- Two global system hotkeys:
  - Focus last note
  - Create new note
- Global hotkeys wired to settings (not hardcoded)

### Command Palette

- Search over note title/content
- Command actions in palette:
  - Create note
  - Open preferences
  - Open about
- Keyboard navigation (up/down, enter, esc)
- Selection state handling + close/focus behavior

### Note Editing Features

- Inline calculations column
- Unit conversion and expression parsing support
- Typing visual effects engine (multiple effect modes)
- List toggle behavior in text editor
- Monospace toggle support
- Font selection and previews
- Pin/unpin behavior
- Zoom in/out/reset note content

### Data Model + Persistence

- Markdown-first storage (`Notes/`, `Trash/`)
- Sidecar JSON for note version history
- Legacy JSON import/migration support
- Seed JSON migration support
- Duplicate markdown consolidation
- Canonicalization + cleanup passes
- Trash restore flow
- Versioning + restore workflow
- Autosave scheduling + immediate save paths

### Data Operations

- Export notes flow
- Import notes flow
- Archive duplicates/backups flow
- Open storage directory in Finder flow

### Theming + Visuals

- Expanded color theme set
- Auto text color contrast handling
- Color picker popover/grid
- Theme previews in note surfaces
- Custom macOS menu bar icon handling

### Internationalization

- Localization controller for runtime language selection
- Bundled multi-language resources for macOS build

### Window Management

- Remember/reapply note window state behavior
- Dedicated floating behavior for command palette
- Focus restoration logic when palette closes

### Dev/Repo Operations

- Single dev launcher script for macOS app bundle refresh + run
- Repository refactor toward external-source submodules

## Upstream Relationship

- Upstream inspiration/source: `elly-code/jorts`
- macOS fork implementation lives in `JortsMacOS`
- Upstream code tracking lives in `submodules/jorts`
