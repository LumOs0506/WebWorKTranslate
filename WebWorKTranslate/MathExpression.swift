import Foundation

struct MathError: LocalizedError, Equatable {
    let message: String
    var errorDescription: String? { message }
    init(_ message: String) { self.message = message }
}

/// A strict grammar: explicit grouping is preserved, without evaluating the answer.
indirect enum MathExpression: Equatable {
    case atom(String)
    case unary(String, MathExpression)
    case binary(String, MathExpression, MathExpression)
    case function(String, [MathExpression])
    case factorial(MathExpression)

    static let functions: Set<String> = [
        "sqrt", "abs", "ln", "log", "log10", "exp", "sin", "cos", "tan", "cot", "sec", "csc",
        "asin", "acos", "atan", "acot", "asec", "acsc", "arcsin", "arccos", "arctan", "arccot", "arcsec", "arccsc",
        "sinh", "cosh", "tanh", "coth", "sech", "csch", "asinh", "acosh", "atanh", "acoth", "asech", "acsch",
        "arcsinh", "arccosh", "arctanh", "arccoth", "arcsech", "arccsch", "fact", "sgn", "step", "P", "C"
    ]

    var output: String {
        switch self {
        case .atom(let value): return value
        case .unary(let op, let value): return "(\(op)\(value.output))"
        case .binary(let op, let lhs, let rhs): return "(\(lhs.output)\(op)\(rhs.output))"
        case .function("exp", let args): return "(e^(\(args[0].output)))"
        case .function(let name, let args): return "\(name)(\(args.map(\.output).joined(separator: ",")))"
        case .factorial(let value): return "(\(value.output))!"
        }
    }
    var webwork: String {
        switch self {
        case .binary, .unary: return String(output.dropFirst().dropLast())
        default: return output
        }
    }
    var containsInfinity: Bool {
        switch self {
        case .atom(let value): return value == "inf"
        case .unary(_, let value), .factorial(let value): return value.containsInfinity
        case .binary(_, let lhs, let rhs): return lhs.containsInfinity || rhs.containsInfinity
        case .function(_, let args): return args.contains(where: \.containsInfinity)
        }
    }
    var warnings: [String] {
        switch self {
        case .function(let name, let args):
            let note = name == "log" ? ["WebWorK’s log may mean natural log or base 10. Choose ln or log₁₀ to be explicit."] :
                ["P", "C", "step"].contains(name) ? ["\(name) is enabled only in some WebWorK problems."] : []
            return note + args.flatMap(\.warnings)
        case .binary(_, let lhs, let rhs): return lhs.warnings + rhs.warnings
        case .unary(_, let value), .factorial(let value): return value.warnings
        default: return []
        }
    }
}

struct ExpressionParser {
    private enum Token: Equatable { case atom(String), function(String), symbol(Character), end }
    private var tokens: [Token] = []
    private var index = 0
    init(_ source: String) throws {
        guard source.count <= 4000 else { throw MathError("This expression is too long. Use fewer than 4,000 characters.") }
        let text = Array(source.replacingOccurrences(of: "π", with: "pi")
            .replacingOccurrences(of: "∞", with: "inf").replacingOccurrences(of: "−", with: "-")
            .replacingOccurrences(of: "×", with: "*").replacingOccurrences(of: "·", with: "*")
            .replacingOccurrences(of: "÷", with: "/").replacingOccurrences(of: "**", with: "^"))
        var i = 0
        while i < text.count {
            let c = text[i]
            if c.isWhitespace { i += 1; continue }
            if c.isASCII && (c.isNumber || c == ".") {
                let start = i
                var dots = 0, digits = 0
                while i < text.count && (text[i].isNumber || text[i] == ".") {
                    if text[i] == "." { dots += 1 } else { digits += 1 }
                    i += 1
                }
                guard dots <= 1 && digits > 0 else { throw MathError("Check the decimal point in your number.") }
                if i < text.count && text[i] == "E" {
                    i += 1
                    if i < text.count && (text[i] == "+" || text[i] == "-") { i += 1 }
                    let start = i
                    while i < text.count && text[i].isNumber { i += 1 }
                    guard i > start else { throw MathError("Scientific notation needs an exponent, such as 2.1E-2.") }
                }
                tokens.append(.atom(String(text[start..<i])))
            } else if c.isASCII && c.isLetter {
                let start = i
                while i < text.count && text[i].isASCII && text[i].isLetter { i += 1 }
                var word = String(text[start..<i])
                if word == "log" && i + 1 < text.count && text[i] == "1" && text[i + 1] == "0" { word = "log10"; i += 2 }
                if MathExpression.functions.contains(word) { tokens.append(.function(word)) }
                else if ["pi", "e", "inf"].contains(word) { tokens.append(.atom(word)) }
                else if word.count == 1 { tokens.append(.atom(word)) }
                else if text[i...].first(where: { !$0.isWhitespace }) != "(" {
                    tokens += word.map { .atom(String($0)) }
                }
                else { throw MathError("Unknown name ‘\(word)’. Use the function pad or single-letter variables.") }
            } else if "+-*/^!(),[]{}".contains(c) { tokens.append(.symbol(c)); i += 1 }
            else { throw MathError("‘\(c)’ is not supported here. Enter an expression, without an equals sign.") }
        }
        tokens.append(.end)
    }
    mutating func parse() throws -> MathExpression {
        guard peek != .end else { throw MathError("Start with a number, variable, or template.") }
        let value = try expression()
        guard peek == .end else { throw MathError("Check your parentheses and operators.") }
        return value
    }
    private var peek: Token { tokens[min(index, tokens.count - 1)] }
    @discardableResult private mutating func take() -> Token { let token = peek; index += 1; return token }
    private mutating func expect(_ symbol: Character) throws {
        guard peek == .symbol(symbol) else { throw MathError("Complete the expression and close its parentheses.") }
        take()
    }
    private mutating func expression(_ minimum: Int = 0, depth: Int = 0) throws -> MathExpression {
        guard depth < 80 else { throw MathError("This expression has too many nested parts.") }
        var lhs: MathExpression
        switch take() {
        case .atom(let value): lhs = .atom(value)
        case .symbol("+"), .symbol("-"):
            let op = tokens[index - 1] == .symbol("-") ? "-" : "+"
            lhs = .unary(op, try expression(25, depth: depth + 1))
        case .symbol(let c) where "([{".contains(c):
            lhs = try expression(depth: depth + 1)
            try expect(c == "(" ? ")" : c == "[" ? "]" : "}")
        case .function(let name):
            try expect("(")
            var args = [try expression(depth: depth + 1)]
            while peek == .symbol(",") { take(); args.append(try expression(depth: depth + 1)) }
            try expect(")")
            guard args.count == (["P", "C"].contains(name) ? 2 : 1) else { throw MathError("Check the number of arguments for \(name).") }
            lhs = .function(name, args)
        default: throw MathError("An operand is missing. Fill each box and finish the expression.")
        }
        while true {
            if peek == .symbol("!") {
                guard 40 >= minimum else { break }
                take(); lhs = .factorial(lhs); continue
            }
            let op: String, precedence: Int, implicit: Bool
            switch peek {
            case .symbol("+"), .symbol("-"): op = peek == .symbol("+") ? "+" : "-"; precedence = 10; implicit = false
            case .symbol("*"), .symbol("/"): op = peek == .symbol("*") ? "*" : "/"; precedence = 20; implicit = false
            case .symbol("^"): op = "^"; precedence = 30; implicit = false
            case .atom, .function, .symbol("("), .symbol("["), .symbol("{"): op = "*"; precedence = 20; implicit = true
            default: return lhs
            }
            guard precedence >= minimum else { return lhs }
            if !implicit { take() }
            let rhs = try expression(op == "^" ? precedence : precedence + 1, depth: depth + 1)
            lhs = .binary(op, lhs, rhs)
        }
        return lhs
    }
}

struct MathNode: Identifiable, Codable, Equatable {
    enum Kind: String, Codable { case token, fraction, power, root, nthRoot, function, group, absolute, logBase, interval }
    var id = UUID()
    var kind: Kind
    var text = ""
    var children: [MathRow] = []
    static func token(_ text: String) -> MathNode { MathNode(kind: .token, text: text) }
    var raw: String {
        get throws {
            let parts = try children.map { try $0.raw }
            switch kind {
            case .token: return text
            case .fraction: return "((\(parts[0]))/(\(parts[1])))"
            case .power: return "((\(parts[0]))^(\(parts[1])))"
            case .root: return "sqrt(\(parts[0]))"
            case .nthRoot: return "((\(parts[1]))^(1/(\(parts[0]))))"
            case .function: return "\(text)(\(parts.joined(separator: ",")))"
            case .group: return "(\(parts[0]))"
            case .absolute: return "abs(\(parts[0]))"
            case .logBase: return "(ln(\(parts[1]))/ln(\(parts[0])))"
            case .interval: throw MathError("An interval must be the entire answer. Start a new expression for an interval.")
            }
        }
    }
}

struct MathRow: Identifiable, Codable, Equatable {
    var id = UUID()
    var nodes: [MathNode] = []
    init(nodes: [MathNode] = []) { self.nodes = nodes }
    init(text: String) { nodes = text.map { .token(String($0)) } }
    var raw: String {
        get throws {
            guard !nodes.isEmpty else { throw MathError("Fill every highlighted box to finish your expression.") }
            // Spaces separate constants from adjacent variables/functions while retaining digit runs.
            return try nodes.map { node in
                let value = try node.raw
                return node.kind != .token || ["pi", "inf", "e"].contains(node.text) ? " \(value) " : value
            }.joined()
        }
    }
    func row(_ target: UUID) -> MathRow? {
        if id == target { return self }
        for node in nodes { for child in node.children { if let found = child.row(target) { return found } } }
        return nil
    }
    mutating func edit(_ target: UUID, _ action: (inout MathRow) -> Void) {
        if id == target { action(&self); return }
        for n in nodes.indices { for c in nodes[n].children.indices { nodes[n].children[c].edit(target, action) } }
    }
    var rowIDs: [UUID] { [id] + nodes.flatMap { $0.children.flatMap(\.rowIDs) } }
    func parent(of target: UUID) -> (row: UUID, index: Int)? {
        for (i, node) in nodes.enumerated() {
            for child in node.children {
                if child.id == target { return (id, i) }
                if let found = child.parent(of: target) { return found }
            }
        }
        return nil
    }
    func translate() throws -> (output: String, warnings: [String]) {
        if nodes.count == 1, let node = nodes.first, node.kind == .interval {
            let values = try node.children.map { row -> MathExpression in
                var parser = try ExpressionParser(row.raw)
                return try parser.parse()
            }
            let lower = values[0], upper = values[1]
            let left = String(node.text.prefix(1)), right = String(node.text.suffix(1))
            if lower.containsInfinity && !(lower == .unary("-", .atom("inf")) && left == "(") {
                throw MathError("An infinite lower endpoint must be −∞ with an open parenthesis.")
            }
            if upper.containsInfinity && !(upper == .atom("inf") && right == ")") {
                throw MathError("An infinite upper endpoint must be ∞ with an open parenthesis.")
            }
            return ("\(left)\(lower.webwork),\(upper.webwork)\(right)", lower.warnings + upper.warnings)
        }
        var parser = try ExpressionParser(raw)
        let expression = try parser.parse()
        guard !expression.containsInfinity else { throw MathError("Use ∞ as an open interval endpoint, not in an arithmetic expression.") }
        return (expression.webwork, Array(Set(expression.warnings)).sorted())
    }
}

extension MathExpression {
    /// Rebuild parsed expressions as editable textbook templates for paste and examples.
    var mathRow: MathRow {
        switch self {
        case .atom(let text): return MathRow(nodes: text == "pi" || text == "inf" ? [.token(text)] : MathRow(text: text).nodes)
        case .unary(let op, let value): return MathRow(nodes: [.token(op), MathNode(kind: .group, children: [value.mathRow])])
        case .binary(let op, let lhs, let rhs):
            if op == "/" || op == "^" { return MathRow(nodes: [MathNode(kind: op == "/" ? .fraction : .power, children: [lhs.mathRow, rhs.mathRow])]) }
            func grouped(_ value: MathExpression) -> [MathNode] {
                if case .binary(let inner, _, _) = value, inner == "+" || inner == "-" {
                    return [MathNode(kind: .group, children: [value.mathRow])]
                }
                return value.mathRow.nodes
            }
            return MathRow(nodes: grouped(lhs) + [.token(op)] + grouped(rhs))
        case .factorial(let value): return MathRow(nodes: [MathNode(kind: .group, children: [value.mathRow]), .token("!")])
        case .function(let name, let args):
            return MathRow(nodes: [MathNode(kind: name == "sqrt" ? .root : name == "abs" ? .absolute : .function, text: name, children: args.map(\.mathRow))])
        }
    }
}
