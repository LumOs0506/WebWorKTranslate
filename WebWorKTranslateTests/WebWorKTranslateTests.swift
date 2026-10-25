import Foundation
import Testing
@testable import WebWorKTranslate

@MainActor
struct WebWorKTranslateTests {
    private func parse(_ source: String) throws -> MathExpression {
        var parser = try ExpressionParser(source)
        return try parser.parse()
    }

    @Test(arguments: [
        ("(x+1)/(x-2)", "(x+1)/(x-2)"),
        ("2x+3(x+1)", "(2*x)+(3*(x+1))"),
        ("-5^2", "-(5^2)"),
        ("(-5)^2", "(-5)^2"),
        ("2^3^4", "2^(3^4)"),
        ("1/2x", "(1/2)*x"),
        ("2/3*4", "(2/3)*4"),
        ("sqrt(x^2+1)", "sqrt(((x^2)+1))"),
        ("sin(pi/4)^2", "sin((pi/4))^2"),
        ("log10(100)+ln(e)", "log10(100)+ln(e)"),
        ("2.1E-2*x", "2.1E-2*x"),
        ("asin(x)", "asin(x)"),
        ("abs(-x)", "abs((-x))"),
        ("5!", "(5)!"),
        ("P(5,2)", "P(5,2)"),
        ("2**3", "2^3")
    ])
    func precedenceAndSyntax(_ sample: (String, String)) throws {
        #expect(try parse(sample.0).webwork == sample.1)
    }

    @Test(arguments: ["", "x+", "sqrt()", "2..1", ".", "2.1E-", "sin x", "(x+1", "x+1)", "x=2", "\\frac{x}{2}", "unknown(x)", "sin(x,y)", "P(2)", "x,,y"])
    func invalidInputIsRejected(_ source: String) {
        #expect(throws: MathError.self) { try parse(source) }
    }

    @Test(arguments: ["(x+1)/(x-2)", "-5^2", "(-5)^2", "2^3^4", "a-(b-c)", "(a+b)*(c-d)", "sin(pi/4)^2", "sqrt(x^2+1)", "2.1E-2*x", "x*sin(x)", "abs(-x)", "5!", "ln(e)", "P(5,2)", "a/(b/c)"])
    func textToTextbookRoundTripPreservesMeaning(_ source: String) throws {
        let expression = try parse(source)
        let row = expression.mathRow
        let translated = try row.translate().output
        #expect(try parse(translated) == expression)
    }

    @Test func nestedFractionAndPowerEditing() throws {
        let editor = MathEditor(defaults: nil)
        editor.insertText("12")
        editor.insertTemplate(.fraction)
        #expect(editor.output == nil)
        editor.insertText("x")
        editor.insertTemplate(.power)
        editor.insertText("2")
        #expect(try parse(#require(editor.output)) == parse("12/(x^2)"))
        editor.exitTemplate()
        editor.insertText("+1")
        #expect(try parse(#require(editor.output)) == parse("12/(x^2+1)"))
        editor.undo()
        #expect(try parse(#require(editor.output)) == parse("12/(x^2)"))
        editor.redo()
        #expect(try parse(#require(editor.output)) == parse("12/(x^2+1)"))
    }
    @Test func rootAndLogTemplates() throws {
        let root = MathNode(kind: .nthRoot, children: [MathRow(text: "3"), MathRow(text: "x+1")])
        #expect(try parse(MathRow(nodes: [root]).translate().output) == parse("(x+1)^(1/3)"))
        let log = MathNode(kind: .logBase, children: [MathRow(text: "2"), MathRow(text: "x")])
        #expect(try parse(MathRow(nodes: [log]).translate().output) == parse("ln(x)/ln(2)"))
    }
    @Test func functionsNextToVariablesMultiply() throws {
        let editor = MathEditor(defaults: nil)
        editor.insertText("x")
        editor.insertTemplate(.function, text: "sin")
        editor.insertText("t")
        #expect(try parse(#require(editor.output)) == parse("x*sin(t)"))
    }
    @Test func validAndInvalidIntervals() throws {
        let valid = MathNode(kind: .interval, text: "(]", children: [MathRow(nodes: [.token("-"), .token("inf")]), MathRow(text: "10")])
        #expect(try MathRow(nodes: [valid]).translate().output == "(-inf,10]")
        var invalid = valid
        invalid.text = "[]"
        #expect(throws: MathError.self) { try MathRow(nodes: [invalid]).translate() }
        #expect(throws: MathError.self) { try MathRow(nodes: [.token("2"), valid]).translate() }
        #expect(throws: MathError.self) { try MathRow(nodes: [.token("inf")]).translate() }
    }
    @Test func clearingCanBeUndoneAndInvalidPastePreservesDraft() throws {
        let editor = MathEditor(defaults: nil)
        #expect(editor.load("x^2+1"))
        let initial = editor.document
        #expect(!editor.load("sin("))
        #expect(editor.document == initial)
        editor.clear()
        #expect(editor.output == nil)
        editor.undo()
        #expect(editor.document == initial)
    }
    @Test func navigationAndEmptyTemplateDeletion() {
        let editor = MathEditor(defaults: nil)
        editor.insertTemplate(.fraction)
        let numerator = editor.cursor.row
        editor.nextSlot()
        #expect(editor.cursor.row != numerator)
        editor.backspace()
        #expect(editor.document.nodes.isEmpty)
        editor.undo()
        #expect(editor.document.nodes.count == 1)
        editor.move(-1)
        #expect(editor.document.row(editor.cursor.row) != nil)
    }
    @Test func persistenceAndHistory() throws {
        let suite = "WebWorKTranslate-tests-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let editor = MathEditor(defaults: defaults)
        editor.load("sqrt(2)")
        editor.save()
        let restored = MathEditor(defaults: defaults)
        #expect(restored.output == editor.output)
        #expect(restored.history.count == 1)
        restored.deleteHistory(restored.history[0].id)
        #expect(MathEditor(defaults: defaults).history.isEmpty)
    }
    @Test func ambiguousAndConditionalFunctionsExplainTheirLimits() throws {
        #expect(try parse("log(x)").warnings.count == 1)
        #expect(try parse("C(5,2)").warnings.count == 1)
        #expect(try parse("log10(x)").warnings.isEmpty)
    }
    @Test func typedFunctionPowerMatchesThePad() throws {
        let editor = MathEditor(defaults: nil)
        editor.insertText("sin")
        editor.insertTemplate(.group)
        editor.insertText("x")
        editor.exitTemplate()
        editor.insertTemplate(.power)
        editor.insertText("2")
        #expect(try parse(#require(editor.output)) == parse("sin(x)^2"))
        #expect(editor.document.nodes.first?.children.first?.nodes.first?.kind == .function)
    }
    @Test(arguments: ["12!", "2.1E-2", "3E2"])
    func powersWrapWholeNumbersAndPostfixOperators(_ source: String) throws {
        let editor = MathEditor(defaults: nil)
        editor.insertText(source)
        editor.insertTemplate(.power)
        editor.insertText("2")
        #expect(try parse(#require(editor.output)) == parse("(\(source))^2"))
    }
    @Test func adjacentSingleLetterVariables() throws {
        #expect(try parse("da").webwork == "d*a")
        #expect(try parse("xyz").webwork == "(x*y)*z")
    }
    @Test func typedConstantsAndFunctionCoefficients() throws {
        let editor = MathEditor(defaults: nil)
        editor.insertText("p")
        editor.insertText("i")
        editor.insertTemplate(.power)
        editor.insertText("2")
        #expect(try parse(#require(editor.output)) == parse("pi^2"))
        editor.clear()
        editor.insertText("2sin")
        editor.insertTemplate(.group)
        editor.insertText("x")
        editor.exitTemplate()
        editor.insertTemplate(.power)
        editor.insertText("2")
        #expect(try parse(#require(editor.output)) == parse("2*sin(x)^2"))
    }
}
