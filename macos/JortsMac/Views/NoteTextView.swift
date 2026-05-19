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

            guard let pointInTextView = caretPoint(in: textView) else { return }

            // textView -> window -> host
            let pointInWindow = textView.convert(pointInTextView, to: nil)
            let pointInHost = host.convert(pointInWindow, from: nil)
            host.emit(effect: parent.typingEffect, at: pointInHost)
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
                return CGPoint(x: rectInTextView.minX, y: rectInTextView.midY)
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
        overlay.layer?.masksToBounds = false
        overlay.layer?.zPosition = 999
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

    override func hitTest(_ point: NSPoint) -> NSView? {
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
        emitter.lifetime = 0.5

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
            cell.birthRate = 90
            cell.lifetime = 0.6
            cell.lifetimeRange = 0.2
            cell.velocity = 110
            cell.velocityRange = 80
            cell.emissionRange = .pi * 2
            cell.scale = 0.22
            cell.scaleRange = 0.12
            cell.spin = 3
            cell.spinRange = 5
            cell.alphaSpeed = -1.6
            cell.color = colors.randomElement()
            cell.contents = NSImage(systemSymbolName: "sparkle", accessibilityDescription: nil)?
                .withSymbolConfiguration(.init(pointSize: 12, weight: .regular))?
                .cgImage(forProposedRect: nil, context: nil, hints: nil)
            return cell
        }

        layer.addSublayer(emitter)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak emitter] in
            emitter?.removeFromSuperlayer()
        }
    }

    private func emitDoom(at point: CGPoint) {
        guard let layer else { return }
        let emitter = CAEmitterLayer()
        emitter.emitterPosition = point
        emitter.emitterShape = .circle
        emitter.emitterSize = CGSize(width: 10, height: 10)
        emitter.renderMode = .additive
        emitter.beginTime = CACurrentMediaTime()
        emitter.lifetime = 0.35

        let colors: [CGColor] = [
            NSColor.systemRed.cgColor,
            NSColor.systemOrange.cgColor,
            NSColor.systemYellow.cgColor,
            NSColor.systemPurple.cgColor,
            NSColor.systemBlue.cgColor
        ]

        let baseImage = NSImage(systemSymbolName: "sparkle", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 14, weight: .bold))?
            .cgImage(forProposedRect: nil, context: nil, hints: nil)

        emitter.emitterCells = (0..<5).map { i in
            let cell = CAEmitterCell()
            cell.birthRate = i == 0 ? 520 : 220
            cell.lifetime = 0.35
            cell.lifetimeRange = 0.18
            cell.velocity = i == 0 ? 290 : 220
            cell.velocityRange = 180
            cell.emissionRange = .pi * 2
            cell.scale = i == 0 ? 0.22 : 0.16
            cell.scaleRange = 0.12
            cell.alphaSpeed = -3.6
            cell.color = colors[i % colors.count]
            cell.contents = baseImage
            return cell
        }

        layer.addSublayer(emitter)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { [weak emitter] in
            emitter?.removeFromSuperlayer()
        }
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
