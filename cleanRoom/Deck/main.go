package main

import (
	"embed"

	"github.com/wailsapp/wails/v2"
	"github.com/wailsapp/wails/v2/pkg/options"
	"github.com/wailsapp/wails/v2/pkg/options/assetserver"
	"github.com/wailsapp/wails/v2/pkg/options/mac"
)

//go:embed all:frontend/dist
var assets embed.FS

func main() {
	app := NewApp()

	err := wails.Run(&options.App{
		Title:            "Deck",
		Width:            1000,
		Height:           360,
		MinWidth:         700,
		MinHeight:        305,
		MaxHeight:        420,
		AssetServer:      &assetserver.Options{
			Assets: assets,
		},
		BackgroundColour: &options.RGBA{R: 30, G: 30, B: 30, A: 240},
		OnStartup:        app.startup,
		OnShutdown:       app.shutdown,
		Frameless:        true,
		StartHidden:      true,
		Mac: &mac.Options{
			TitleBar: &mac.TitleBar{
				HideTitleBar: true,
			},
			About: &mac.AboutInfo{
				Title:   "Deck",
				Message: "Modern, native, privacy-first clipboard manager for macOS.\n\nCleanroom Go implementation.",
			},
			WebviewIsTransparent: false,
			WindowIsTranslucent:  true,
		},
		Bind: []interface{}{
			app,
		},
	})

	if err != nil {
		println("Error:", err.Error())
	}
}
