import SwiftUI
import SharedLogic

// MARK: - シート用 Identifiable ラッパ

/// コーヒーアイテム編集シートのターゲット。
///
/// `.sheet(item:)` と `Identifiable` の組み合わせで、
/// nil = 非表示 / 非 nil = 表示（新規 or 既存）を切り替える。
private enum CoffeeEditingTarget: Identifiable {
    case new
    case existing(CoffeeItem)

    var id: String {
        switch self {
        case .new: return "new"
        case .existing(let item): return item.id
        }
    }

    /// シート初期値。新規は nil、編集は既存 CoffeeItem。
    var initial: CoffeeItem? {
        switch self {
        case .new: return nil
        case .existing(let item): return item
        }
    }
}

/// フードアイテム編集シートのターゲット。
private enum FoodEditingTarget: Identifiable {
    case new
    case existing(FoodItem)

    var id: String {
        switch self {
        case .new: return "new"
        case .existing(let item): return item.id
        }
    }

    var initial: FoodItem? {
        switch self {
        case .new: return nil
        case .existing(let item): return item
        }
    }
}

// MARK: - VisitEditorView

/// 訪問記録作成 / 編集画面。
///
/// - `VisitListView` / `VisitDetailView` の `.sheet` で開かれる前提のため、自身を `NavigationStack` でラップする
/// - Bridge は遷移ごとに新規生成するため、View 内 `@State` で保持する（AppState にホルダを持たせない）
struct VisitEditorView: View {

    // MARK: - Properties

    let mode: any VisitEditorViewModelMode
    let appState: AppState

    @State private var viewModel: VisitEditorViewModelBridge
    @Environment(\.dismiss) private var dismiss

    @State private var coffeeBeingEdited: CoffeeEditingTarget?
    @State private var foodBeingEdited: FoodEditingTarget?

    // MARK: - Init

    init(mode: any VisitEditorViewModelMode, appState: AppState) {
        self.mode = mode
        self.appState = appState
        _viewModel = State(
            initialValue: VisitEditorViewModelBridge(
                kotlin: appState.container.makeVisitEditorViewModel()
            )
        )
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                cafeSection
                visitSection
                coffeeSection
                foodSection
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .task {
                viewModel.onAppear(mode: mode, userId: appState.uid ?? "")
            }
            .onDisappear {
                viewModel.onDisappear()
            }
            .alert(
                String(localized: "エラー"),
                isPresented: Binding(
                    get: { viewModel.error != nil },
                    set: { if !$0 { viewModel.onErrorDismissed() } }
                )
            ) {
                Button(String(localized: "OK")) {
                    viewModel.onErrorDismissed()
                }
            } message: {
                Text(viewModel.error ?? "")
            }
            .onChange(of: viewModel.savedVisitId) { _, newValue in
                if newValue != nil {
                    dismiss()
                }
            }
            .sheet(item: $coffeeBeingEdited) { target in
                CoffeeItemEditorView(
                    initial: target.initial,
                    onSave: { viewModel.onCoffeeUpserted(item: $0) }
                )
            }
            .sheet(item: $foodBeingEdited) { target in
                FoodItemEditorView(
                    initial: target.initial,
                    onSave: { viewModel.onFoodUpserted(item: $0) }
                )
            }
            .overlay {
                if viewModel.isSaving {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.ultraThinMaterial)
                }
            }
        }
    }

    // MARK: - カフェ Section

    private var cafeSection: some View {
        Section(String(localized: "カフェ")) {
            TextField(
                String(localized: "カフェ名（必須）"),
                text: Binding(
                    get: { viewModel.draft.cafeName },
                    set: { viewModel.onCafeNameChanged($0) }
                )
            )
            .accessibilityLabel(String(localized: "カフェ名"))

            TextField(
                String(localized: "住所（任意）"),
                text: Binding(
                    get: { viewModel.draft.cafeAddress },
                    set: { viewModel.onCafeAddressChanged($0) }
                )
            )
            .accessibilityLabel(String(localized: "住所"))

            TextField(
                String(localized: "Web サイト URL（任意）"),
                text: Binding(
                    get: { viewModel.draft.cafeWebsiteUrl },
                    set: { viewModel.onCafeWebsiteUrlChanged($0) }
                )
            )
            .keyboardType(.URL)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .accessibilityLabel(String(localized: "Web サイト URL"))

            TextField(
                String(localized: "Google Maps URL（任意）"),
                text: Binding(
                    get: { viewModel.draft.cafeMapsUrl },
                    set: { viewModel.onCafeMapsUrlChanged($0) }
                )
            )
            .keyboardType(.URL)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .accessibilityLabel(String(localized: "Google Maps URL"))
        }
    }

    // MARK: - 訪問 Section

    private var visitSection: some View {
        Section(String(localized: "訪問")) {
            DatePicker(
                String(localized: "訪問日"),
                selection: Binding(
                    get: { localDateToDate(viewModel.draft.visitedOn) },
                    set: { viewModel.onVisitedOnChanged(dateToLocalDate($0)) }
                ),
                displayedComponents: .date
            )
            .accessibilityLabel(String(localized: "訪問日"))

            LabeledContent(String(localized: "評価")) {
                StarRatingView(
                    rating: Int(viewModel.draft.rating),
                    onChange: { viewModel.onRatingChanged(rating: $0) }
                )
            }
            .accessibilityLabel(String(localized: "評価"))

            TextField(
                String(localized: "雰囲気（任意）"),
                text: Binding(
                    get: { viewModel.draft.ambiance },
                    set: { viewModel.onAmbianceChanged($0) }
                ),
                axis: .vertical
            )
            .lineLimit(3...6)
            .accessibilityLabel(String(localized: "雰囲気"))

            TextField(
                String(localized: "メモ（任意）"),
                text: Binding(
                    get: { viewModel.draft.notes },
                    set: { viewModel.onNotesChanged($0) }
                ),
                axis: .vertical
            )
            .lineLimit(3...6)
            .accessibilityLabel(String(localized: "メモ"))
        }
    }

    // MARK: - コーヒー Section

    private var coffeeSection: some View {
        Section(String(localized: "コーヒー")) {
            ForEach(viewModel.draft.coffees) { coffee in
                Button {
                    coffeeBeingEdited = .existing(coffee)
                } label: {
                    CoffeeItemSummaryRow(coffee: coffee)
                }
                .foregroundStyle(.primary)
                .accessibilityLabel(coffee.name)
            }
            .onDelete { indexSet in
                indexSet.forEach { index in
                    let coffees = viewModel.draft.coffees
                    if index < coffees.count {
                        viewModel.onCoffeeRemoved(id: coffees[index].id)
                    }
                }
            }

            Button {
                coffeeBeingEdited = .new
            } label: {
                Label(String(localized: "コーヒーを追加"), systemImage: "plus")
            }
            .accessibilityLabel(String(localized: "コーヒーを追加"))
        }
    }

    // MARK: - フード Section

    private var foodSection: some View {
        Section(String(localized: "フード")) {
            ForEach(viewModel.draft.foods) { food in
                Button {
                    foodBeingEdited = .existing(food)
                } label: {
                    FoodItemSummaryRow(food: food)
                }
                .foregroundStyle(.primary)
                .accessibilityLabel(food.name)
            }
            .onDelete { indexSet in
                indexSet.forEach { index in
                    let foods = viewModel.draft.foods
                    if index < foods.count {
                        viewModel.onFoodRemoved(id: foods[index].id)
                    }
                }
            }

            Button {
                foodBeingEdited = .new
            } label: {
                Label(String(localized: "フードを追加"), systemImage: "plus")
            }
            .accessibilityLabel(String(localized: "フードを追加"))
        }
    }

    // MARK: - ツールバー

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button(String(localized: "キャンセル")) {
                dismiss()
            }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(String(localized: "保存")) {
                viewModel.onSaveTapped()
            }
            .disabled(viewModel.isSaving)
        }
    }

    // MARK: - ナビゲーションタイトル

    private var navigationTitle: String {
        if mode is VisitEditorViewModelModeCreate {
            return String(localized: "新規訪問")
        } else {
            return String(localized: "訪問の編集")
        }
    }

    // MARK: - LocalDate ↔ Date 変換

    /// `Kotlinx_datetimeLocalDate` を Foundation の `Date` に変換する。
    private func localDateToDate(_ localDate: Kotlinx_datetimeLocalDate) -> Date {
        var components = DateComponents()
        components.year = Int(localDate.year)
        components.month = Int(localDate.monthNumber)
        components.day = Int(localDate.dayOfMonth)
        return Calendar.current.date(from: components) ?? Date()
    }

    /// Foundation の `Date` を `Kotlinx_datetimeLocalDate` に変換する。
    private func dateToLocalDate(_ date: Date) -> Kotlinx_datetimeLocalDate {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return Kotlinx_datetimeLocalDate(
            year: Int32(components.year ?? 2026),
            monthNumber: Int32(components.month ?? 1),
            dayOfMonth: Int32(components.day ?? 1)
        )
    }
}

// MARK: - CoffeeItemSummaryRow

/// コーヒーアイテムの一覧行コンポーネント（Editor 内リスト用）。
private struct CoffeeItemSummaryRow: View {
    let coffee: CoffeeItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(coffee.name)
                .font(.body)
            Text(coffee.brewMethod.name)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - FoodItemSummaryRow

/// フードアイテムの一覧行コンポーネント（Editor 内リスト用）。
private struct FoodItemSummaryRow: View {
    let food: FoodItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(food.name)
                .font(.body)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Preview

#Preview {
    Text("VisitEditorView preview placeholder")
}
