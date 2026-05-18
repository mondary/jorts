# Jorts for macOS

This directory contains a native Swift/AppKit + SwiftUI port of Jorts.

## Scope

- Multiple sticky-note windows.
- The same `saved_state.json` schema as the GTK app: `title`, `color`, `content`, `monospace`, `zoom`, `width`, and `height`.
- Jorts color themes, monospace mode, zoom, list-prefix toggling, emoji picker, preferences, and debounced persistence.
- Automatic one-time import from common Linux/legacy Jorts save paths when no macOS save exists yet.

## Build and Run

From the repository root:

```bash
./script/build_and_run.sh
```

The app stores notes at:

```text
~/Library/Application Support/io.github.elly_code.jorts.macos/saved_state.json
```
