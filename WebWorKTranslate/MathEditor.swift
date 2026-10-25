import Foundation
import Observation

struct MathCursor: Equatable {
    var row: UUID
    var offset: Int
}
struct EditorSnapshot {
    var document: MathRow
    var cursor: MathCursor
}
struct SavedExpression: Identifiable, Codable {
    var id = UUID()
    var document: MathRow
    var output: String
    var date = Date()
}

@Observable
final class MathEditor {
    var document: MathRow
    var cursor: MathCursor
    var history: [SavedExpression] = []
    var notice: String?
    private var undoStack: [EditorSnapshot] = []
    private var redoStack: [EditorSnapshot] = []
    private let defaults: UserDefaults?
    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }
    var result: Result<(output: String, warnings: [String]), Error> { Result { try document.translate() } }
    var output: String? { try? result.get().output }

    init(defaults: UserDefaults? = .standard) {
        self.defaults = defaults
        let restored = defaults?.data(forKey: "math-draft-v1").flatMap { try? JSONDecoder().decode(MathRow.self, from: $0) }
        let initial = restored ?? MathRow()
        document = initial
        cursor = MathCursor(row: initial.id, offset: initial.nodes.count)
        if let data = defaults?.data(forKey: "math-history-v1"), let saved = try? JSONDecoder().decode([SavedExpression].self, from: data) {
            history = saved
        }
    }
    func select(_ row: UUID, _ offset: Int) {
        guard let found = document.row(row) else { return }
        cursor = MathCursor(row: row, offset: min(max(offset, 0), found.nodes.count))
    }
    private func checkpoint() {
        undoStack.append(EditorSnapshot(document: document, cursor: cursor))
        if undoStack.count > 100 { undoStack.removeFirst() }
        redoStack.removeAll()
        notice = nil
    }
    private func persist() {
        if let data = try? JSONEncoder().encode(document) { defaults?.set(data, forKey: "math-draft-v1") }
    }
    func undo() {
        guard let state = undoStack.popLast() else { return }
        redoStack.append(EditorSnapshot(document: document, cursor: cursor))
        document = state.document; cursor = state.cursor; notice = nil; persist()
    }
    func redo() {
        guard let state = redoStack.popLast() else { return }
        undoStack.append(EditorSnapshot(document: document, cursor: cursor))
        document = state.document; cursor = state.cursor; notice = nil; persist()
    }
    func clear() {
        checkpoint(); document = MathRow(); cursor = MathCursor(row: document.id, offset: 0); persist()
    }
    func insertText(_ text: String) {
        guard !text.isEmpty else { return }
        checkpoint()
        let nodes = ["pi", "inf"].contains(text) ? [MathNode.token(text)] : text.map { MathNode.token(String($0)) }
        let offset = cursor.offset
        document.edit(cursor.row) { $0.nodes.insert(contentsOf: nodes, at: offset) }
        cursor.offset += nodes.count
        if let row = document.row(cursor.row) {
            var start = cursor.offset
            while start > 0 && row.nodes[start - 1].kind == .token && row.nodes[start - 1].text.allSatisfy(\.isLetter) { start -= 1 }
            let word = row.nodes[start..<cursor.offset].map(\.text).joined()
            if ["pi", "inf"].contains(word) {
                let end = cursor.offset
                document.edit(cursor.row) { $0.nodes.replaceSubrange(start..<end, with: [.token(word)]) }
                cursor.offset = start + 1
            }
        }
        persist()
    }
    func insertTemplate(_ kind: MathNode.Kind, text: String = "") {
        // Limit recursive UI depth as well as parser depth.
        var depth = 0, rowID = cursor.row
        while let parent = document.parent(of: rowID) { depth += 1; rowID = parent.row }
        guard depth < 15 else { notice = "Use fewer than 16 nested templates."; return }
        checkpoint()
        var kind = kind
        var text = text
        // Typing sin( should create the same function node as pressing sin.
        // Otherwise a subsequent power could accidentally become sin(x^2).
        if kind == .group, let row = document.row(cursor.row) {
            var start = cursor.offset
            while start > 0 && row.nodes[start - 1].kind == .token && row.nodes[start - 1].text.allSatisfy({ $0.isLetter || $0.isNumber }) {
                start -= 1
            }
            let word = row.nodes[start..<cursor.offset].map(\.text).joined()
            if let function = MathExpression.functions.sorted(by: { $0.count > $1.count }).first(where: { word.hasSuffix($0) }) {
                start = cursor.offset - function.count
                let end = cursor.offset
                document.edit(cursor.row) { $0.nodes.removeSubrange(start..<end) }
                cursor.offset = start
                kind = .function
                text = function
            }
        }
        let count = [.fraction, .power, .nthRoot, .logBase, .interval].contains(kind) || (kind == .function && ["P", "C"].contains(text)) ? 2 : 1
        var node = MathNode(kind: kind, text: text, children: (0..<count).map { _ in MathRow() })
        let selectedRow = cursor.row
        var offset = cursor.offset
        if (kind == .fraction || kind == .power), offset > 0, let row = document.row(selectedRow) {
            var start = offset - 1
            // A postfix factorial belongs to the preceding operand.
            while start > 0 && row.nodes[start].kind == .token && row.nodes[start].text == "!" { start -= 1 }
            let previous = row.nodes[start]
            if previous.kind != .token || !["+", "-", "*", "/", "^", "(", ","].contains(previous.text) {
                if previous.kind == .token && previous.text.allSatisfy({ $0.isNumber || $0 == "." }) {
                    while start > 0 && row.nodes[start - 1].kind == .token && row.nodes[start - 1].text.allSatisfy({ $0.isNumber || $0 == "." }) { start -= 1 }
                    if start >= 2 && ["+", "-"].contains(row.nodes[start - 1].text) && row.nodes[start - 2].text == "E" {
                        start -= 2
                    } else if start > 0 && row.nodes[start - 1].text == "E" { start -= 1 }
                    while start > 0 && row.nodes[start - 1].kind == .token && row.nodes[start - 1].text.allSatisfy({ $0.isNumber || $0 == "." }) { start -= 1 }
                }
                node.children[0].nodes = Array(row.nodes[start..<offset])
                let end = offset
                document.edit(selectedRow) { $0.nodes.removeSubrange(start..<end) }
                offset = start
            }
        }
        document.edit(selectedRow) { $0.nodes.insert(node, at: offset) }
        let child = node.children[(kind == .fraction || kind == .power) && !node.children[0].nodes.isEmpty ? 1 : 0]
        cursor = MathCursor(row: child.id, offset: 0)
        persist()
    }
    func backspace() {
        if cursor.offset > 0 {
            checkpoint()
            let offset = cursor.offset - 1
            document.edit(cursor.row) { $0.nodes.remove(at: offset) }
            cursor.offset = offset; persist()
        } else if let parent = document.parent(of: cursor.row), let row = document.row(parent.row) {
            let node = row.nodes[parent.index]
            if node.children.allSatisfy({ $0.nodes.isEmpty }) {
                checkpoint()
                document.edit(parent.row) { $0.nodes.remove(at: parent.index) }
                cursor = MathCursor(row: parent.row, offset: parent.index); persist()
            } else { cursor = MathCursor(row: parent.row, offset: parent.index) }
        }
    }
    func move(_ direction: Int) {
        func positions(_ row: MathRow) -> [MathCursor] {
            var result = [MathCursor(row: row.id, offset: 0)]
            for (i, node) in row.nodes.enumerated() {
                result += node.children.flatMap(positions)
                result.append(MathCursor(row: row.id, offset: i + 1))
            }
            return result
        }
        let positions = positions(document)
        guard let index = positions.firstIndex(of: cursor) else { return }
        cursor = positions[min(max(index + direction, 0), positions.count - 1)]
    }
    func nextSlot(backwards: Bool = false) {
        let ids = document.rowIDs
        guard let index = ids.firstIndex(of: cursor.row) else { return }
        let next = ids[(index + (backwards ? ids.count - 1 : 1)) % ids.count]
        cursor = MathCursor(row: next, offset: document.row(next)?.nodes.count ?? 0)
    }
    func exitTemplate() {
        if let parent = document.parent(of: cursor.row) { cursor = MathCursor(row: parent.row, offset: parent.index + 1) }
    }
    @discardableResult func load(_ source: String) -> Bool {
        do {
            var parser = try ExpressionParser(source)
            let row = try parser.parse().mathRow
            _ = try row.translate()
            replace(row)
            return true
        } catch { notice = error.localizedDescription; return false }
    }
    func replace(_ row: MathRow) {
        checkpoint(); document = row; cursor = MathCursor(row: row.id, offset: row.nodes.count); persist()
    }
    func save() {
        guard let output else { return }
        if history.first?.output != output { history.insert(SavedExpression(document: document, output: output), at: 0) }
        history = Array(history.prefix(20))
        persistHistory()
        notice = "Saved to your recent expressions."
    }
    func deleteHistory(_ id: UUID) { history.removeAll { $0.id == id }; persistHistory() }
    private func persistHistory() {
        if let data = try? JSONEncoder().encode(history) { defaults?.set(data, forKey: "math-history-v1") }
    }
}
