import SwiftUI
import SharedLogic
import UIKit

// MARK: - Identifiable 拡張

extension Photo_: @retroactive Identifiable {}

// MARK: - CoffeeDetailView

/// コーヒー記録詳細画面（read-only）。
///
/// - `CoffeeListView` の `NavigationStack` 内に push される前提のため、自身では `NavigationStack` に包まない
/// - Bridge は遷移ごとに新規生成するため、View 内 `@State` で保持する（AppState にホルダを持たせない）
struct CoffeeDetailView: View {

    let coffeeId: String
    let appState: AppState
    @State private var viewModel: CoffeeDetailViewModelBridge
    @State private var isPresentingEditor = false
    @State private var isPresentingDuplicateEditor = false

    init(coffeeId: String, appState: AppState) {
        self.coffeeId = coffeeId
        self.appState = appState
        _viewModel = State(
            initialValue: CoffeeDetailViewModelBridge(
                kotlin: appState.container.makeCoffeeDetailViewModel()
            )
        )
    }

    var body: some View {
        content
            .navigationTitle(viewModel.coffee?.name ?? String(localized: "詳細"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            isPresentingEditor = true
                        } label: {
                            Label(String(localized: "編集"), systemImage: "pencil")
                        }
                        Button {
                            isPresentingDuplicateEditor = true
                        } label: {
                            Label(String(localized: "これをもとに記録"), systemImage: "doc.on.doc")
                        }
                    } label: {
                        Label(String(localized: "その他の操作"), systemImage: "ellipsis.circle")
                    }
                    .accessibilityLabel(String(localized: "その他の操作"))
                }
            }
            .task { viewModel.onAppear(coffeeId: coffeeId) }
            .onDisappear { viewModel.onDisappear() }
            .errorToast(message: viewModel.error) {
                viewModel.onErrorDismissed()
            }
            .sheet(isPresented: $isPresentingEditor) {
                if let coffee = viewModel.coffee {
                    CoffeeEditorView(
                        mode: CoffeeEditorViewModelModeEdit(coffeeId: coffeeId),
                        appState: appState,
                        initialCafe: coffee.cafe
                    )
                }
            }
            .sheet(isPresented: $isPresentingDuplicateEditor) {
                if viewModel.coffee != nil {
                    // 複製元の初期値（cafe 含む）は KMP 側の Mode.Duplicate が構築するため initialCafe は渡さない
                    CoffeeEditorView(
                        mode: CoffeeEditorViewModelModeDuplicate(sourceCoffeeId: coffeeId),
                        appState: appState
                    )
                }
            }
    }

    // MARK: - コンテンツ切り替え

    @ViewBuilder
    private var content: some View {
        if viewModel.coffee == nil && viewModel.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let coffee = viewModel.coffee {
            detailForm(coffee: coffee)
        } else {
            ContentUnavailableView(
                String(localized: "コーヒー記録が見つかりません"),
                systemImage: "questionmark.circle"
            )
        }
    }

    // MARK: - 詳細フォーム

    private func detailForm(coffee: CoffeeRecord) -> some View {
        Form {
            // ヘッダ：カフェ情報（任意） + 記録日 + 評価
            Section {
                if let cafe = coffee.cafe {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(cafe.name)
                            .font(.title3)
                        if let address = cafe.address {
                            Text(address)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                } else {
                    Label(String(localized: "セルフ抽出"), systemImage: "house")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                }

                LabeledContent(String(localized: "記録日")) {
                    Text(formattedDate(coffee.visitedOn))
                }

                LabeledContent(String(localized: "評価")) {
                    StarRatingView(rating: coffee.rating)
                }
            }

            // コーヒー情報
            Section(String(localized: "コーヒー")) {
                LabeledContent(String(localized: "名前")) {
                    Text(coffee.name)
                        .multilineTextAlignment(.trailing)
                }
                .accessibilityLabel(String(localized: "コーヒー名 \(coffee.name)"))

                LabeledContent(String(localized: "抽出方法")) {
                    Text(localizedBrewMethod(coffee.brewMethod))
                }

                if let origin = coffee.origin, !origin.isEmpty {
                    LabeledContent(String(localized: "産地")) {
                        Text(origin)
                    }
                }

                if let variety = coffee.variety, !variety.isEmpty {
                    LabeledContent(String(localized: "品種")) {
                        Text(variety)
                    }
                }

                if let processing = coffee.processing {
                    LabeledContent(String(localized: "精製方法")) {
                        Text(processing.name)
                    }
                }

                if let roastLevel = coffee.roastLevel {
                    LabeledContent(String(localized: "焙煎度")) {
                        Text(roastLevel.name)
                    }
                }

                if let cup = coffee.cup, !cup.isEmpty {
                    LabeledContent(String(localized: "カップ")) {
                        Text(cup)
                    }
                }
            }

            // テイスティング（all-or-nothing: tasting != nil なら 5 要素すべて表示）
            if let tasting = coffee.tasting {
                let tastingItems: [(label: String, value: Int)] = [
                    (String(localized: "甘味"),  Int(tasting.sweetness)),
                    (String(localized: "ボディ"), Int(tasting.body)),
                    (String(localized: "酸味"),  Int(tasting.acidity)),
                    (String(localized: "風味"),  Int(tasting.flavor)),
                    (String(localized: "後味"),  Int(tasting.aftertaste)),
                ]
                Section(String(localized: "テイスティング")) {
                    ForEach(tastingItems, id: \.label) { item in
                        LabeledContent(item.label) {
                            TastingScoreBar(value: item.value)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(
                            String(localized: "\(item.label) \(item.value)/10")
                        )
                    }
                }
            }

            // メモ
            if !coffee.notes.isEmpty {
                Section(String(localized: "メモ")) {
                    Text(coffee.notes)
                        .font(.body)
                }
            }

            // 写真
            let photos = coffee.photos
            if !photos.isEmpty {
                Section(String(localized: "写真")) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 8) {
                            ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                                PhotoDetailCell(
                                    photo: photo,
                                    index: index + 1,
                                    total: photos.count
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

    // MARK: - BrewMethod ローカライズ

    private func localizedBrewMethod(_ method: BrewMethod) -> String {
        switch method {
        case .handDrip: return String(localized: "ハンドドリップ")
        case .espresso: return String(localized: "エスプレッソ")
        case .nelDrip: return String(localized: "ネルドリップ")
        case .frenchPress: return String(localized: "フレンチプレス")
        case .aeroPress: return String(localized: "エアロプレス")
        case .syphon: return String(localized: "サイフォン")
        case .coldBrew: return String(localized: "コールドブリュー")
        case .other: return String(localized: "その他")
        @unknown default: return method.name
        }
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

// MARK: - TastingScoreBar

/// テイスティング要素のスコア（1〜10）をバーと数値で表示するコンポーネント。
private struct TastingScoreBar: View {

    let value: Int  // 1..10

    var body: some View {
        HStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.tertiarySystemFill))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.accentColor)
                        .frame(width: geo.size.width * CGFloat(value) / 10.0, height: 8)
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(height: 20)

            Text("\(value)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(minWidth: 20, alignment: .trailing)
        }
        .frame(maxWidth: 160)
    }
}

// MARK: - Preview (詳細画面 Form Demo)

#Preview("詳細 Form Demo（カフェあり）") {
    NavigationStack {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Blue Bottle 三軒茶屋")
                        .font(.title3)
                    Text("東京都世田谷区太子堂4-1-22")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)

                LabeledContent(String(localized: "記録日")) {
                    Text("2026/06/02")
                }
                LabeledContent(String(localized: "評価")) {
                    StarRatingView(rating: 4.0)
                }
            }

            Section(String(localized: "コーヒー")) {
                LabeledContent(String(localized: "名前")) {
                    Text("本日のコーヒー（ケニア カグモイニ）")
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent(String(localized: "抽出方法")) { Text("ハンドドリップ") }
                LabeledContent(String(localized: "産地")) { Text("ケニア") }
                LabeledContent(String(localized: "品種")) { Text("SL28") }
                LabeledContent(String(localized: "精製方法")) { Text("Washed") }
                LabeledContent(String(localized: "焙煎度")) { Text("Medium") }
                LabeledContent(String(localized: "カップ")) { Text("ノリタケ") }
            }

            Section(String(localized: "メモ")) {
                Text("ベリー系の華やかな酸味。落ち着いた木質の内装")
            }
        }
        .navigationTitle("本日のコーヒー（ケニア カグモイニ）")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {} label: {
                    Label(String(localized: "編集"), systemImage: "pencil")
                }
            }
        }
    }
}

#Preview("詳細 Form Demo（セルフ抽出）") {
    NavigationStack {
        Form {
            Section {
                Label(String(localized: "セルフ抽出"), systemImage: "house")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)

                LabeledContent(String(localized: "記録日")) {
                    Text("2026/06/19")
                }
                LabeledContent(String(localized: "評価")) {
                    StarRatingView(rating: 3.0)
                }
            }

            Section(String(localized: "コーヒー")) {
                LabeledContent(String(localized: "名前")) {
                    Text("エチオピア イルガチェフェ")
                }
                LabeledContent(String(localized: "抽出方法")) { Text("ハンドドリップ") }
            }
        }
        .navigationTitle("エチオピア イルガチェフェ")
        .navigationBarTitleDisplayMode(.inline)
    }
}
