import AppKit
import QuickLookUI
import SwiftUI

struct QuickLookPreview: NSViewRepresentable {
    let urls: [URL]

    func makeNSView(context: Context) -> QLPreviewView {
        let v = QLPreviewView(frame: .zero, style: .normal)!
        v.autostarts = true
        v.previewItem = urls.first as NSURL?
        return v
    }

    func updateNSView(_ nsView: QLPreviewView, context: Context) {
        nsView.previewItem = urls.first as NSURL?
    }
}
