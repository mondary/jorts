import Foundation

enum InlineCalculator {
    static func renderResultsColumn(from noteText: String) -> String {
        let lines = noteText.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let results = lines.map { line -> String in
            guard let result = evaluateLine(line) else { return "" }
            return format(result)
        }
        return results.joined(separator: "\n")
    }

    private static func evaluateLine(_ line: String) -> Double? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Allow: digits, whitespace, operators, parens, decimal separators.
        // Require at least one operator to avoid echoing plain numbers.
        let allowed = CharacterSet(charactersIn: "0123456789+-*/%()., ").inverted
        guard trimmed.rangeOfCharacter(from: allowed) == nil else { return nil }
        guard trimmed.contains(where: { "+-*/%".contains($0) }) else { return nil }

        // Normalize decimal separator.
        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        var parser = ExpressionParser(normalized)
        return parser.parseAndEval()
    }

    private static func format(_ value: Double) -> String {
        if value.isNaN || value.isInfinite { return "" }
        if abs(value.rounded() - value) < 1e-10 {
            return String(Int64(value.rounded()))
        }
        var s = String(format: "%.6f", value)
        while s.contains(".") && (s.hasSuffix("0") || s.hasSuffix(".")) {
            if s.hasSuffix(".") { s.removeLast(); break }
            s.removeLast()
        }
        return s
    }
}

private struct ExpressionParser {
    private let chars: [Character]
    private var i: Int = 0

    init(_ s: String) {
        self.chars = Array(s)
    }

    mutating func parseAndEval() -> Double? {
        skipSpaces()
        guard let value = parseExpr() else { return nil }
        skipSpaces()
        guard i == chars.count else { return nil }
        return value
    }

    // expr := term (('+'|'-') term)*
    private mutating func parseExpr() -> Double? {
        guard var value = parseTerm() else { return nil }
        while true {
            skipSpaces()
            guard let op = peek(), op == "+" || op == "-" else { break }
            _ = advance()
            guard let rhs = parseTerm() else { return nil }
            value = (op == "+") ? (value + rhs) : (value - rhs)
        }
        return value
    }

    // term := factor (('*'|'/'|'%') factor)*
    private mutating func parseTerm() -> Double? {
        guard var value = parseFactor() else { return nil }
        while true {
            skipSpaces()
            guard let op = peek(), op == "*" || op == "/" || op == "%" else { break }
            _ = advance()
            guard let rhs = parseFactor() else { return nil }
            switch op {
            case "*": value *= rhs
            case "/":
                guard rhs != 0 else { return nil }
                value /= rhs
            case "%":
                guard rhs != 0 else { return nil }
                value = value.truncatingRemainder(dividingBy: rhs)
            default:
                return nil
            }
        }
        return value
    }

    // factor := number | '(' expr ')' | ('+'|'-') factor
    private mutating func parseFactor() -> Double? {
        skipSpaces()
        guard let c = peek() else { return nil }

        if c == "+" || c == "-" {
            _ = advance()
            guard let inner = parseFactor() else { return nil }
            return (c == "-") ? -inner : inner
        }

        if c == "(" {
            _ = advance()
            guard let value = parseExpr() else { return nil }
            skipSpaces()
            guard peek() == ")" else { return nil }
            _ = advance()
            return value
        }

        return parseNumber()
    }

    private mutating func parseNumber() -> Double? {
        skipSpaces()
        let start = i
        var sawDigit = false
        var sawDot = false

        while let c = peek() {
            if c.isNumber {
                sawDigit = true
                _ = advance()
                continue
            }
            if c == "." && !sawDot {
                sawDot = true
                _ = advance()
                continue
            }
            break
        }

        guard sawDigit else { return nil }
        let s = String(chars[start..<i])
        return Double(s)
    }

    private mutating func skipSpaces() {
        while let c = peek(), c == " " || c == "\t" {
            _ = advance()
        }
    }

    private func peek() -> Character? {
        guard i < chars.count else { return nil }
        return chars[i]
    }

    @discardableResult
    private mutating func advance() -> Character? {
        guard i < chars.count else { return nil }
        let c = chars[i]
        i += 1
        return c
    }
}
