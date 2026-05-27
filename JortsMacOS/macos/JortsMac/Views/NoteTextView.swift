import AppKit
import SwiftUI

struct NoteTextView: NSViewRepresentable {
    @Binding var text: String
    let onShiftTabToTitle: () -> Void
    let focusRequestToken: Int
    let isEditable: Bool
    let typingEffect: TypingEffect
    let showsInlineCalculations: Bool
    let showsInlineBrandIcons: Bool

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
        host.setInlineCalculationsVisible(showsInlineCalculations)
        host.updateInlineCalculations(noteText: text, font: font, color: textColor)
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
        host.setInlineCalculationsVisible(showsInlineCalculations)

        if textView.string != text && !context.coordinator.isApplyingChange {
            let selectedRange = textView.selectedRange()
            textView.string = text
            textView.setSelectedRange(selectedRange.clamped(toLength: (text as NSString).length))
        }

        // Ensure brand icons are present even when a note is reopened (text is reloaded from storage).
        // This only affects the displayed attributed string; stored text remains plain via sanitization.
        context.coordinator.applyBrandIconsIfNeeded(in: textView)

        host.updateInlineCalculations(noteText: textView.string, font: font, color: textColor)

        if context.coordinator.lastToggleListRequestToken != toggleListRequestToken {
            context.coordinator.lastToggleListRequestToken = toggleListRequestToken
            context.coordinator.toggleList(in: textView)
        }

        if context.coordinator.lastFocusRequestToken != focusRequestToken {
            context.coordinator.lastFocusRequestToken = focusRequestToken
            context.coordinator.needsDeferredFocusToTop = true
        }

        if context.coordinator.needsDeferredFocusToTop, textView.window != nil {
            context.coordinator.needsDeferredFocusToTop = false
            textView.window?.makeFirstResponder(textView)
            let top = NSRange(location: 0, length: 0)
            textView.setSelectedRange(top)
            textView.scrollRangeToVisible(top)
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
        var needsDeferredFocusToTop = false
        weak var effectHost: EffectHostView?
        weak var textView: NSTextView?
        private var lastEffectAt: TimeInterval = 0
        private var lastCaretHostPoint: CGPoint?
        private var lastCaretAt: TimeInterval = 0

        init(_ parent: NoteTextView) {
            self.parent = parent
        }

        func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
            guard !isApplyingChange,
                  let replacementString else {
                return true
            }

            if completeBrandBadgeIfNeeded(in: textView, range: affectedCharRange, replacement: replacementString) {
                return false
            }

            guard !parent.listPrefix.isEmpty else {
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

            // Never persist NSTextAttachment placeholders (U+FFFC) into storage.
            parent.text = sanitizedPlainText(from: textView)
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            // Hyper-style effects: show feedback when moving caret, not only when typing.
            if parent.typingEffect == .doom {
                maybeEmitTypingEffect(from: textView)
            }
        }

        private func maybeEmitTypingEffect(from textView: NSTextView) {
            guard parent.typingEffect != .off else { return }
            guard parent.isEditable else { return }

            let now = Date().timeIntervalSinceReferenceDate
            // Throttle a bit to keep typing smooth.
            guard now - lastEffectAt > 0.02 else { return }
            lastEffectAt = now

            guard let host = effectHost else { return }

            guard let pointInTextView = caretPoint(in: textView) else { return }

            // textView -> window -> host
            let pointInWindow = textView.convert(pointInTextView, to: nil)
            var pointInHost = host.convert(pointInWindow, from: nil)

            // Place the effect slightly to the right of the caret so it doesn't sit "under" the glyph.
            if parent.typingEffect == .doom {
                pointInHost.x += max(6, (textView.font?.pointSize ?? 14) * 0.45)
            }

            var direction: CGVector?
            if parent.typingEffect == .doom {
                let dt = max(0.001, now - lastCaretAt)
                if let prev = lastCaretHostPoint {
                    let dx = pointInHost.x - prev.x
                    let dy = pointInHost.y - prev.y
                    // Normalize to a direction vector; scale down so emitter stays subtle.
                    let len = max(1.0, sqrt(dx * dx + dy * dy))
                    direction = CGVector(dx: dx / len, dy: dy / len)
                }
                lastCaretHostPoint = pointInHost
                lastCaretAt = now
                _ = dt
            }

            host.emit(effect: parent.typingEffect, at: pointInHost, direction: direction)
        }

        private func completeBrandBadgeIfNeeded(in textView: NSTextView, range: NSRange, replacement: String) -> Bool {
            guard parent.showsInlineBrandIcons,
                  range.length == 0,
                  InlineBrandIcons.shouldComplete(after: replacement) else {
                return false
            }

            let original = textView.string as NSString
            guard range.location <= original.length else { return false }

            var start = range.location
            while start > 0 {
                let prev = Character(original.substring(with: NSRange(location: start - 1, length: 1)))
                guard prev.isLetter || prev.isNumber else { break }
                start -= 1
            }

            guard start < range.location else { return false }
            let tokenRange = NSRange(location: start, length: range.location - start)
            let token = original.substring(with: tokenRange)
            guard let badge = InlineBrandIcons.badge(for: token) else { return false }

            if range.location + 1 <= original.length {
                let existing = original.substring(with: NSRange(location: range.location, length: 1))
                if existing == " " {
                    return false
                }
            }

            isApplyingChange = true
            if let attachment = BrandIconAttachment.make(for: badge, font: parent.font) {
                let attributed = NSMutableAttributedString(string: " ")
                attributed.append(NSAttributedString(attachment: attachment))
                attributed.append(NSAttributedString(string: replacement))
                textView.textStorage?.replaceCharacters(in: range, with: attributed)
            } else {
                textView.insertText(" \(badge.title)\(replacement)", replacementRange: range)
            }
            isApplyingChange = false
            parent.text = sanitizedPlainText(from: textView)
            textView.didChangeText()
            return true
        }

        func applyBrandIconsIfNeeded(in textView: NSTextView) {
            guard parent.showsInlineBrandIcons else { return }
            guard !isApplyingChange else { return }
            guard let storage = textView.textStorage else { return }

            // We regenerate icons from the plain text. This keeps storage clean and makes reopen deterministic.
            let plain = sanitizedPlainText(from: textView)
            let ns = plain as NSString
            if ns.length == 0 { return }

            // Apply only if the displayed string is currently plain (no attachments). This avoids rework.
            if textView.string.contains("\u{FFFC}") {
                return
            }

            let fullRange = NSRange(location: 0, length: ns.length)
            var rangesToReplace: [(tokenRange: NSRange, badge: InlineBrandIcons.Badge)] = []

            ns.enumerateSubstrings(in: fullRange, options: [.byWords, .localized]) { substring, substringRange, _, _ in
                guard let token = substring else { return }
                guard let badge = InlineBrandIcons.badge(for: token) else { return }
                rangesToReplace.append((substringRange, badge))
            }

            guard !rangesToReplace.isEmpty else { return }

            // Replace from end to start so ranges stay valid.
            isApplyingChange = true
            storage.beginEditing()
            for item in rangesToReplace.reversed() {
                let tokenEnd = item.tokenRange.location + item.tokenRange.length
                if tokenEnd < ns.length {
                    let nextChar = ns.substring(with: NSRange(location: tokenEnd, length: 1))
                    // If there's already a space after the token, keep it; we'll still insert icon after that.
                    _ = nextChar
                }

                guard let attachment = BrandIconAttachment.make(for: item.badge, font: parent.font) else { continue }
                let insert = NSMutableAttributedString(string: " ")
                insert.append(NSAttributedString(attachment: attachment))
                storage.insert(insert, at: tokenEnd)
            }
            storage.endEditing()
            isApplyingChange = false
        }

        private func sanitizedPlainText(from textView: NSTextView) -> String {
            // NSTextAttachment appears as U+FFFC in string. We also remove the leading space we insert before icons.
            // This keeps persisted notes clean and stable.
            let raw = textView.string
            if !raw.contains("\u{FFFC}") { return raw }
            var out = raw.replacingOccurrences(of: " \u{FFFC}", with: "")
            out = out.replacingOccurrences(of: "\u{FFFC}", with: "")
            return out
        }

        private func caretPoint(in textView: NSTextView) -> CGPoint? {
            let stringLength = (textView.string as NSString).length
            let caretLocation = min(max(0, textView.selectedRange().location), stringLength)

            // Prefer AppKit's caret rect (screen coords), but avoid falling back to a generic visibleRect center,
            // which makes effects appear "random" on screen.
            let caretRange = NSRange(location: caretLocation, length: 0)
            let screenRect = textView.firstRect(forCharacterRange: caretRange, actualRange: nil)
            if !screenRect.isEmpty, let window = textView.window {
                let windowRect = window.convertFromScreen(screenRect)
                let rectInTextView = textView.convert(windowRect, from: nil)
                // Anchor on the right edge of the caret rect to place effects "after" the cursor.
                return CGPoint(x: rectInTextView.maxX, y: rectInTextView.midY)
            }

            guard let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer else {
                return nil
            }

            layoutManager.ensureLayout(for: textContainer)

            let anchorCharIndex = max(0, min(caretLocation, max(0, stringLength - 1)))
            let glyphIndex = layoutManager.glyphIndexForCharacter(at: anchorCharIndex)
            let lineRect = layoutManager.lineFragmentUsedRect(forGlyphAt: glyphIndex, effectiveRange: nil)
            let glyphLocation = layoutManager.location(forGlyphAt: glyphIndex)
            let origin = textView.textContainerOrigin

            let x = origin.x + lineRect.minX + glyphLocation.x
            let y = origin.y + lineRect.minY + glyphLocation.y + (textView.font?.ascender ?? 0) * 0.35
            return CGPoint(x: x, y: y)
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

private enum BrandIconAttachment {
    private static var cache: [String: NSImage] = [:]

    static func make(for badge: InlineBrandIcons.Badge, font: NSFont) -> NSTextAttachment? {
        guard let iconFile = badge.iconFile,
              let image = image(named: iconFile) else {
            return nil
        }
        let size = max(13, min(18, font.pointSize + 1))
        let attachment = NSTextAttachment()
        attachment.image = image
        attachment.bounds = NSRect(x: 0, y: (font.descender + 1), width: size, height: size)
        return attachment
    }

    private static func image(named name: String) -> NSImage? {
        if let cached = cache[name] { return cached }
        guard let url = Bundle.module.url(forResource: name, withExtension: "svg", subdirectory: "BrandIcons"),
              let image = NSImage(contentsOf: url) else {
            return nil
        }
        cache[name] = image
        return image
    }
}

final class EffectHostView: NSView {
    private let scrollView: NSScrollView
    private let overlay = EffectOverlayView(frame: .zero)
    private let inlineCalcView = InlineCalcResultsView(frame: .zero)
    private var lastShakeAt: TimeInterval = 0

    var textView: NSTextView? { scrollView.documentView as? NSTextView }

    init(scrollView: NSScrollView) {
        self.scrollView = scrollView
        super.init(frame: .zero)

        wantsLayer = true

        addSubview(scrollView)
        addSubview(overlay)
        scrollView.contentView.addSubview(inlineCalcView)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        overlay.translatesAutoresizingMaskIntoConstraints = false
        inlineCalcView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            overlay.leadingAnchor.constraint(equalTo: leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: trailingAnchor),
            overlay.topAnchor.constraint(equalTo: topAnchor),
            overlay.bottomAnchor.constraint(equalTo: bottomAnchor),

            inlineCalcView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            inlineCalcView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            inlineCalcView.bottomAnchor.constraint(equalTo: scrollView.contentView.bottomAnchor),
            inlineCalcView.widthAnchor.constraint(equalToConstant: 160)
        ])

        overlay.isHidden = false
        overlay.alphaValue = 1
        overlay.layer?.masksToBounds = false
        overlay.layer?.zPosition = 999

        inlineCalcView.isHidden = true
        inlineCalcView.alphaValue = 1
        inlineCalcView.layer?.zPosition = 10
    }

    required init?(coder: NSCoder) {
        nil
    }

    func emit(effect: TypingEffect, at point: CGPoint, direction: CGVector? = nil) {
        if effect == .doom {
            shakeWindowIfNeeded()
        }
        overlay.emit(effect: effect, at: point, direction: direction)
    }

    private func shakeWindowIfNeeded() {
        let now = Date().timeIntervalSinceReferenceDate
        guard now - lastShakeAt > 0.08 else { return }
        lastShakeAt = now

        guard let window else { return }
        let originalFrame = window.frame
        let offsets: [CGFloat] = [-3, 4, -2, 2, 0]

        for (index, dx) in offsets.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.014) { [weak window] in
                guard let window else { return }
                var frame = originalFrame
                frame.origin.x += dx
                window.setFrame(frame, display: false)
            }
        }
    }

    func setInlineCalculationsVisible(_ visible: Bool) {
        inlineCalcView.isHidden = !visible
    }

    func updateInlineCalculations(noteText: String, font: NSFont, color: NSColor) {
        inlineCalcView.update(noteText: noteText, font: font, color: color)
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

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    func emit(effect: TypingEffect, at point: CGPoint, direction: CGVector? = nil) {
        switch effect {
        case .off:
            return
        case .confetti:
            emitConfetti(at: point)
        case .doom:
            emitDoom(at: point, direction: direction)
        case .typewriter:
            emitTypewriter(at: point)
        case .wave:
            emitWave(at: point)
        case .pop:
            emitPop(at: point)
        case .glow:
            emitGlow(at: point)
        }
    }

    private func emitConfetti(at point: CGPoint) {
        guard let layer else { return }
        let emitter = CAEmitterLayer()
        emitter.emitterPosition = point
        emitter.emitterShape = .point
        emitter.renderMode = .additive
        emitter.beginTime = CACurrentMediaTime()
        emitter.lifetime = 0.22

        let colors: [CGColor] = [
            NSColor.systemPink.cgColor,
            NSColor.systemRed.cgColor,
            NSColor.systemOrange.cgColor,
            NSColor.systemYellow.cgColor,
            NSColor.systemGreen.cgColor,
            NSColor.systemTeal.cgColor,
            NSColor.systemBlue.cgColor,
            NSColor.systemPurple.cgColor
        ]

        emitter.emitterCells = (0..<10).map { _ in
            let cell = CAEmitterCell()
            cell.birthRate = 55
            cell.lifetime = 0.26
            cell.lifetimeRange = 0.10
            cell.velocity = 110
            cell.velocityRange = 80
            cell.emissionRange = .pi * 2
            cell.scale = 0.22
            cell.scaleRange = 0.12
            cell.spin = 3
            cell.spinRange = 5
            cell.alphaSpeed = -3.0
            cell.color = colors.randomElement()
            cell.contents = NSImage(systemSymbolName: "sparkle", accessibilityDescription: nil)?
                .withSymbolConfiguration(.init(pointSize: 12, weight: .regular))?
                .cgImage(forProposedRect: nil, context: nil, hints: nil)
            return cell
        }

        layer.addSublayer(emitter)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak emitter] in
            emitter?.removeFromSuperlayer()
        }
    }

    private func emitDoom(at point: CGPoint, direction: CGVector?) {
        guard let layer else { return }
        // Hyperpower-style caret trail: bright burst, short trail, fast fade.
        let emitter = CAEmitterLayer()
        emitter.emitterPosition = point
        emitter.emitterShape = .point
        emitter.renderMode = .additive
        emitter.beginTime = CACurrentMediaTime()
        emitter.lifetime = 0.22
        let baseAngle: CGFloat? = direction.map { atan2($0.dy, $0.dx) }

        let colors: [CGColor] = [
            NSColor.systemRed.cgColor,
            NSColor.systemOrange.cgColor,
            NSColor.systemYellow.cgColor,
            NSColor.systemPink.cgColor,
            NSColor.systemPurple.cgColor,
            NSColor.systemBlue.cgColor
        ]

        let square = makeParticleImage(size: 8, cornerRadius: 1.5)
        let spark = NSImage(systemSymbolName: "sparkle", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 14, weight: .bold))?
            .cgImage(forProposedRect: nil, context: nil, hints: nil)

        let streak = CAEmitterCell()
        streak.birthRate = 420
        streak.lifetime = 0.20
        streak.lifetimeRange = 0.06
        streak.velocity = 140
        streak.velocityRange = 70
        if let baseAngle { streak.emissionLongitude = baseAngle }
        streak.emissionRange = .pi / 3
        streak.scale = 0.48
        streak.scaleRange = 0.20
        streak.scaleSpeed = -1.6
        streak.alphaSpeed = -5.0
        streak.spin = 5
        streak.spinRange = 8
        streak.color = colors.randomElement()
        streak.contents = square

        let burst = CAEmitterCell()
        burst.birthRate = 120
        burst.lifetime = 0.14
        burst.lifetimeRange = 0.05
        burst.velocity = 190
        burst.velocityRange = 90
        if let baseAngle { burst.emissionLongitude = baseAngle }
        burst.emissionRange = .pi * 2
        burst.scale = 0.22
        burst.scaleRange = 0.10
        burst.scaleSpeed = -2.0
        burst.alphaSpeed = -6.4
        burst.color = colors.randomElement()
        burst.contents = spark

        emitter.emitterCells = [streak, burst]

        layer.addSublayer(emitter)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) { [weak emitter] in
            emitter?.removeFromSuperlayer()
        }
    }

    private func makeParticleImage(size: CGFloat, cornerRadius: CGFloat) -> CGImage? {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        NSColor.white.setFill()
        NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: size, height: size), xRadius: cornerRadius, yRadius: cornerRadius).fill()
        image.unlockFocus()
        return image.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }

    private func emitTypewriter(at point: CGPoint) {
        guard let layer else { return }

        // Create a small letter that appears with bounce effect
        let bounceLayer = CAShapeLayer()
        let letterPath = NSBezierPath(rect: CGRect(x: -6, y: -8, width: 12, height: 16))
        bounceLayer.path = letterPath.cgPath
        bounceLayer.position = point
        bounceLayer.fillColor = NSColor.labelColor.cgColor
        bounceLayer.opacity = 0.8

        layer.addSublayer(bounceLayer)

        // Bounce animation - like a typewriter key being pressed
        let bounceAnimation = CAKeyframeAnimation(keyPath: "transform.scale.y")
        bounceAnimation.values = [1.0, 0.3, 1.2, 1.0]
        bounceAnimation.keyTimes = [0, 0.2, 0.5, 1.0]
        bounceAnimation.duration = 0.3
        bounceAnimation.isRemovedOnCompletion = false
        bounceAnimation.fillMode = .forwards

        // Slight horizontal compression too
        let scaleXAnimation = CAKeyframeAnimation(keyPath: "transform.scale.x")
        scaleXAnimation.values = [1.0, 1.3, 0.9, 1.0]
        scaleXAnimation.keyTimes = [0, 0.2, 0.5, 1.0]
        scaleXAnimation.duration = 0.3
        scaleXAnimation.isRemovedOnCompletion = false
        scaleXAnimation.fillMode = .forwards

        // Fade out
        let fadeAnimation = CABasicAnimation(keyPath: "opacity")
        fadeAnimation.fromValue = 0.8
        fadeAnimation.toValue = 0.0
        fadeAnimation.beginTime = CACurrentMediaTime() + 0.2
        fadeAnimation.duration = 0.15
        fadeAnimation.isRemovedOnCompletion = false
        fadeAnimation.fillMode = .forwards

        bounceLayer.add(bounceAnimation, forKey: "bounce")
        bounceLayer.add(scaleXAnimation, forKey: "scaleX")
        bounceLayer.add(fadeAnimation, forKey: "fade")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak bounceLayer] in
            bounceLayer?.removeFromSuperlayer()
        }
    }

    private func emitWave(at point: CGPoint) {
        guard let layer else { return }

        // Create a wavy line that passes through the typing point
        let waveLayer = CAShapeLayer()
        let wavePath = NSBezierPath()

        // Create a sine wave
        let amplitude: CGFloat = 8
        let frequency: CGFloat = 0.3
        let width: CGFloat = 80

        wavePath.move(to: CGPoint(x: point.x - width/2, y: point.y))

        for i in 0..<20 {
            let x = point.x - width/2 + (CGFloat(i) / 20.0) * width
            let normalizedX = CGFloat(i) / 20.0
            let y = point.y + sin(normalizedX * .pi * 2 * frequency) * amplitude
            wavePath.line(to: CGPoint(x: x, y: y))
        }

        waveLayer.path = wavePath.cgPath
        waveLayer.strokeColor = NSColor.systemBlue.cgColor
        waveLayer.fillColor = NSColor.clear.cgColor
        waveLayer.lineWidth = 2.0
        waveLayer.lineCap = .round
        waveLayer.opacity = 0.7

        layer.addSublayer(waveLayer)

        // Wave animation - move horizontally
        let moveAnimation = CABasicAnimation(keyPath: "transform.translation.x")
        moveAnimation.fromValue = -20
        moveAnimation.toValue = 20
        moveAnimation.duration = 0.4
        moveAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)

        // Scale wave as it expands
        let scaleAnimation = CABasicAnimation(keyPath: "transform.scale.x")
        scaleAnimation.fromValue = 0.5
        scaleAnimation.toValue = 1.5
        scaleAnimation.duration = 0.4
        scaleAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)

        // Fade out
        let fadeAnimation = CABasicAnimation(keyPath: "opacity")
        fadeAnimation.fromValue = 0.7
        fadeAnimation.toValue = 0.0
        fadeAnimation.duration = 0.4
        fadeAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)

        waveLayer.add(moveAnimation, forKey: "move")
        waveLayer.add(scaleAnimation, forKey: "scale")
        waveLayer.add(fadeAnimation, forKey: "fade")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak waveLayer] in
            waveLayer?.removeFromSuperlayer()
        }
    }

    private func emitPop(at point: CGPoint) {
        guard let layer else { return }

        // Create a circle that pops at the cursor position
        let popLayer = CAShapeLayer()
        let circlePath = NSBezierPath(ovalIn: CGRect(x: -10, y: -10, width: 20, height: 20))
        popLayer.path = circlePath.cgPath
        popLayer.position = point
        popLayer.fillColor = NSColor.systemPurple.withAlphaComponent(0.6).cgColor
        popLayer.strokeColor = NSColor.systemPurple.cgColor
        popLayer.lineWidth = 1.5

        layer.addSublayer(popLayer)

        // Scale animation - quick pop then settle
        let scaleAnimation = CAKeyframeAnimation(keyPath: "transform.scale")
        scaleAnimation.values = [0.1, 1.4, 1.0, 0.8]
        scaleAnimation.keyTimes = [0, 0.15, 0.3, 1.0]
        scaleAnimation.duration = 0.35
        scaleAnimation.timingFunctions = [
            CAMediaTimingFunction(name: .easeOut),
            CAMediaTimingFunction(name: .easeIn),
            CAMediaTimingFunction(name: .easeOut)
        ]
        scaleAnimation.isRemovedOnCompletion = false
        scaleAnimation.fillMode = .forwards

        // Rotation for extra flair
        let rotateAnimation = CABasicAnimation(keyPath: "transform.rotation")
        rotateAnimation.fromValue = 0
        rotateAnimation.toValue = CGFloat.pi * 0.25
        rotateAnimation.duration = 0.35
        rotateAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        rotateAnimation.isRemovedOnCompletion = false
        rotateAnimation.fillMode = .forwards

        // Fade out
        let fadeAnimation = CABasicAnimation(keyPath: "opacity")
        fadeAnimation.fromValue = 1.0
        fadeAnimation.toValue = 0.0
        fadeAnimation.beginTime = CACurrentMediaTime() + 0.15
        fadeAnimation.duration = 0.2
        fadeAnimation.isRemovedOnCompletion = false
        fadeAnimation.fillMode = .forwards

        popLayer.add(scaleAnimation, forKey: "scale")
        popLayer.add(rotateAnimation, forKey: "rotate")
        popLayer.add(fadeAnimation, forKey: "fade")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak popLayer] in
            popLayer?.removeFromSuperlayer()
        }
    }

    private func emitGlow(at point: CGPoint) {
        guard let layer else { return }

        // Create a glowing starburst effect
        let glowLayer = CALayer()
        glowLayer.position = point

        // Central glow
        let centerGlow = CAShapeLayer()
        let centerPath = NSBezierPath(ovalIn: CGRect(x: -8, y: -8, width: 16, height: 16))
        centerGlow.path = centerPath.cgPath
        centerGlow.fillColor = NSColor.systemYellow.withAlphaComponent(0.8).cgColor
        glowLayer.addSublayer(centerGlow)

        // Starburst rays
        for i in 0..<8 {
            let ray = CAShapeLayer()
            let angle = CGFloat(i) * CGFloat.pi / 4
            let length: CGFloat = 25
            let rayPath = NSBezierPath()
            rayPath.move(to: CGPoint(x: 0, y: 0))
            rayPath.line(to: CGPoint(
                x: cos(angle) * length,
                y: sin(angle) * length
            ))

            ray.path = rayPath.cgPath
            ray.strokeColor = NSColor.systemYellow.withAlphaComponent(0.9).cgColor
            ray.lineWidth = 2.0
            ray.lineCap = .round
            glowLayer.addSublayer(ray)
        }

        // Outer glow ring
        let ringLayer = CAShapeLayer()
        let ringPath = NSBezierPath(ovalIn: CGRect(x: -15, y: -15, width: 30, height: 30))
        ringLayer.path = ringPath.cgPath
        ringLayer.strokeColor = NSColor.systemYellow.withAlphaComponent(0.5).cgColor
        ringLayer.fillColor = NSColor.clear.cgColor
        ringLayer.lineWidth = 1.5
        glowLayer.addSublayer(ringLayer)

        layer.addSublayer(glowLayer)

        // Scale up and rotate
        let scaleAnimation = CAKeyframeAnimation(keyPath: "transform.scale")
        scaleAnimation.values = [0.2, 1.3, 1.0]
        scaleAnimation.keyTimes = [0, 0.3, 1.0]
        scaleAnimation.duration = 0.4
        scaleAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        scaleAnimation.isRemovedOnCompletion = false
        scaleAnimation.fillMode = .forwards

        let rotateAnimation = CABasicAnimation(keyPath: "transform.rotation")
        rotateAnimation.fromValue = 0
        rotateAnimation.toValue = CGFloat.pi * 0.5
        rotateAnimation.duration = 0.4
        rotateAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        rotateAnimation.isRemovedOnCompletion = false
        rotateAnimation.fillMode = .forwards

        // Fade out
        let fadeAnimation = CABasicAnimation(keyPath: "opacity")
        fadeAnimation.fromValue = 1.0
        fadeAnimation.toValue = 0.0
        fadeAnimation.beginTime = CACurrentMediaTime() + 0.2
        fadeAnimation.duration = 0.2
        fadeAnimation.isRemovedOnCompletion = false
        fadeAnimation.fillMode = .forwards

        glowLayer.add(scaleAnimation, forKey: "scale")
        glowLayer.add(rotateAnimation, forKey: "rotate")
        glowLayer.add(fadeAnimation, forKey: "fade")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak glowLayer] in
            glowLayer?.removeFromSuperlayer()
        }
    }
}

final class InlineCalcResultsView: NSView {
    private let textLayer = CATextLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true

        textLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
        textLayer.alignmentMode = .right
        textLayer.isWrapped = true
        textLayer.truncationMode = .none
        layer?.addSublayer(textLayer)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func layout() {
        super.layout()
        textLayer.frame = bounds.insetBy(dx: 10, dy: 8)
    }

    func update(noteText: String, font: NSFont, color: NSColor) {
        let resultsText = InlineCalculator.renderResultsColumn(from: noteText)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .right
        paragraph.lineBreakMode = .byClipping
        paragraph.minimumLineHeight = font.defaultLineHeight(for: font)
        paragraph.maximumLineHeight = font.defaultLineHeight(for: font)

        let attributed = NSAttributedString(
            string: resultsText,
            attributes: [
                .font: font,
                .foregroundColor: color.withAlphaComponent(0.55),
                .paragraphStyle: paragraph
            ]
        )
        textLayer.string = attributed
        needsLayout = true
    }
}

private extension NSFont {
    func defaultLineHeight(for font: NSFont) -> CGFloat {
        font.ascender - font.descender + font.leading
    }
}
