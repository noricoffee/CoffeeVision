import GoogleMobileAds
import SwiftUI
import SharedLogic

/// カフェ詳細画面。
///
/// - カフェ情報（名前 / 住所）+ 過去コーヒー記録一覧を表示する
/// - ツールバーの `+` ボタンで `CoffeeEditorView` を sheet で起動（cafe pre-filled）
/// - NavigationStack push ごとに新規 Bridge を生成するため、`@State` で保持する
/// - マップの Annotation タップ / 検索結果タップの両方から push される
/// - observation は `bridge` の `deinit`（= View 破棄）まで生かす。`onDisappear` での
///   cancel は push → pop 後の再表示で observation が凍結するバグになるため行わない
///   （`kmp-bridge.md` の既知パターン）
struct CafeDetailView: View {

    // MARK: - Properties

    let placeId: String
    let initialCafe: Cafe?
    var appState: AppState

    @State private var bridge: CafeDetailViewModelBridge?
    @State private var isPresentingEditor = false

    /// インラインアダプティブバナー（requirements.md §11-1）のローダー。`cafeDetailList` の
    /// `List` 自体に `.background(GeometryReader)` + `.task` を付けてロードする
    /// （常に実体化されるビューに付けるため確実に発火する。詳細は `adSection` のコメント参照）。
    @State private var adLoader = BannerAdLoader(adUnitID: AdUnitIDs.cafeDetail)

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
        .trackScreen("cafe_detail")
        .navigationTitle(bridge?.cafe?.name ?? initialCafe?.name ?? String(localized: "カフェ詳細"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .errorToast(message: bridge?.error) {
            bridge?.onErrorDismissed()
        }
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
            if let cafe = bridge.cafe ?? initialCafe {
                headerSection(cafe: cafe, bridge: bridge)
            }
            cafeInfoSection(bridge: bridge)
            if let cafe = bridge.cafe ?? initialCafe {
                cafeLinksSection(cafe: cafe)
                cafeHoursSection(cafe: cafe)
            }
            adSection
            coffeesSection(bridge: bridge)
        }
        .listStyle(.insetGrouped)
        .background(
            // List 自体の実測幅からインラインアダプティブバナーの幅を計算する（iPad マルチタスキング
            // でも正確な幅になる）。`.insetGrouped` の左右余白は概算値（`Self.adHorizontalMargin`）を
            // 差し引く。Color.clear は常に実体化されるため `.task` は確実に発火する。
            GeometryReader { proxy in
                Color.clear
                    .task(id: proxy.size.width) {
                        let width = proxy.size.width - Self.adHorizontalMargin * 2
                        // レイアウト測定の過渡状態（ゴミ幅・負値）でリクエストしない
                        // （`BannerAdLoader.minimumRequestableWidth` 参照。2026-07-14 実機診断で確認）。
                        guard width >= BannerAdLoader.minimumRequestableWidth else { return }
                        adLoader.load(adSize: inlineAdaptiveBanner(width: width, maxHeight: Self.adMaxHeight))
                    }
            }
        )
    }

    /// `.insetGrouped` リストの左右余白概算（実測値より狭めに見積もり、バナーがはみ出さないようにする）。
    private static let adHorizontalMargin: CGFloat = 32
    /// インラインアダプティブバナーの上限高さ（行の高さになじむ値）。
    private static let adMaxHeight: CGFloat = 100

    // MARK: - 視覚ヘッダー（写真帯 + 店名 + 評価 / 営業状態 / 価格帯 + 保存ボタン）

    @ViewBuilder
    private func headerSection(cafe: Cafe, bridge: CafeDetailViewModelBridge) -> some View {
        let photoHeader = CafePhotoHeader(
            cafe: cafe,
            coffees: bridge.coffees,
            photoLoader: appState.placePhotoLoader
        )

        Section {
            if !photoHeader.isEmpty {
                photoHeader
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(cafe.name)
                    .font(.title2.bold())
                headerInfoRow(cafe: cafe)
            }

            saveButton(bridge: bridge)
        }
    }

    /// 「★4.5 (128件)」+ 営業状態 + 価格帯を 1 行にまとめた行。
    private func headerInfoRow(cafe: Cafe) -> some View {
        HStack(spacing: 8) {
            if let openNow = cafe.openNow?.boolValue {
                HStack(spacing: 4) {
                    Circle()
                        .fill(openNow ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(openNow ? String(localized: "営業中") : String(localized: "営業時間外"))
                        .foregroundStyle(openNow ? .green : .red)
                }
            }

            if let rating = cafe.googleRating?.doubleValue {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                    Text(ratingText(rating: rating, count: cafe.userRatingCount?.intValue))
                        .foregroundStyle(.secondary)
                }
            }

            if let level = cafe.priceLevel, let text = priceLevelText(for: level) {
                Text(text)
                    .foregroundStyle(.secondary)
            }
        }
        .font(.subheadline)
        .accessibilityElement(children: .combine)
    }

    /// 「★4.5 (128件)」形式の評価テキスト。件数が nil または 0 のときは括弧を省略する。
    private func ratingText(rating: Double, count: Int?) -> String {
        let ratingStr = String(format: "%.1f", rating)
        if let count, count > 0 {
            return "\(ratingStr) (\(count)件)"
        }
        return ratingStr
    }

    /// 写真帯直下の全幅保存ボタン。未保存 = 「保存する」（bordered + indigo）、保存済み = 「保存済み」
    /// （borderedProminent + indigo）。両状態とも tint は indigo で固定し、状態の違いは塗りの有無
    /// （bordered / borderedProminent）で表す。色セマンティクスの詳細は `docs/ui-ux-guidelines.md`
    /// のマップ概念の色セマンティクス表を参照。旧ツールバーの bookmark トグルから移設（フェーズ 16）。
    @ViewBuilder
    private func saveButton(bridge: CafeDetailViewModelBridge) -> some View {
        let label = Label(
            bridge.isSaved ? String(localized: "保存済み") : String(localized: "保存する"),
            systemImage: bridge.isSaved ? "bookmark.fill" : "bookmark"
        )
        .frame(maxWidth: .infinity)

        Group {
            if bridge.isSaved {
                Button(action: bridge.onSaveToggled) { label }
                    .buttonStyle(.borderedProminent)
                    .tint(.indigo)
            } else {
                Button(action: bridge.onSaveToggled) { label }
                    .buttonStyle(.bordered)
                    .tint(.indigo)
            }
        }
        .controlSize(.large)
        .sensoryFeedback(.selection, trigger: bridge.isSaved)
        .accessibilityLabel(
            bridge.isSaved
                ? String(localized: "行きたい店から削除")
                : String(localized: "行きたい店に追加")
        )
    }

    // MARK: - カフェ情報セクション

    private func cafeInfoSection(bridge: CafeDetailViewModelBridge) -> some View {
        Section {
            if let cafe = bridge.cafe ?? initialCafe {
                if let address = cafe.address, !address.isEmpty {
                    LabeledContent(String(localized: "住所")) {
                        Text(address)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel(String(localized: "住所 \(address)"))
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
        } header: {
            Text(String(localized: "カフェ情報"))
        } footer: {
            GoogleMapsAttributionText()
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

    // MARK: - 広告セクション

    /// 情報系セクション（カフェ情報 / 外部リンク / 営業時間）とコーヒー記録セクションの間の
    /// インラインアダプティブバナー（requirements.md §11-1）。
    ///
    /// `List` の `Section` は中身が空でも行の余白・区切り線を描画しうるため、ここで
    /// `adLoader.isLoaded` を直接見て**未ロード時は Section 自体を List の body に含めない**
    /// （2026-07-14 実機診断で確認した対応。ローダーは `cafeDetailList` の `List` に付けた
    /// `.background(GeometryReader).task` が保持・駆動する）。
    ///
    /// `BannerViewRepresentable` には受信済みサイズ（`adLoader.loadedAdSize`）で明示
    /// `.frame(width:height:)` を与える（公式 SwiftUI サンプル `BannerContentView.swift` と
    /// 同じ構成）。サイズを明示しないと SwiftUI がレイアウト中に異なる frame を与えてしまい、
    /// SDK 側のサイズ検証で "Invalid ad width or height" が発生し受信済み広告が無効化される
    /// ことがある（2026-07-14 実機診断で確認）。行内でのセンタリングは外側の `HStack` + `Spacer`
    /// で行い、representable 自体は伸縮させない。
    @ViewBuilder
    private var adSection: some View {
        if adLoader.isLoaded, let bannerView = adLoader.bannerView, let loadedAdSize = adLoader.loadedAdSize {
            Section {
                HStack {
                    Spacer(minLength: 0)
                    BannerViewRepresentable(bannerView: bannerView)
                        .frame(width: loadedAdSize.width, height: loadedAdSize.height)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity)
                .listRowInsets(EdgeInsets())
            }
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
            StarRatingView(rating: coffee.rating?.doubleValue, size: .caption)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(localized: "\(coffee.name), \(formattedDate), \(ratingAccessibilityText)")
        )
    }

    private var ratingAccessibilityText: String {
        guard let rating = coffee.rating?.doubleValue else {
            return String(localized: "未評価")
        }
        return rating.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(rating))星"
            : "\(rating)星"
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
