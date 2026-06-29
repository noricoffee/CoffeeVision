import SwiftUI
import SharedLogic

/// カフェ詳細画面。
///
/// - カフェ情報（名前 / 住所）+ 過去コーヒー記録一覧を表示する
/// - ツールバーの `+` ボタンで `CoffeeEditorView` を sheet で起動（cafe pre-filled）
/// - NavigationStack push ごとに新規 Bridge を生成するため、`@State` で保持する
/// - マップの Annotation タップ / 検索結果タップの両方から push される
struct CafeDetailView: View {

    // MARK: - Properties

    let placeId: String
    let initialCafe: Cafe?
    var appState: AppState

    @State private var bridge: CafeDetailViewModelBridge?
    @State private var isPresentingEditor = false

    // MARK: - Body

    var body: some View {
        Group {
            if let bridge {
                if bridge.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    cafeDetailList(bridge: bridge)
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(bridge?.cafe?.name ?? initialCafe?.name ?? String(localized: "カフェ詳細"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .onAppear {
            if bridge == nil, let uid = appState.uid {
                bridge = CafeDetailViewModelBridge(
                    viewModel: appState.container.makeCafeDetailViewModel(
                        placeId: placeId,
                        initialCafe: initialCafe,
                        userId: uid
                    )
                )
            }
        }
        .onDisappear {
            bridge?.cancel()
        }
        .sheet(isPresented: $isPresentingEditor) {
            CoffeeEditorView(
                mode: CoffeeEditorViewModelModeCreate.shared,
                appState: appState,
                initialCafe: bridge?.cafe ?? initialCafe
            )
        }
    }

    // MARK: - リストコンテンツ

    private func cafeDetailList(bridge: CafeDetailViewModelBridge) -> some View {
        List {
            cafeInfoSection(bridge: bridge)
            if let cafe = bridge.cafe ?? initialCafe {
                cafeLinksSection(cafe: cafe)
                cafeHoursSection(cafe: cafe)
            }
            coffeesSection(bridge: bridge)
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - カフェ情報セクション

    private func cafeInfoSection(bridge: CafeDetailViewModelBridge) -> some View {
        Section(String(localized: "カフェ情報")) {
            if let cafe = bridge.cafe ?? initialCafe {
                LabeledContent(String(localized: "名前")) {
                    Text(cafe.name)
                        .multilineTextAlignment(.trailing)
                }
                .accessibilityLabel(String(localized: "カフェ名 \(cafe.name)"))

                if let address = cafe.address, !address.isEmpty {
                    LabeledContent(String(localized: "住所")) {
                        Text(address)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel(String(localized: "住所 \(address)"))
                }

                if let openNow = cafe.openNow?.boolValue {
                    LabeledContent(String(localized: "営業状態")) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(openNow ? Color.green : Color.red)
                                .frame(width: 8, height: 8)
                            Text(openNow ? String(localized: "営業中") : String(localized: "営業時間外"))
                                .foregroundStyle(openNow ? .green : .red)
                        }
                    }
                    .accessibilityLabel(
                        String(localized: "営業状態: \(openNow ? "営業中" : "営業時間外")")
                    )
                }

                if let rating = cafe.googleRating?.doubleValue {
                    LabeledContent(String(localized: "Google 評価")) {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                                .font(.caption)
                            Text(String(format: "%.1f", rating))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityLabel(
                        String(localized: "Google 評価 \(String(format: "%.1f", rating))")
                    )
                }

                if let level = cafe.priceLevel, let text = priceLevelText(for: level) {
                    LabeledContent(String(localized: "価格帯")) {
                        Text(text)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel(String(localized: "価格帯 \(text)"))
                }

                if let phone = cafe.phoneNumber,
                   let url = URL(string: "tel:\(phone)") {
                    Link(destination: url) {
                        Label(phone, systemImage: "phone")
                            .foregroundStyle(Color.accentColor)
                    }
                    .accessibilityLabel(String(localized: "電話する \(phone)"))
                }

                LabeledContent(String(localized: "記録 \(bridge.coffees.count) 杯")) {
                    EmptyView()
                }
                .accessibilityLabel(String(localized: "記録 \(bridge.coffees.count) 杯"))
            } else {
                Text(String(localized: "カフェ情報を読み込み中..."))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - 外部リンクセクション

    /// `websiteUrl` / `mapsUrl` が 1 つ以上 non-nil のときだけ Section を表示する。
    @ViewBuilder
    private func cafeLinksSection(cafe: Cafe) -> some View {
        if cafe.websiteUrl != nil || cafe.mapsUrl != nil {
            Section(String(localized: "外部リンク")) {
                if let urlStr = cafe.websiteUrl, let url = URL(string: urlStr) {
                    Link(destination: url) {
                        Label(String(localized: "公式サイト"), systemImage: "globe")
                            .foregroundStyle(Color.accentColor)
                    }
                    .accessibilityLabel(String(localized: "公式サイトを開く"))
                }
                if let urlStr = cafe.mapsUrl, let url = URL(string: urlStr) {
                    Link(destination: url) {
                        Label(String(localized: "Google Maps で開く"), systemImage: "map")
                            .foregroundStyle(Color.accentColor)
                    }
                    .accessibilityLabel(String(localized: "Google Maps で開く"))
                }
            }
        }
    }

    // MARK: - 営業時間セクション

    /// `weekdayDescriptions` が空でないときだけ Section を表示する。
    @ViewBuilder
    private func cafeHoursSection(cafe: Cafe) -> some View {
        if !cafe.weekdayDescriptions.isEmpty {
            Section(String(localized: "営業時間")) {
                ForEach(cafe.weekdayDescriptions, id: \.self) { line in
                    Text(line)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - ヘルパ

    /// Kotlin の `priceLevel` 文字列を表示用テキスト（`¥` 記号または `"無料"`）に変換する。
    /// 不明な値は `nil` を返し、呼び出し側で非表示にする。
    private func priceLevelText(for level: String) -> String? {
        switch level {
        case "PRICE_LEVEL_FREE":          return String(localized: "無料")
        case "PRICE_LEVEL_INEXPENSIVE":   return "¥"
        case "PRICE_LEVEL_MODERATE":      return "¥¥"
        case "PRICE_LEVEL_EXPENSIVE":     return "¥¥¥"
        case "PRICE_LEVEL_VERY_EXPENSIVE": return "¥¥¥¥"
        default:                          return nil
        }
    }

    // MARK: - コーヒー記録セクション

    private func coffeesSection(bridge: CafeDetailViewModelBridge) -> some View {
        Section(String(localized: "コーヒー記録")) {
            if bridge.coffees.isEmpty {
                emptyRecordsView
            } else {
                ForEach(bridge.coffees) { coffee in
                    NavigationLink {
                        CoffeeDetailView(coffeeId: coffee.id, appState: appState)
                    } label: {
                        CoffeeSummaryRow(coffee: coffee)
                    }
                }
            }
        }
    }

    /// コーヒー記録がない場合の空表示 + 記録追加誘導。
    private var emptyRecordsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "cup.and.saucer")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text(String(localized: "まだコーヒー記録がありません"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button {
                isPresentingEditor = true
            } label: {
                Label(
                    String(localized: "コーヒーを記録"),
                    systemImage: "plus.circle.fill"
                )
                .font(.body.bold())
            }
            .accessibilityLabel(String(localized: "コーヒーを記録"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    // MARK: - ツールバー

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                isPresentingEditor = true
            } label: {
                Label(
                    String(localized: "コーヒーを記録"),
                    systemImage: "plus"
                )
            }
            .accessibilityLabel(String(localized: "コーヒーを記録"))
            .disabled(appState.uid == nil)
        }
    }
}

// MARK: - CoffeeSummaryRow

/// カフェ詳細画面内の過去コーヒー記録行コンポーネント。
private struct CoffeeSummaryRow: View {

    let coffee: CoffeeRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(coffee.name)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Text(formattedDate)
                .font(.caption)
                .foregroundStyle(.secondary)
            StarRatingView(rating: coffee.rating, size: .caption)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(localized: "\(coffee.name), \(formattedDate), \(coffee.rating.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(coffee.rating))" : "\(coffee.rating)")星")
        )
    }

    private var formattedDate: String {
        let d = coffee.visitedOn
        return String(
            format: "%04d/%02d/%02d",
            Int(d.year),
            Int(d.monthNumber),
            Int(d.dayOfMonth)
        )
    }
}
