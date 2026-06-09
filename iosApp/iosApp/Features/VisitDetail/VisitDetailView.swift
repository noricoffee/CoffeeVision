import SwiftUI
import SharedLogic
import UIKit

// MARK: - Identifiable 拡張

extension CoffeeItem: @retroactive Identifiable {}
extension FoodItem: @retroactive Identifiable {}
extension Photo_: @retroactive Identifiable {}

// MARK: - VisitDetailView

/// 訪問記録詳細画面（read-only）。
///
/// - `VisitListView` の `NavigationStack` 内に push される前提のため、自身では `NavigationStack` に包まない
/// - Bridge は遷移ごとに新規生成するため、View 内 `@State` で保持する（AppState にホルダを持たせない）
struct VisitDetailView: View {

    let visitId: String
    let appState: AppState
    @State private var viewModel: VisitDetailViewModelBridge
    @State private var isPresentingEditor = false

    init(visitId: String, appState: AppState) {
        self.visitId = visitId
        self.appState = appState
        _viewModel = State(
            initialValue: VisitDetailViewModelBridge(
                kotlin: appState.container.makeVisitDetailViewModel()
            )
        )
    }

    var body: some View {
        content
            .navigationTitle(viewModel.visit?.cafe.name ?? String(localized: "詳細"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isPresentingEditor = true
                    } label: {
                        Label(String(localized: "編集"), systemImage: "pencil")
                    }
                    .accessibilityLabel(String(localized: "訪問記録を編集"))
                }
            }
            .task { viewModel.onAppear(visitId: visitId) }
            .onDisappear { viewModel.onDisappear() }
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
            .sheet(isPresented: $isPresentingEditor) {
                VisitEditorView(
                    mode: VisitEditorViewModelModeEdit(visitId: visitId),
                    appState: appState
                )
            }
    }

    // MARK: - コンテンツ切り替え

    @ViewBuilder
    private var content: some View {
        if viewModel.visit == nil && viewModel.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let visit = viewModel.visit {
            detailForm(visit: visit)
        } else {
            ContentUnavailableView(
                String(localized: "訪問記録が見つかりません"),
                systemImage: "questionmark.circle"
            )
        }
    }

    // MARK: - 詳細フォーム

    private func detailForm(visit: Visit_) -> some View {
        Form {
            // ヘッダ：カフェ情報 + 訪問日 + 評価
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(visit.cafe.name)
                        .font(.title3)
                    if let address = visit.cafe.address {
                        Text(address)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)

                LabeledContent(String(localized: "訪問日")) {
                    Text(formattedDate(visit.visitedOn))
                }

                LabeledContent(String(localized: "評価")) {
                    StarRatingView(rating: Int(visit.rating))
                }
            }

            // 雰囲気
            if !visit.ambiance.isEmpty {
                Section(String(localized: "雰囲気")) {
                    Text(visit.ambiance)
                        .font(.body)
                }
            }

            // メモ
            if !visit.notes.isEmpty {
                Section(String(localized: "メモ")) {
                    Text(visit.notes)
                        .font(.body)
                }
            }

            // コーヒー
            if !visit.coffees.isEmpty {
                Section(String(localized: "コーヒー")) {
                    ForEach(visit.coffees) { coffee in
                        CoffeeItemRow(coffee: coffee)
                    }
                }
            }

            // フード
            if !visit.foods.isEmpty {
                Section(String(localized: "フード")) {
                    ForEach(visit.foods) { food in
                        FoodItemRow(food: food)
                    }
                }
            }

            // 写真
            if !visit.photos.isEmpty {
                Section(String(localized: "写真")) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 8) {
                            ForEach(Array(visit.photos.enumerated()), id: \.element.id) { index, photo in
                                PhotoDetailCell(
                                    photo: photo,
                                    index: index + 1,
                                    total: visit.photos.count
                                )
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .frame(height: 136)
                }
            }
        }
    }

    // MARK: - 日付フォーマット

    private func formattedDate(_ date: Kotlinx_datetimeLocalDate) -> String {
        String(
            format: "%04d/%02d/%02d",
            Int(date.year),
            Int(date.monthNumber),
            Int(date.dayOfMonth)
        )
    }
}

// MARK: - CoffeeItemRow

/// コーヒーアイテム行コンポーネント。
private struct CoffeeItemRow: View {
    let coffee: CoffeeItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(coffee.name)
                .font(.headline)

            // メタ情報（nil は省略）
            let metaParts = coffeeMetaParts
            if !metaParts.isEmpty {
                Text(metaParts.joined(separator: " · "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            StarRatingView(rating: Int(coffee.rating), size: .subheadline)

            if let notes = coffee.notes, !notes.isEmpty {
                Text(notes)
                    .font(.body)
                    .foregroundStyle(.primary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private var coffeeMetaParts: [String] {
        var parts: [String] = []
        parts.append(coffee.brewMethod.name)
        if let origin = coffee.origin { parts.append(origin) }
        if let variety = coffee.variety { parts.append(variety) }
        if let processing = coffee.processing { parts.append(processing.name) }
        if let roastLevel = coffee.roastLevel { parts.append(roastLevel.name) }
        if let cup = coffee.cup { parts.append(cup) }
        return parts
    }
}

// MARK: - FoodItemRow

/// フードアイテム行コンポーネント。
private struct FoodItemRow: View {
    let food: FoodItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(food.name)
                .font(.headline)

            StarRatingView(rating: Int(food.rating), size: .subheadline)

            if let notes = food.notes, !notes.isEmpty {
                Text(notes)
                    .font(.body)
                    .foregroundStyle(.primary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - PhotoDetailCell

/// 詳細画面の写真表示セル。
private struct PhotoDetailCell: View {

    let photo: Photo_
    let index: Int
    let total: Int

    var body: some View {
        Group {
            if let fileName = photo.fileName,
               let uiImage = PhotoFileStore.loadImage(fileName: fileName) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 120, height: 120)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.secondarySystemBackground))
                    .frame(width: 120, height: 120)
                    .overlay {
                        Image(systemName: "photo.badge.exclamationmark")
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .accessibilityLabel(
            String(format: String(localized: "写真 %d/%d 枚目"), index, total)
        )
    }
}

// MARK: - Preview

#Preview {
    Text("VisitDetailView preview placeholder")
}
