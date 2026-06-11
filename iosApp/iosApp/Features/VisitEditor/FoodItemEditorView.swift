import SwiftUI
import SharedLogic

/// フードアイテム追加 / 編集モーダル View。
///
/// - `initial` が `nil` のとき: 新規追加モード（id を新規 UUID で採番する）
/// - `initial` が非 `nil` のとき: 編集モード（既存 FoodItem の値で初期化する）
/// - 保存ボタンタップで `onSave` クロージャを呼び、親 VM の `onFoodUpserted(item:)` に渡す
/// - name が空の場合は保存ボタンを disabled にする簡易バリデーション
struct FoodItemEditorView: View {

    // MARK: - Properties

    let initial: FoodItem?
    let onSave: (FoodItem) -> Void

    @Environment(\.dismiss) private var dismiss

    // MARK: - 編集中の State

    @State private var id: String
    @State private var name: String
    @State private var rating: Int
    @State private var notes: String

    // MARK: - Init

    init(initial: FoodItem?, onSave: @escaping (FoodItem) -> Void) {
        self.initial = initial
        self.onSave = onSave
        _id = State(initialValue: initial?.id ?? UUID().uuidString)
        _name = State(initialValue: initial?.name ?? "")
        _rating = State(initialValue: initial.map { Int($0.rating) } ?? 0)
        _notes = State(initialValue: initial?.notes ?? "")
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                // メニュー名
                Section(String(localized: "メニュー名")) {
                    TextField(String(localized: "例: スコーン（必須）"), text: $name)
                        .accessibilityLabel(String(localized: "メニュー名"))
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
            .navigationTitle(initial == nil ? String(localized: "フードの追加") : String(localized: "フードの編集"))
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
        let item = FoodItem(
            id: id,
            name: name,
            rating: Int32(rating),
            notes: notes.isEmpty ? nil : notes
        )
        onSave(item)
        dismiss()
    }
}

// MARK: - Preview

#Preview("新規") {
    FoodItemEditorView(initial: nil, onSave: { _ in })
}

#Preview("編集（クッキー）") {
    FoodItemEditorView(
        initial: PreviewSamples.sampleFoodItems[2],
        onSave: { _ in }
    )
}
