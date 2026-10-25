import SwiftUI
import AppKit

// A warm paper surface and a restrained calculator palette, independent of system theme.
enum Palette {
    static let paper = Color(red: 0.97, green: 0.96, blue: 0.94)
    static let sidebar = Color(red: 0.93, green: 0.92, blue: 0.89)
    static let ink = Color(red: 0.15, green: 0.20, blue: 0.20)
    static let muted = Color(red: 0.43, green: 0.47, blue: 0.46)
    static let accent = Color(red: 0.72, green: 0.30, blue: 0.16)
    static let line = Color(red: 0.85, green: 0.85, blue: 0.81)
}

struct ContentView: View {
    @State private var editor = MathEditor()
    @State private var category = "Algebra"
    @State private var showingGuide = false
    @State private var showingHistory = false
    @State private var copied = false
    @FocusState private var mathFocused: Bool
    private let categories = ["Algebra", "Trig", "Functions", "Variables"]

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    expressionCard
                    outputCard
                    keypad
                    footer
                }
                .padding(32)
                .frame(maxWidth: 1000)
                .frame(maxWidth: .infinity)
            }
            .background(Palette.paper)
        }
        .frame(minWidth: 920, minHeight: 730)
        .foregroundStyle(Palette.ink)
        .tint(Palette.accent)
        .preferredColorScheme(.light)
        .sheet(isPresented: $showingGuide) { guide }
        .sheet(isPresented: $showingHistory) { recent }
        .onChange(of: editor.document) { copied = false }
        .onAppear { mathFocused = true }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Text("ƒ").font(.system(size: 31, weight: .medium, design: .serif))
                    .frame(width: 42, height: 42).foregroundStyle(.white)
                    .background(Palette.ink, in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 1) {
                    Text("WebWorK").font(.system(size: 17, weight: .bold))
                    Text("TRANSLATE").font(.system(size: 9, weight: .semibold)).tracking(2.5)
                }
            }.padding(.bottom, 36)
            Text("YOUR WORKSPACE").font(.system(size: 9, weight: .bold)).tracking(1.6).foregroundStyle(Palette.muted)
                .padding(.bottom, 14)
            Label("Expression pad", systemImage: "square.and.pencil")
                .font(.system(size: 13, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading).padding(12)
                .foregroundStyle(Palette.accent)
                .background(Palette.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            sidebarButton("Recent expressions", icon: "clock") { showingHistory = true }
            sidebarButton("Syntax guide", icon: "book.closed") { showingGuide = true }
            Rectangle().fill(Palette.line).frame(height: 1).padding(.vertical, 24)
            Text("TRY AN EXAMPLE").font(.system(size: 9, weight: .bold)).tracking(1.6).foregroundStyle(Palette.muted)
                .padding(.bottom, 14)
            example("A fraction", detail: "Grouping made clear", source: "(x+1)/(x-2)")
            example("Roots & powers", detail: "A little more structure", source: "sqrt(x^2+1)")
            example("Trigonometry", detail: "Functions in radians", source: "sin(pi/4)^2")
            example("Logarithms", detail: "An explicit base", source: "log10(100)+ln(x)")
            Spacer(minLength: 30)
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "pencil.and.outline").font(.system(size: 21)).foregroundStyle(Palette.accent)
                Text("Think in math.\nPaste in WebWorK.")
                    .font(.system(size: 18, weight: .medium, design: .serif)).lineSpacing(3)
                Text("Your expressions stay on this Mac.")
                    .font(.system(size: 11)).foregroundStyle(Palette.muted).lineSpacing(3)
            }
        }
        .padding(22).frame(width: 224).frame(maxHeight: .infinity)
        .background(Palette.sidebar)
        .overlay(alignment: .trailing) { Rectangle().fill(Palette.line).frame(width: 1) }
    }
    private func sidebarButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon).font(.system(size: 13))
                .frame(maxWidth: .infinity, alignment: .leading).padding(12)
        }.buttonStyle(.plain)
    }
    private func example(_ title: String, detail: String, source: String) -> some View {
        Button { editor.load(source); mathFocused = true } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.system(size: 12, weight: .semibold))
                    Text(detail).font(.system(size: 10)).foregroundStyle(Palette.muted)
                }
                Spacer()
                Image(systemName: "arrow.up.right").font(.system(size: 10)).foregroundStyle(Palette.muted)
            }.padding(.vertical, 11)
        }.buttonStyle(.plain).help("Load example. Undo returns to your expression.")
    }
    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 7) {
                Text("MATH, WITHOUT THE SYNTAX GUESSWORK").font(.system(size: 9, weight: .bold)).tracking(1.6).foregroundStyle(Palette.accent)
                Text("Write it your way.").font(.system(size: 33, weight: .medium, design: .serif))
                Text("Build a textbook expression. Get WebWorK notation, instantly.")
                    .font(.system(size: 12)).foregroundStyle(Palette.muted)
            }
            Spacer()
            Text("RAD").font(.system(size: 10, weight: .bold, design: .monospaced))
                .padding(.horizontal, 10).padding(.vertical, 6)
                .overlay(Capsule().stroke(Palette.line)).padding(.top, 6)
                .help("WebWorK trigonometric functions use radians.")
        }
    }
    private var expressionCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                sectionLabel("01", "YOUR EXPRESSION")
                Spacer()
                Button { paste() } label: { Image(systemName: "doc.on.clipboard") }.help("Paste a plain math expression (⌘V)").keyboardShortcut("v", modifiers: .command)
                Button { editor.undo(); mathFocused = true } label: { Image(systemName: "arrow.uturn.backward") }.disabled(!editor.canUndo).help("Undo (⌘Z)").keyboardShortcut("z", modifiers: .command)
                Button { editor.redo(); mathFocused = true } label: { Image(systemName: "arrow.uturn.forward") }.disabled(!editor.canRedo).help("Redo (⇧⌘Z)").keyboardShortcut("z", modifiers: [.command, .shift])
                Button("Clear") { editor.clear(); mathFocused = true }.font(.system(size: 11))
            }.buttonStyle(.borderless).padding(18)
            ScrollView(.horizontal) {
                EquationRowView(row: editor.document, cursor: editor.cursor, size: 32) { row, offset in
                    editor.select(row, offset); mathFocused = true
                }
                .frame(minHeight: 115).padding(.horizontal, 22).padding(.vertical, 10)
            }
            .focusable().focusEffectDisabled().focused($mathFocused)
            .onKeyPress(phases: .down) { press in handleKey(press) }
            .accessibilityIdentifier("expressionEditor")
            HStack(spacing: 5) {
                Image(systemName: "cursorarrow.click").font(.system(size: 10))
                Text("Click any part to edit. Use Tab to move between slots.")
                Spacer()
                Button { editor.move(-1); mathFocused = true } label: { Image(systemName: "arrow.left") }.help("Move cursor left")
                Button { editor.move(1); mathFocused = true } label: { Image(systemName: "arrow.right") }.help("Move cursor right")
            }
            .font(.system(size: 10)).foregroundStyle(Palette.muted).buttonStyle(.borderless).padding(16)
            .background(Palette.paper.opacity(0.65))
        }
        .background(.white, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.line, lineWidth: 1))
    }
    private var outputCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                sectionLabel("02", "WEBWORK NOTATION", dark: true)
                Spacer()
                if editor.output != nil {
                    Label("Ready to copy", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 10)).foregroundStyle(Color(red: 0.64, green: 0.80, blue: 0.67))
                }
            }
            HStack(alignment: .center, spacing: 16) {
                Group {
                    if let output = editor.output {
                        Text(output).font(.system(size: 19, weight: .medium, design: .monospaced))
                            .textSelection(.enabled).foregroundStyle(.white)
                            .accessibilityIdentifier("webworkOutput")
                    } else {
                        Text(editor.document.nodes.isEmpty ? "Your translation will appear here" : "Complete your expression to translate")
                            .font(.system(size: 15, design: .monospaced)).foregroundStyle(.white.opacity(0.5))
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
                Button { copyOutput() } label: {
                    Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 12, weight: .semibold)).padding(.horizontal, 16).padding(.vertical, 11)
                        .background(editor.output == nil ? Color.white.opacity(0.08) : Palette.accent, in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain).foregroundStyle(.white).disabled(editor.output == nil)
                .keyboardShortcut("c", modifiers: [.command, .shift]).accessibilityIdentifier("copyOutput")
            }
            if case .failure(let error) = editor.result, !editor.document.nodes.isEmpty {
                Label(error.localizedDescription, systemImage: "info.circle").font(.system(size: 11)).foregroundStyle(Color(red: 1, green: 0.77, blue: 0.53))
            }
            if case .success(let result) = editor.result {
                ForEach(result.warnings, id: \.self) { warning in
                    Label(warning, systemImage: "info.circle").font(.system(size: 11)).foregroundStyle(Color(red: 1, green: 0.77, blue: 0.53))
                }
            }
        }
        .padding(20).background(Palette.ink, in: RoundedRectangle(cornerRadius: 14))
    }
    private func sectionLabel(_ number: String, _ title: String, dark: Bool = false) -> some View {
        HStack(spacing: 9) {
            Text(number).foregroundStyle(dark ? .white.opacity(0.45) : Palette.accent)
            Text(title).foregroundStyle(dark ? .white.opacity(0.75) : Palette.muted)
        }.font(.system(size: 9, weight: .bold, design: .monospaced)).tracking(1.2)
    }
    private var keypad: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("The math pad").font(.system(size: 19, weight: .medium, design: .serif))
                Spacer()
                Button { editor.save() } label: { Label("Save expression", systemImage: "bookmark") }
                    .font(.system(size: 11)).buttonStyle(.borderless).disabled(editor.output == nil)
            }
            HStack(alignment: .top, spacing: 22) {
                VStack(spacing: 12) {
                    HStack(spacing: 3) {
                        ForEach(categories, id: \.self) { item in
                            Button { category = item } label: {
                                Text(item).font(.system(size: 10, weight: .semibold))
                                    .frame(maxWidth: .infinity).padding(.vertical, 8)
                                    .background(category == item ? .white : .clear, in: RoundedRectangle(cornerRadius: 6))
                                    .foregroundStyle(category == item ? Palette.ink : Palette.muted)
                            }.buttonStyle(.plain)
                        }
                    }.padding(3).background(Palette.sidebar, in: RoundedRectangle(cornerRadius: 8))
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 4), spacing: 7) {
                        ForEach(functionKeys, id: \.self) { key in padKey(key, function: true) }
                    }
                }.frame(maxWidth: .infinity)
                Rectangle().fill(Palette.line).frame(width: 1, height: 248)
                VStack(spacing: 7) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 4), spacing: 7) {
                        ForEach(["7", "8", "9", "⌫", "4", "5", "6", "÷", "1", "2", "3", "×", "0", ".", "−", "+"], id: \.self) { key in padKey(key) }
                    }
                    HStack(spacing: 7) {
                        Button { editor.nextSlot(); mathFocused = true } label: { Label("Next slot", systemImage: "arrow.right.to.line") }
                            .frame(maxWidth: .infinity).help("Tab: move to the next template slot")
                        Button { editor.exitTemplate(); mathFocused = true } label: { Label("Exit", systemImage: "arrow.up.right") }
                            .frame(maxWidth: .infinity).help("Escape: move outside the current template")
                    }.font(.system(size: 11, weight: .medium)).buttonStyle(.borderless).padding(.top, 9)
                }.frame(width: 244)
            }
            if let notice = editor.notice {
                Text(notice).font(.system(size: 11)).foregroundStyle(Palette.accent).accessibilityIdentifier("editorNotice")
            }
        }
    }
    private var functionKeys: [String] {
        switch category {
        case "Trig": return ["sin", "cos", "tan", "π", "asin", "acos", "atan", "θ → t", "csc", "sec", "cot", "|x|", "sinh", "cosh", "tanh", "xʸ"]
        case "Functions": return ["ln", "log₁₀", "logₐ", "eˣ", "sgn", "n!", "P(n,k)", "C(n,k)", "asinh", "acosh", "atanh", "step", "csch", "sech", "coth", "√"]
        case "Variables": return ["x", "y", "z", "t", "a", "b", "c", "n", "r", "u", "v", "w", "π", "e", "∞", "E"]
        default: return ["a⁄b", "xʸ", "√", "ⁿ√", "( )", "|x|", "π", "e", "ln", "log₁₀", "x", "y", "[a,b]", "(a,b)", "[a,b)", "(a,b]"]
        }
    }
    private func padKey(_ key: String, function: Bool = false) -> some View {
        Button { activate(key); mathFocused = true } label: {
            Text(key).font(.system(size: function ? 17 : 20, weight: .regular, design: function ? .serif : .rounded))
                .frame(maxWidth: .infinity).frame(height: 44)
                .foregroundStyle(["+", "−", "×", "÷", "⌫"].contains(key) ? Palette.accent : Palette.ink)
                .background(function ? Palette.sidebar.opacity(0.75) : .white, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.line.opacity(0.7), lineWidth: 0.7))
        }.buttonStyle(.plain).accessibilityLabel(keyDescription(key)).help(keyDescription(key))
    }
    private func keyDescription(_ key: String) -> String {
        ["a⁄b": "Fraction", "xʸ": "Power", "√": "Square root", "ⁿ√": "Nth root", "⌫": "Backspace", "( )": "Parentheses", "|x|": "Absolute value", "logₐ": "Log with base", "log₁₀": "Base 10 logarithm", "eˣ": "Exponential", "θ → t": "Use t for theta", "E": "Scientific notation exponent" ][key] ?? key
    }
    private func activate(_ key: String) {
        switch key {
        case "a⁄b", "÷", "/": editor.insertTemplate(.fraction)
        case "xʸ", "^": editor.insertTemplate(.power)
        case "√": editor.insertTemplate(.root)
        case "ⁿ√": editor.insertTemplate(.nthRoot)
        case "( )", "(": editor.insertTemplate(.group)
        case "|x|": editor.insertTemplate(.absolute)
        case "logₐ": editor.insertTemplate(.logBase)
        case "log₁₀": editor.insertTemplate(.function, text: "log10")
        case "eˣ": editor.insertText("e"); editor.insertTemplate(.power)
        case "P(n,k)", "C(n,k)": editor.insertTemplate(.function, text: String(key.prefix(1)))
        case "n!": editor.insertText("!")
        case "π": editor.insertText("pi")
        case "∞": editor.insertText("inf")
        case "θ → t": editor.insertText("t")
        case "×": editor.insertText("*")
        case "−": editor.insertText("-")
        case "⌫": editor.backspace()
        case "[a,b]", "(a,b)", "[a,b)", "(a,b]": editor.insertTemplate(.interval, text: String(key.prefix(1)) + String(key.suffix(1)))
        default:
            if MathExpression.functions.contains(key) { editor.insertTemplate(.function, text: key) }
            else { editor.insertText(key) }
        }
    }
    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        if press.modifiers.contains(.command) || press.modifiers.contains(.control) { return .ignored }
        switch press.key {
        case .leftArrow: editor.move(-1)
        case .rightArrow: editor.move(1)
        case .upArrow: editor.nextSlot(backwards: true)
        case .downArrow: editor.nextSlot()
        case .tab: editor.nextSlot(backwards: press.modifiers.contains(.shift))
        case .escape, .return: editor.exitTemplate()
        case .delete: editor.backspace()
        default:
            if press.characters == ")" { editor.exitTemplate() }
            else if !press.characters.isEmpty && press.characters.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || ".+-*/^!(".contains($0)) }) {
                for character in press.characters { activate(String(character)) }
            } else { return .ignored }
        }
        return .handled
    }
    private func paste() {
        if let value = NSPasteboard.general.string(forType: .string) { editor.load(value) }
        else { editor.notice = "The clipboard does not contain a text expression." }
        mathFocused = true
    }
    private func copyOutput() {
        guard let output = editor.output else { return }
        NSPasteboard.general.clearContents()
        copied = NSPasteboard.general.setString(output, forType: .string)
    }
    private var footer: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "info.circle")
            Text("Translation preserves your math; it does not solve it. Use WebWorK’s Preview before submitting. Available functions and variables depend on the problem.")
        }.font(.system(size: 10)).foregroundStyle(Palette.muted).lineSpacing(3)
    }
    private var guide: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("A little syntax, a lot of clarity.").font(.system(size: 26, design: .serif))
                Spacer(); Button("Done") { showingGuide = false }.keyboardShortcut(.cancelAction)
            }
            Text("Click a box in a template, then use the pad or type. Tab moves between slots; arrows move the cursor; Escape exits a template. Fraction and power wrap the preceding number or template. Undo works with ⌘Z.")
            Grid(alignment: .leading, horizontalSpacing: 35, verticalSpacing: 13) {
                guideRow("Textbook", "WebWorK")
                guideRow("A fraction", "(x+1)/(x-2)")
                guideRow("A power / nth root", "x^2 / x^(1/3)")
                guideRow("Natural / base 10 logarithm", "ln(x) / log10(x)")
                guideRow("Inverse sine", "asin(x)")
                guideRow("Absolute value / factorial", "abs(x) / n!")
                guideRow("Scientific notation", "2.1E-2")
                guideRow("An interval", "(-inf,10]")
            }.padding(18).background(.white, in: RoundedRectangle(cornerRadius: 12))
            Text("All trig functions use radians. Inverse trig is a function such as asin, not the reciprocal 1/sin. An arbitrary-base log uses ln(x)/ln(base); log alone can be redefined by an instructor.")
            Text("Paste accepts plain expressions such as sqrt(x^2+1), not LaTeX. Use the interval templates for intervals. Equations, matrices, derivatives, and integrals are not supported in this version.")
                .foregroundStyle(Palette.muted)
            Link("Open the official WebWorK notation reference ↗", destination: URL(string: "https://wiki.openwebwork.org/wiki/Available_Functions")!)
        }.font(.system(size: 13)).lineSpacing(4).padding(30).frame(width: 650).background(Palette.paper)
    }
    private func guideRow(_ title: String, _ value: String) -> some View {
        GridRow { Text(title); Text(value).font(.system(size: 12, design: .monospaced)) }
    }
    private var recent: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Recent expressions").font(.system(size: 26, design: .serif))
                Spacer(); Button("Done") { showingHistory = false }.keyboardShortcut(.cancelAction)
            }
            Text("Up to 20 saved expressions, stored on this Mac.").foregroundStyle(Palette.muted)
            if editor.history.isEmpty {
                ContentUnavailableView("A clean page", systemImage: "bookmark", description: Text("Use Save expression to keep a result here."))
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(editor.history) { entry in
                            HStack {
                                Button {
                                    editor.replace(entry.document); showingHistory = false; mathFocused = true
                                } label: {
                                    VStack(alignment: .leading, spacing: 7) {
                                        Text(entry.output).font(.system(size: 14, design: .monospaced)).lineLimit(3)
                                        Text(entry.date, format: .dateTime.month().day().hour().minute()).font(.system(size: 10)).foregroundStyle(Palette.muted)
                                    }.frame(maxWidth: .infinity, alignment: .leading)
                                }.buttonStyle(.plain)
                                Button { editor.deleteHistory(entry.id) } label: { Image(systemName: "trash") }.buttonStyle(.borderless).help("Remove saved expression")
                            }.padding(16).background(.white, in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
            }
        }.padding(30).frame(width: 640, height: 470).background(Palette.paper)
    }
}

#Preview { ContentView() }
