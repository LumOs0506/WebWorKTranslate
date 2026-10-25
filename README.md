# WebWorK Translate

A native macOS SwiftUI app for entering textbook-style mathematics and copying an equivalent WebWorK expression. It works offline without third-party dependencies.

## Run

Open `WebWorKTranslate.xcodeproj` in Xcode, select the **WebWorKTranslate** scheme and **My Mac**, then press **Run**. The existing project targets macOS 27 and Xcode 27.

## Use

- Click a template or type numbers, variables, and operators into the expression area.
- Fractions, powers, roots, absolute values, functions, and logarithms have individually editable slots. Click inside a slot to edit it.
- `Tab` / `Shift-Tab` move between slots. Arrow keys move the cursor. `Escape`, `Return`, or `)` exit a template.
- Fraction and power insertions wrap the preceding number or template. Use a parentheses template to group a larger base.
- `⌘Z` undoes and `⇧⌘Z` redoes edits, including Clear and example loading.
- `⌘V` replaces the expression with parsed plain math from the clipboard, such as `sqrt(x^2+1)`. Invalid paste leaves the draft intact. LaTeX paste is not supported.
- **Copy** or `⇧⌘C` copies the WebWorK result. **Save expression** adds it to the recent list.

The draft and up to 20 saved expressions are stored locally in UserDefaults. No account, network service, or telemetry is used.

## Conversion

The structured editor produces an expression tree, and a strict precedence parser emits explicit multiplication and parentheses. It preserves fractions, unary minus, right-associative powers, and function arguments without evaluating or simplifying the answer. Incomplete expressions cannot be copied.

Supported: arithmetic, single-letter variables, pi and e, square/nth roots, powers, absolute value, factorials, natural/base-10/arbitrary-base logarithms, trig/inverse trig/hyperbolic functions, scientific notation, and standalone interval templates. Conditional WebWorK functions `P`, `C`, and `step` display a notice. Ambiguous `log` displays a notice; the pad uses explicit `ln` and `log10`.

Infinity is supported only as an open interval endpoint. Equations, matrices, integral/derivative notation, interval unions, and LaTeX imports are not implemented. This is a notation translator, not a CAS or a mathematical-domain validator: it does not detect every undefined expression or prove that interval endpoints are ordered.

Rules follow the [official WebWorK Available Functions reference](https://wiki.openwebwork.org/wiki/Available_Functions). Trigonometry uses radians. Individual problems can restrict functions and variables; use WebWorK's Preview before submitting.

## Verify

```sh
xcodebuild -scheme WebWorKTranslate -destination 'platform=macOS' -only-testing:WebWorKTranslateTests test
```

Tests cover precedence, implicit multiplication, invalid input, text-to-textbook round trips, nested editing, interval endpoints, undo/redo, and persistence. UI verification also covers pad entry, keyboard navigation, Copy, and nested root/fraction layout.

## Source map

- `ContentView.swift`: workspace, keypad, clipboard, guide, and saved-expression views.
- `EquationView.swift`: recursive native textbook rendering and cursor placement.
- `MathEditor.swift`: document mutations, cursor navigation, undo/redo, and local persistence.
- `MathExpression.swift`: structured math model, strict parser, and WebWorK serialization.
