import SwiftUI
import SharedLogic

/// コーヒーアイテム追加 / 編集モーダル View。
///
/// - `initial` が `nil` のとき: 新規追加モード（id を新規 UUID で採番する）
/// - `initial` が非 `nil` のとき: 編集モード（既存 CoffeeItem の値で初期化する）
/// - 保存ボタンタップで `onSave` クロージャを呼び、親 VM の `onCoffeeUpserted(item:)` に渡す
/// - カフェ名（name）が空の場合は保存ボタンを disabled にする簡易バリデーション（KMP VM 側のバリデーションを補助）
struct CoffeeItemEditorView: View {

    // MARK: - Properties

    let initial: CoffeeItem?
    let onSave: (CoffeeItem) -> Void

    @Environment(\.dismiss) private var dismiss

    // MARK: - 編集中の State

    @State private var id: String
    @State private var name: String
    @State private var brewMethod: BrewMethod
    @State private var origin: String
    @State private var variety: String
    @State private var cup: String
    @State private var processing: ProcessingMethod?
    @State private var roastLevel: RoastLevel?
    @State private var rating: Int
    @State private var notes: String

    // MARK: - Init

    init(initial: CoffeeItem?, onSave: @escaping (CoffeeItem) -> Void) {
        self.initial = initial
        self.onSave = onSave
        _id = State(initialValue: initial?.id ?? UUID().uuidString)
        _name = State(initialValue: initial?.name ?? "")
        _brewMethod = State(initialValue: initial?.brewMethod ?? BrewMethod.handDrip)
        _origin = State(initialValue: initial?.origin ?? "")
        _variety = State(initialValue: initial?.variety ?? "")
        _cup = State(initialValue: initial?.cup ?? "")
        _processing = State(initialValue: initial?.processing)
        _roastLevel = State(initialValue: initial?.roastLevel)
        _rating = State(initialValue: initial.map { Int($0.rating) } ?? 0)
        _notes = State(initialValue: initial?.notes ?? "")
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                // メニュー名
                Section(String(localized: "メニュー名")) {
                    TextField(String(localized: "例: エスプレッソ（必須）"), text: $name)
                        .accessibilityLabel(String(localized: "メニュー名"))
                }

                // 抽出方法
                Section(String(localized: "抽出方法")) {
                    Picker(String(localized: "抽出方法"), selection: $brewMethod) {
                        ForEach(BrewMethod.allCases, id: \.name) { method in
                            Text(method.name).tag(method)
                        }
                    }
                    .accessibilityLabel(String(localized: "抽出方法"))
                }

                // 産地 / 品種 / カップ
                Section(String(localized: "産地 / 品種")) {
                    TextField(String(localized: "産地（任意）"), text: $origin)
                        .accessibilityLabel(String(localized: "産地"))
                    TextField(String(localized: "品種（任意）"), text: $variety)
                        .accessibilityLabel(String(localized: "品種"))
                    TextField(String(localized: "カップ（任意）"), text: $cup)
                        .accessibilityLabel(String(localized: "カップ"))
                }

                // 精製方法
                Section(String(localized: "精製方法")) {
                    Picker(String(localized: "精製方法"), selection: $processing) {
                        Text(String(localized: "未指定")).tag(Optional<ProcessingMethod>.none)
                        ForEach(ProcessingMethod.allCases, id: \.name) { method in
                            Text(method.name).tag(Optional(method))
                        }
                    }
                    .accessibilityLabel(String(localized: "精製方法"))
                }

                // 焙煎度
                Section(String(localized: "焙煎度")) {
                    Picker(String(localized: "焙煎度"), selection: $roastLevel) {
                        Text(String(localized: "未指定")).tag(Optional<RoastLevel>.none)
                        ForEach(RoastLevel.allCases, id: \.name) { level in
                            Text(level.name).tag(Optional(level))
                        }
                    }
                    .accessibilityLabel(String(localized: "焙煎度"))
                }

                // 評価
                Section(String(localized: "評価")) {
                    LabeledContent(String(localized: "評価")) {
                        StarRatingView(rating: rating, onChange: { rating = $0 })
                    }
                }

                // メモ
                Section(String(localized: "メモ")) {
                    TextField(String(localized: "メモ（任意）"), text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                        .accessibilityLabel(String(localized: "メモ"))
                }
            }
            .navigationTitle(initial == nil ? String(localized: "コーヒーの追加") : String(localized: "コーヒーの編集"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(String(localized: "キャンセル")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(String(localized: "保存")) {
                        saveAndDismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    // MARK: - Private

    private func saveAndDismiss() {
        let item = CoffeeItem(
            id: id,
            name: name,
            brewMethod: brewMethod,
            origin: origin.isEmpty ? nil : origin,
            variety: variety.isEmpty ? nil : variety,
            processing: processing,
            roastLevel: roastLevel,
            cup: cup.isEmpty ? nil : cup,
            rating: Int32(rating),
            notes: notes.isEmpty ? nil : notes
        )
        onSave(item)
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    CoffeeItemEditorView(initial: nil, onSave: { _ in })
}
