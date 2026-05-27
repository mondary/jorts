<div align="center">
  <img alt="An icon representing a stack of little squared blue sticky notes. The first one, and the second one hinted below, have scribbles over them" src="data/icons/default/hicolor/128.png" />
  <h1>Jorts_MacOS</h1>
  <h3>Neither jeans nor shorts, just like jorts. A sticky notes app for macOS</h3>

  <p>
    <strong>This is a native macOS fork of</strong>
    <a href="https://github.com/elly-code/jorts">elly-code/jorts</a>
  </p>

  <p>
    <a href="https://github.com/clm-tmp/JORTS_macos">
      <img src="https://img.shields.io/badge/macOS-fork-blue" alt="macOS fork">
    </a>
    <em> — macOS port by <a href="https://github.com/clm-tmp">clm-tmp</a></em>
  </p>

  <p>
    <em>Looking for Linux or Windows? See the <a href="#other-platforms">original project</a>.</em>
  </p>
</div>

<br/>

<img src="https://github.com/elly-code/jorts/blob/main/data/screenshots/spread.png" alt="Several colourful sticky notes in a spread. Most are covered in scribbles. One in forefront is blue and has the text 'Lovely little colourful squares for all of your notes! 🥰'">

<br/>

---

## macOS Port

This is a **native Swift + AppKit implementation** of Jorts, rewritten from the original GTK-based version. It provides a true macOS experience with native menus, keyboard shortcuts, and system integration.

**Minimum requirement:** macOS 13.0 (Ventura) or later


## Installation on macOS

### Building from source

You'll need [Xcode](https://developer.apple.com/xcode/) or the Swift toolchain.

```bash
# Clone the repository
git clone https://github.com/clm-tmp/JORTS_macos.git
cd JORTS_macos

# Build + package + run (single dev entrypoint)
./run-dev.sh
```

### Development build

```bash
# Build in release mode
swift build -c release

# The binary will be at:
# .build/arm64-apple-macosx/release/JortsMac
```

**Note:** A distributable app bundle (`.app`) and proper installer are planned for future releases. For now, use the built executable or Xcode to run the app.

### Inline calculations (macOS)

Type simple math in a note to see results in a subtle right-side column.

- Units: `10 km in m`, `5kg + 200g`, `32 f in c`
- Variables (per render, top-to-bottom): `tax=1.2` then `100*tax`


## Storage

Notes are stored in `saved_state.json` in the app's data directory.

**Location on macOS (default):**
```bash
~/Documents/JortsMacOS/
```

You can manually backup or transfer notes by copying this file. The JSON format is simple and human-readable.


## Other Platforms

Looking for Jorts on **Linux** or **Windows**? The original project supports those platforms:

- [elly-code/jorts](https://github.com/elly-code/jorts) — GTK-based version
- Available on [Flathub](https://flathub.org/apps/io.github.ellie_commons.jorts) for Linux
- Windows installer available in [releases](https://github.com/elly-code/jorts/releases)


## Keyboard Shortcuts (macOS)

| Shortcut | Action |
|----------|--------|
| `Cmd + N` | New sticky note |
| `Cmd + S` | Save all notes |
| `Cmd + W` | Close note window |
| `Cmd + ,` | Preferences |
| `Cmd + Delete` | Delete sticky note |
| `Cmd + Shift + L` | Toggle list |
| `Cmd + M` | Toggle monospace |
| `Cmd + Plus` | Zoom in |
| `Cmd + Minus` | Zoom out |
| `Cmd + 0` | Reset zoom |


## Contributing

This is a personal macOS port. For issues related to the original Jorts application, please report them to [elly-code/jorts](https://github.com/elly-code/jorts/issues).

macOS-specific issues can be reported here.


## Credits

- **[teamcons](https://github.com/teamcons)** — Original developer and maintainer of Jorts
- **[lains](https://github.com/lains)** — Original creator (Notejot)
- **[wpkelso](https://github.com/wpkelso)** — Icon designer
- **[clm-tmp](https://github.com/clm-tmp)** — Native macOS port developer

**Links:**
- Original project: [elly-code/jorts](https://github.com/elly-code/jorts)
- This macOS fork: [clm-tmp/JORTS_macos](https://github.com/clm-tmp/JORTS_macos)


## License

This project shares the same license as the original Jorts. See [LICENSE](LICENSE) for details.
