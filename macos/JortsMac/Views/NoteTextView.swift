import AppKit
import SwiftUI

struct NoteTextView: NSViewRepresentable {
    @Binding var text: String
    let onShiftTabToTitle: () -> Void
    let focusRequestToken: Int
    let isEditable: Bool
    let typingEffect: TypingEffect

    let font: NSFont
    let textColor: NSColor
    let insertionPointColor: NSColor
    let listPrefix: String
    let toggleListRequestToken: Int

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.string = text
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.isEditable = isEditable
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainerInset = NSSize(width: 12, height: 8)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: .greatestFiniteMagnitude)
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        applyStyle(to: textView)

        scrollView.documentView = textView

        let host = EffectHostView(scrollView: scrollView)
        context.coordinator.effectHost = host
        context.coordinator.textView = textView
        return host
    }

    func updateNSView(_ view: NSView, context: Context) {
        context.coordinator.parent = self

        guard let host = view as? EffectHostView,
              let textView = host.textView else {
            return
        }

        applyStyle(to: textView)
        textView.isEditable = isEditable

        if textView.string != text && !context.coordinator.isApplyingChange {
            let selectedRange = textView.selectedRange()
            textView.string = text
            textView.setSelectedRange(selectedRange.clamped(toLength: (text as NSString).length))
        }

        if context.coordinator.lastToggleListRequestToken != toggleListRequestToken {
            context.coordinator.lastToggleListRequestToken = toggleListRequestToken
            context.coordinator.toggleList(in: textView)
        }

        if context.coordinator.lastFocusRequestToken != focusRequestToken {
            context.coordinator.lastFocusRequestToken = focusRequestToken
            textView.window?.makeFirstResponder(textView)
        }
    }

    private func applyStyle(to textView: NSTextView) {
        textView.font = font
        textView.textColor = textColor
        textView.insertionPointColor = insertionPointColor
        textView.selectedTextAttributes = [
            .backgroundColor: insertionPointColor.withAlphaComponent(0.22)
        ]
        textView.typingAttributes = [
            .font: font,
            .foregroundColor: textColor
        ]
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: NoteTextView
        var isApplyingChange = false
        var lastToggleListRequestToken = 0
        var lastFocusRequestToken = 0
        weak var effectHost: EffectHostView?
        weak var textView: NSTextView?
        private var lastEffectAt: TimeInterval = 0

        init(_ parent: NoteTextView) {
            self.parent = parent
        }

        func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
            guard !isApplyingChange,
                  let replacementString,
                  !parent.listPrefix.isEmpty else {
                return true
            }

            // Continue bullet list on newline if current line starts with the list prefix.
            if replacementString == "\n" {
                let original = textView.string as NSString
                let insertionLocation = affectedCharRange.location
                var lineStart = 0
                var lineEnd = 0
                var contentsEnd = 0
                original.getLineStart(&lineStart, end: &lineEnd, contentsEnd: &contentsEnd, for: NSRange(location: insertionLocation, length: 0))

                let lineRange = NSRange(location: lineStart, length: max(0, contentsEnd - lineStart))
                if hasPrefix(parent.listPrefix, in: original, lineRange: lineRange) {
                    isApplyingChange = true
                    textView.insertText("\n\(parent.listPrefix)", replacementRange: affectedCharRange)
                    isApplyingChange = false
                    parent.text = textView.string
                    textView.didChangeText()
                    return false
                }
            }

            return true
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertBacktab(_:)) {
                parent.onShiftTabToTitle()
                return true
            }
            return false
        }

        func textDidChange(_ notification: Notification) {
            guard !isApplyingChange,
                  let textView = notification.object as? NSTextView else {
                return
            }

            maybeEmitTypingEffect(from: textView)

            // Convert "- " at start of line into the configured list prefix once the user starts typing content.
            if !parent.listPrefix.isEmpty {
                let original = textView.string as NSString
                let insertionLocation = textView.selectedRange().location
                if insertionLocation <= original.length {
                    var lineStart = 0
                    var lineEnd = 0
                    var contentsEnd = 0
                    original.getLineStart(&lineStart, end: &lineEnd, contentsEnd: &contentsEnd, for: NSRange(location: max(0, insertionLocation - 1), length: 0))

                    if contentsEnd >= lineStart + 3,
                       lineStart + 2 <= original.length
                    {
                        let maybeDash = original.substring(with: NSRange(location: lineStart, length: 2))
                        if maybeDash == "- " {
                            let nextCharRange = NSRange(location: lineStart + 2, length: 1)
                            let nextChar = original.substring(with: nextCharRange)
                            if nextChar != "\n" && nextChar != "\r" && nextChar != " " && nextChar != "\t" {
                                isApplyingChange = true
                                textView.textStorage?.beginEditing()
                                textView.textStorage?.replaceCharacters(in: NSRange(location: lineStart, length: 2), with: parent.listPrefix)
                                textView.textStorage?.endEditing()
                                isApplyingChange = false
                                textView.didChangeText()
                            }
                        }
                    }
                }
            }

            parent.text = textView.string
        }

        private func maybeEmitTypingEffect(from textView: NSTextView) {
            guard parent.typingEffect != .off else { return }
            guard parent.isEditable else { return }

            let now = Date().timeIntervalSinceReferenceDate
            // Throttle a bit to keep typing smooth.
            guard now - lastEffectAt > 0.02 else { return }
            lastEffectAt = now

            guard let host = effectHost else { return }
            let caretLocation = max(0, textView.selectedRange().location)
            let caretRange = NSRange(location: min(caretLocation, (textView.string as NSString).length), length: 0)
            var caretRect = textView.firstRect(forCharacterRange: caretRange, actualRange: nil)
            if caretRect.isEmpty {
                caretRect = textView.visibleRect
            }
            // Convert screen -> host coords.
            if let window = textView.window {
                caretRect = window.convertFromScreen(caretRect)
                caretRect = host.convert(caretRect, from: nil as NSView?)
            }

            let point = CGPoint(x: caretRect.midX, y: caretRect.midY)
            host.emit(effect: parent.typingEffect, at: point)
        }

        func toggleList(in textView: NSTextView) {
            guard !parent.listPrefix.isEmpty else {
                NSSound.beep()
                return
            }

            if textView.string.isEmpty {
                textView.insertText(parent.listPrefix, replacementRange: NSRange(location: 0, length: 0))
                parent.text = textView.string
                return
            }

            let original = textView.string as NSString
            let selectedRange = textView.selectedRange()
            var lineStart = 0
            var lineEnd = 0
            var contentsEnd = 0
            original.getLineStart(&lineStart, end: &lineEnd, contentsEnd: &contentsEnd, for: selectedRange)

            let lineRanges = selectedLineRanges(in: original, from: lineStart, to: max(lineEnd, lineStart + 1))
            let prefixLength = (parent.listPrefix as NSString).length
            let allLinesHavePrefix = lineRanges.allSatisfy { range in
                hasPrefix(parent.listPrefix, in: original, lineRange: range)
            }

            isApplyingChange = true
            textView.textStorage?.beginEditing()

            for range in lineRanges.reversed() {
                if allLinesHavePrefix {
                    let removalRange = NSRange(location: range.location, length: prefixLength)
                    textView.textStorage?.replaceCharacters(in: removalRange, with: "")
                } else if !hasPrefix(parent.listPrefix, in: original, lineRange: range) {
                    textView.textStorage?.replaceCharacters(in: NSRange(location: range.location, length: 0), with: parent.listPrefix)
                }
            }

            textView.textStorage?.endEditing()
            isApplyingChange = false
            parent.text = textView.string
            textView.didChangeText()
        }

        private func selectedLineRanges(in string: NSString, from start: Int, to end: Int) -> [NSRange] {
            var ranges: [NSRange] = []
            var location = min(start, string.length)
            let upperBound = min(max(end, start), string.length)

            repeat {
                var lineStart = 0
                var lineEnd = 0
                var contentsEnd = 0
                string.getLineStart(&lineStart, end: &lineEnd, contentsEnd: &contentsEnd, for: NSRange(location: location, length: 0))
                ranges.append(NSRange(location: lineStart, length: max(0, contentsEnd - lineStart)))

                guard lineEnd > location else {
                    break
                }

                location = lineEnd
            } while location < upperBound

            return ranges
        }

        private func hasPrefix(_ prefix: String, in string: NSString, lineRange: NSRange) -> Bool {
            let prefixLength = (prefix as NSString).length
            guard lineRange.length >= prefixLength,
                  lineRange.location + prefixLength <= string.length else {
                return false
            }

            let actualPrefix = string.substring(with: NSRange(location: lineRange.location, length: prefixLength))
            return actualPrefix == prefix
        }
    }
}

final class EffectHostView: NSView {
    private let scrollView: NSScrollView
    private let overlay = EffectOverlayView(frame: .zero)

    var textView: NSTextView? { scrollView.documentView as? NSTextView }

    init(scrollView: NSScrollView) {
        self.scrollView = scrollView
        super.init(frame: .zero)

        wantsLayer = true

        addSubview(scrollView)
        addSubview(overlay)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        overlay.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            overlay.leadingAnchor.constraint(equalTo: leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: trailingAnchor),
            overlay.topAnchor.constraint(equalTo: topAnchor),
            overlay.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        overlay.isHidden = false
        overlay.alphaValue = 1
    }

    required init?(coder: NSCoder) {
        nil
    }

    func emit(effect: TypingEffect, at point: CGPoint) {
        overlay.emit(effect: effect, at: point)
    }
}

final class EffectOverlayView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
    }

    required init?(coder: NSCoder) {
        nil
    }

    func emit(effect: TypingEffect, at point: CGPoint) {
        switch effect {
        case .off:
            return
        case .confetti:
            emitConfetti(at: point)
        case .doom:
            emitDoom(at: point)
        }
    }

    private func emitConfetti(at point: CGPoint) {
        guard let layer else { return }
        let emitter = CAEmitterLayer()
        emitter.emitterPosition = point
        emitter.emitterShape = .point
        emitter.beginTime = CACurrentMediaTime()
        emitter.lifetime = 0.35

        let colors: [CGColor] = [
            NSColor.systemPink.cgColor,
            NSColor.systemTeal.cgColor,
            NSColor.systemYellow.cgColor,
            NSColor.systemPurple.cgColor,
            NSColor.systemOrange.cgColor
        ]

        emitter.emitterCells = (0..<10).map { _ in
            let cell = CAEmitterCell()
            cell.birthRate = 60
            cell.lifetime = 0.45
            cell.lifetimeRange = 0.2
            cell.velocity = 140
            cell.velocityRange = 80
            cell.emissionRange = .pi * 2
            cell.scale = 0.02
            cell.scaleRange = 0.015
            cell.spin = 6
            cell.spinRange = 8
            cell.alphaSpeed = -2.2
            cell.color = colors.randomElement()
            cell.contents = NSImage(systemSymbolName: "sparkle", accessibilityDescription: nil)?
                .withSymbolConfiguration(.init(pointSize: 12, weight: .regular))?
                .cgImage(forProposedRect: nil, context: nil, hints: nil)
            return cell
        }

        layer.addSublayer(emitter)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak emitter] in
            emitter?.removeFromSuperlayer()
        }
    }

    private func emitDoom(at point: CGPoint) {
        guard let layer else { return }
        let emitter = CAEmitterLayer()
        emitter.emitterPosition = point
        emitter.emitterShape = .circle
        emitter.emitterSize = CGSize(width: 4, height: 4)
        emitter.beginTime = CACurrentMediaTime()
        emitter.lifetime = 0.25

        let cell = CAEmitterCell()
        cell.birthRate = 220
        cell.lifetime = 0.25
        cell.lifetimeRange = 0.1
        cell.velocity = 220
        cell.velocityRange = 120
        cell.emissionRange = .pi * 2
        cell.scale = 0.03
        cell.scaleRange = 0.02
        cell.alphaSpeed = -4.0
        cell.color = NSColor.systemRed.cgColor
        cell.contents = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 10, weight: .bold))?
            .cgImage(forProposedRect: nil, context: nil, hints: nil)
        emitter.emitterCells = [cell]

        layer.addSublayer(emitter)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak emitter] in
            emitter?.removeFromSuperlayer()
        }
    }
}
