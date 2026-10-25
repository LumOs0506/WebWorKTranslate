import SwiftUI

struct EquationRowView: View {
    let row: MathRow
    let cursor: MathCursor?
    var size: CGFloat = 30
    var label = "Expression"
    var select: (UUID, Int) -> Void

    var body: some View {
        HStack(spacing: 0) {
            if row.nodes.isEmpty {
                Button { select(row.id, 0) } label: {
                    Text("□").font(.system(size: size, design: .serif))
                        .foregroundStyle(cursor?.row == row.id ? Palette.accent : Palette.muted)
                        .frame(minWidth: size, minHeight: size * 1.3)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(label), empty. Click to enter math")
            } else {
                insertionPoint(0)
                ForEach(Array(row.nodes.enumerated()), id: \.element.id) { index, node in
                    EquationNodeView(node: node, cursor: cursor, size: size, select: select)
                        .contentShape(Rectangle())
                        .onTapGesture { select(row.id, index + 1) }
                    insertionPoint(index + 1)
                }
            }
        }
        .padding(.horizontal, 3).padding(.vertical, 3)
        .background(cursor?.row == row.id ? Palette.accent.opacity(0.055) : Color.clear, in: RoundedRectangle(cornerRadius: 5))
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(cursor?.row == row.id ? Palette.accent.opacity(0.3) : .clear, lineWidth: 1))
        .fixedSize()
    }
    private func insertionPoint(_ offset: Int) -> some View {
        let active = cursor?.row == row.id && cursor?.offset == offset
        return Rectangle().fill(active ? Palette.accent : Color.clear)
            .frame(width: 2, height: size * 1.1)
            .padding(.horizontal, 1)
            .contentShape(Rectangle())
            .onTapGesture { select(row.id, offset) }
            .accessibilityHidden(true)
    }
}

struct EquationNodeView: View {
    let node: MathNode
    let cursor: MathCursor?
    let size: CGFloat
    var select: (UUID, Int) -> Void

    private func child(_ index: Int, scale: CGFloat = 1, label: String = "Expression") -> AnyView {
        AnyView(EquationRowView(row: node.children[index], cursor: cursor, size: max(16, size * scale), label: label, select: select))
    }
    private func symbol(_ text: String, scale: CGFloat = 1) -> some View {
        Text(text).font(.system(size: size * scale, weight: .regular, design: .serif)).fixedSize()
    }
    private var powerBaseNeedsGrouping: Bool {
        node.children[0].nodes.count > 1 || node.children[0].nodes.first?.kind == .power
    }
    var body: some View {
        Group {
            switch node.kind {
            case .token:
                symbol(["*": "·", "-": "−", "pi": "π", "inf": "∞" ][node.text] ?? node.text)
            case .fraction:
                VStack(spacing: 1) {
                    child(0, scale: 0.9, label: "Numerator")
                    Rectangle().frame(height: 1.5)
                    child(1, scale: 0.9, label: "Denominator")
                }.fixedSize().padding(.horizontal, 3)
            case .power:
                HStack(alignment: .top, spacing: 0) {
                    HStack(spacing: 0) {
                        if powerBaseNeedsGrouping { symbol("(") }
                        child(0, label: "Base")
                        if powerBaseNeedsGrouping { symbol(")") }
                    }.padding(.top, size * 0.28)
                    child(1, scale: 0.65, label: "Exponent")
                }
            case .root, .nthRoot:
                HStack(spacing: 0) {
                    if node.kind == .nthRoot { child(0, scale: 0.6, label: "Root index").offset(y: -size * 0.3) }
                    symbol("√", scale: 1.35)
                    child(node.kind == .root ? 0 : 1, label: "Radicand")
                        .overlay(alignment: .top) { Rectangle().frame(height: 1.3).padding(.top, 1) }
                }
            case .group:
                HStack(spacing: 0) { symbol("("); child(0); symbol(")") }
            case .absolute:
                HStack(spacing: 0) { symbol("|"); child(0, label: "Absolute value"); symbol("|") }
            case .function:
                HStack(spacing: 0) {
                    Text(node.text == "log10" ? "log₁₀" : node.text).font(.system(size: size * 0.86, design: .serif))
                    symbol("(")
                    ForEach(node.children.indices, id: \.self) { index in
                        if index > 0 { symbol(",") }
                        child(index, label: "\(node.text) argument \(index + 1)")
                    }
                    symbol(")")
                }
            case .logBase:
                HStack(alignment: .center, spacing: 0) {
                    symbol("log", scale: 0.86)
                    child(0, scale: 0.6, label: "Log base").offset(y: size * 0.3)
                    symbol("("); child(1, label: "Log argument"); symbol(")")
                }
            case .interval:
                HStack(spacing: 0) {
                    symbol(String(node.text.prefix(1)))
                    child(0, label: "Lower endpoint"); symbol(",")
                    child(1, label: "Upper endpoint")
                    symbol(String(node.text.suffix(1)))
                }
            }
        }
        .foregroundStyle(Palette.ink)
    }
}
