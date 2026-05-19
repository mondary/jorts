import Foundation

enum InlineCalculator {
    static func renderResultsColumn(from noteText: String) -> String {
        let lines = noteText.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var ctx = EvalContext()
        let results = lines.map { line -> String in
            guard let result = evaluateLine(line, ctx: &ctx) else { return "" }
            return format(result)
        }
        return results.joined(separator: "\n")
    }

    private static func evaluateLine(_ line: String, ctx: inout EvalContext) -> Value? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        var parser = LineParser(trimmed, ctx: ctx)
        let value = parser.parseLine()
        ctx = parser.ctx
        return value
    }

    private static func format(_ value: Value) -> String {
        guard value.number.isFinite else { return "" }

        let numberString: String
        if abs(value.number.rounded() - value.number) < 1e-10 {
            numberString = String(Int64(value.number.rounded()))
        } else {
            var s = String(format: "%.6f", value.number)
            while s.contains(".") && (s.hasSuffix("0") || s.hasSuffix(".")) {
                if s.hasSuffix(".") { s.removeLast(); break }
                s.removeLast()
            }
            numberString = s
        }

        if let unit = value.unit {
            return "\(numberString) \(unit.display)"
        }
        return numberString
    }
}

private struct EvalContext {
    var variables: [String: Value] = [:]
}

private struct Value: Equatable {
    var number: Double
    var unit: UnitSpec?
}

private enum UnitKind {
    case length, mass, duration, temperature
}

private struct UnitSpec: Equatable {
    let kind: UnitKind
    let unit: Dimension
    let display: String
}

private enum UnitRegistry {
    static func parseUnit(_ raw: String) -> UnitSpec? {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let u = length[s] { return u }
        if let u = mass[s] { return u }
        if let u = duration[s] { return u }
        if let u = temperature[s] { return u }
        return nil
    }

    static func convert(_ value: Value, to target: UnitSpec) -> Value? {
        guard let from = value.unit else { return nil }
        guard from.kind == target.kind else { return nil }
        let measurement = Measurement(value: value.number, unit: from.unit)
        let converted = measurement.converted(to: target.unit)
        return Value(number: converted.value, unit: target)
    }

    private static let length: [String: UnitSpec] = [
        "mm": .init(kind: .length, unit: UnitLength.millimeters, display: "mm"),
        "cm": .init(kind: .length, unit: UnitLength.centimeters, display: "cm"),
        "m": .init(kind: .length, unit: UnitLength.meters, display: "m"),
        "km": .init(kind: .length, unit: UnitLength.kilometers, display: "km"),
        "in": .init(kind: .length, unit: UnitLength.inches, display: "in"),
        "ft": .init(kind: .length, unit: UnitLength.feet, display: "ft"),
        "yd": .init(kind: .length, unit: UnitLength.yards, display: "yd"),
        "mi": .init(kind: .length, unit: UnitLength.miles, display: "mi")
    ]

    private static let mass: [String: UnitSpec] = [
        "mg": .init(kind: .mass, unit: UnitMass.milligrams, display: "mg"),
        "g": .init(kind: .mass, unit: UnitMass.grams, display: "g"),
        "kg": .init(kind: .mass, unit: UnitMass.kilograms, display: "kg"),
        "oz": .init(kind: .mass, unit: UnitMass.ounces, display: "oz"),
        "lb": .init(kind: .mass, unit: UnitMass.pounds, display: "lb")
    ]

    private static let duration: [String: UnitSpec] = [
        "ms": .init(kind: .duration, unit: UnitDuration.milliseconds, display: "ms"),
        "s": .init(kind: .duration, unit: UnitDuration.seconds, display: "s"),
        "sec": .init(kind: .duration, unit: UnitDuration.seconds, display: "s"),
        "min": .init(kind: .duration, unit: UnitDuration.minutes, display: "min"),
        "h": .init(kind: .duration, unit: UnitDuration.hours, display: "h"),
        "hr": .init(kind: .duration, unit: UnitDuration.hours, display: "h")
    ]

    private static let temperature: [String: UnitSpec] = [
        "c": .init(kind: .temperature, unit: UnitTemperature.celsius, display: "°C"),
        "°c": .init(kind: .temperature, unit: UnitTemperature.celsius, display: "°C"),
        "f": .init(kind: .temperature, unit: UnitTemperature.fahrenheit, display: "°F"),
        "°f": .init(kind: .temperature, unit: UnitTemperature.fahrenheit, display: "°F"),
        "k": .init(kind: .temperature, unit: UnitTemperature.kelvin, display: "K")
    ]
}

private struct LineParser {
    private let input: String
    fileprivate var ctx: EvalContext
    private var tokens: [Token]
    private var pos: Int = 0

    init(_ input: String, ctx: EvalContext) {
        self.input = input
        self.ctx = ctx
        var tokenizer = Tokenizer(input)
        self.tokens = tokenizer.tokenize()
    }

    mutating func parseLine() -> Value? {
        guard !tokens.isEmpty else { return nil }

        // assignment: <ident> '=' expr
        if case let .ident(name)? = peek(), peek(offset: 1) == .eq {
            _ = advance()
            _ = advance()
            guard let value = parseExpr() else { return nil }
            ctx.variables[name] = value
            return parseConversionSuffix(from: value) ?? (pos == tokens.count ? value : nil)
        }

        guard let value = parseExpr() else { return nil }
        return parseConversionSuffix(from: value) ?? (pos == tokens.count ? value : nil)
    }

    private mutating func parseConversionSuffix(from value: Value) -> Value? {
        guard let t = peek() else { return nil }
        guard t == .opWord("in") || t == .opWord("to") || t == .opWord("en") else { return nil }
        _ = advance()
        guard case let .unit(target)? = peek() else { return nil }
        _ = advance()
        guard pos == tokens.count else { return nil }
        return UnitRegistry.convert(value, to: target)
    }

    // expr := term (('+'|'-') term)*
    private mutating func parseExpr() -> Value? {
        guard var value = parseTerm() else { return nil }
        while true {
            guard let t = peek() else { break }
            if t == .plus || t == .minus {
                _ = advance()
                guard let rhs = parseTerm() else { return nil }
                value = applyAddSub(lhs: value, rhs: rhs, op: t)
                if !value.number.isFinite { return nil }
            } else {
                break
            }
        }
        return value
    }

    // term := power (('*'|'/'|'%') power)*
    private mutating func parseTerm() -> Value? {
        guard var value = parsePower() else { return nil }
        while true {
            guard let t = peek() else { break }
            if t == .mul || t == .div || t == .mod {
                _ = advance()
                guard let rhs = parsePower() else { return nil }
                value = applyMulDivMod(lhs: value, rhs: rhs, op: t)
                if !value.number.isFinite { return nil }
            } else {
                break
            }
        }
        return value
    }

    // power := factor ('^' factor)*
    private mutating func parsePower() -> Value? {
        guard var value = parseFactor() else { return nil }
        while peek() == .pow {
            _ = advance()
            guard let rhs = parseFactor() else { return nil }
            guard rhs.unit == nil else { return nil }
            value.number = Foundation.pow(value.number, rhs.number)
            if !value.number.isFinite { return nil }
        }
        return value
    }

    // factor := number[unit]? | ident | '(' expr ')' | ('+'|'-') factor
    private mutating func parseFactor() -> Value? {
        guard let t = peek() else { return nil }
        if t == .plus || t == .minus {
            _ = advance()
            guard var inner = parseFactor() else { return nil }
            if t == .minus { inner.number *= -1 }
            return inner
        }
        if t == .lparen {
            _ = advance()
            guard let inner = parseExpr() else { return nil }
            guard peek() == .rparen else { return nil }
            _ = advance()
            return inner
        }
        if case let .number(n, attachedUnit) = t {
            _ = advance()
            var value = Value(number: n, unit: attachedUnit)
            // "10 kg"
            if value.unit == nil, case let .unit(u)? = peek() {
                _ = advance()
                value.unit = u
            }
            return value
        }
        if case let .ident(name) = t {
            _ = advance()
            return ctx.variables[name]
        }
        return nil
    }

    private func applyAddSub(lhs: Value, rhs: Value, op: Token) -> Value {
        if lhs.unit == nil && rhs.unit == nil {
            return Value(number: op == .plus ? (lhs.number + rhs.number) : (lhs.number - rhs.number), unit: nil)
        }
        if let u = lhs.unit, rhs.unit == nil {
            return Value(number: op == .plus ? (lhs.number + rhs.number) : (lhs.number - rhs.number), unit: u)
        }
        if lhs.unit == nil, let u = rhs.unit {
            return Value(number: op == .plus ? (lhs.number + rhs.number) : (lhs.number - rhs.number), unit: u)
        }
        guard let lu = lhs.unit, let ru = rhs.unit else { return Value(number: .nan, unit: nil) }
        guard lu.kind == ru.kind else { return Value(number: .nan, unit: nil) }
        guard let rhsConverted = UnitRegistry.convert(rhs, to: lu) else { return Value(number: .nan, unit: nil) }
        return Value(number: op == .plus ? (lhs.number + rhsConverted.number) : (lhs.number - rhsConverted.number), unit: lu)
    }

    private func applyMulDivMod(lhs: Value, rhs: Value, op: Token) -> Value {
        switch op {
        case .mul:
            if lhs.unit != nil, rhs.unit != nil { return Value(number: .nan, unit: nil) }
            if let u = lhs.unit { return Value(number: lhs.number * rhs.number, unit: u) }
            if let u = rhs.unit { return Value(number: lhs.number * rhs.number, unit: u) }
            return Value(number: lhs.number * rhs.number, unit: nil)
        case .div:
            guard rhs.number != 0 else { return Value(number: .nan, unit: nil) }
            if lhs.unit != nil, rhs.unit != nil { return Value(number: .nan, unit: nil) }
            if let u = lhs.unit { return Value(number: lhs.number / rhs.number, unit: u) }
            if rhs.unit != nil { return Value(number: .nan, unit: nil) }
            return Value(number: lhs.number / rhs.number, unit: nil)
        case .mod:
            guard rhs.number != 0 else { return Value(number: .nan, unit: nil) }
            if lhs.unit != nil || rhs.unit != nil { return Value(number: .nan, unit: nil) }
            return Value(number: lhs.number.truncatingRemainder(dividingBy: rhs.number), unit: nil)
        default:
            return Value(number: .nan, unit: nil)
        }
    }

    private func peek(offset: Int = 0) -> Token? {
        let p = pos + offset
        guard p >= 0, p < tokens.count else { return nil }
        return tokens[p]
    }

    @discardableResult
    private mutating func advance() -> Token? {
        guard pos < tokens.count else { return nil }
        let t = tokens[pos]
        pos += 1
        return t
    }
}

private enum Token: Equatable {
    case number(Double, UnitSpec?)
    case ident(String)
    case unit(UnitSpec)
    case opWord(String)
    case plus, minus, mul, div, mod, pow
    case lparen, rparen
    case eq
}

private struct Tokenizer {
    private let chars: [Character]
    private var i: Int = 0

    init(_ s: String) {
        self.chars = Array(s)
    }

    mutating func tokenize() -> [Token] {
        var out: [Token] = []
        while let c = peek() {
            if c == " " || c == "\t" { _ = advance(); continue }
            if c.isNumber || c == "." || c == "," {
                guard let token = readNumber() else { return [] }
                out.append(token)
                continue
            }
            if c == "(" { _ = advance(); out.append(.lparen); continue }
            if c == ")" { _ = advance(); out.append(.rparen); continue }
            if c == "+" { _ = advance(); out.append(.plus); continue }
            if c == "-" { _ = advance(); out.append(.minus); continue }
            if c == "*" || c == "×" { _ = advance(); out.append(.mul); continue }
            if c == "/" { _ = advance(); out.append(.div); continue }
            if c == "%" { _ = advance(); out.append(.mod); continue }
            if c == "^" { _ = advance(); out.append(.pow); continue }
            if c == "=" { _ = advance(); out.append(.eq); continue }
            if c.isLetter || c == "°" {
                let word = readWord()
                let lowered = word.lowercased()
                if lowered == "in" || lowered == "to" || lowered == "en" {
                    out.append(.opWord(lowered))
                } else if lowered == "x" {
                    out.append(.mul)
                } else if let unit = UnitRegistry.parseUnit(lowered) {
                    out.append(.unit(unit))
                } else {
                    out.append(.ident(lowered))
                }
                continue
            }
            return []
        }
        return out
    }

    private mutating func readNumber() -> Token? {
        let start = i
        var sawDigit = false
        var sawDot = false
        while let c = peek() {
            if c.isNumber { sawDigit = true; _ = advance(); continue }
            if (c == "." || c == ",") && !sawDot { sawDot = true; _ = advance(); continue }
            break
        }
        guard sawDigit else { return nil }
        let raw = String(chars[start..<i]).replacingOccurrences(of: ",", with: ".")
        guard let number = Double(raw) else { return nil }

        // Attached unit: "10kg"
        let unitStart = i
        while let c = peek(), c.isLetter || c == "°" {
            _ = advance()
        }
        if i > unitStart {
            let unitRaw = String(chars[unitStart..<i])
            if let unit = UnitRegistry.parseUnit(unitRaw) {
                return .number(number, unit)
            }
            i = unitStart
        }
        return .number(number, nil)
    }

    private mutating func readWord() -> String {
        let start = i
        while let c = peek(), c.isLetter || c == "°" {
            _ = advance()
        }
        return String(chars[start..<i])
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

private extension Character {
    var isLetter: Bool { unicodeScalars.allSatisfy { CharacterSet.letters.contains($0) } }
}
