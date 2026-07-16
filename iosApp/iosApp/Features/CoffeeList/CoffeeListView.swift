import GoogleMobileAds
import SwiftUI
import SharedLogic

// MARK: - CoffeeListView

/// コーヒー記録一覧画面。
///
/// - RootTabView の NavigationStack 内に配置されるため、自身では NavigationStack を持たない
/// - bottom-trailing 固定の FAB（`addCoffeeFAB`）から `CoffeeEditorView(mode: .Create)` を sheet 表示する
/// - 既存記録の詳細は NavigationLink で CoffeeDetailView に push する
struct CoffeeListView: View {

    @State var viewModel: CoffeeListViewModelBridge
    var appState: AppState

    /// FAB タップで開くエディタの表示状態。
    @State private var isPresentingEditor = false

    /// 長押しコンテキストメニューから編集対象に選ばれたコーヒー記録（sheet アンカー、FAB 用とは別）。
    @State private var editingCoffee: CoffeeRecord?

    /// 長押しコンテキストメニューから削除確認ダイアログの対象に選ばれたコーヒー記録。
    @State private var deletionTarget: CoffeeRecord?

    /// 先頭インラインアダプティブバナー用ローダー（requirements.md §11-3）。
    ///
    /// 2026-07-15: 上部固定（`.safeAreaInset(edge: .top)`）はスクロールで消えず常に画面を占有する
    /// ため、「スクロールで流れる」ユーザー要望を受けてリスト先頭のインライン配置に変更した
    /// （`CafeDetailView.adSection` と同じパターン）。FAB との近接誤タップ懸念は先頭配置により
    /// 解消済み。分析タブは引き続き下部固定（`AnchoredBannerAdView` + `.safeAreaInset(edge: .bottom)`）。
    @State private var adLoader = BannerAdLoader(adUnitID: AdUnitIDs.coffeeListBottomBar)

    var body: some View {
        // 追加 FAB: bottom-trailing 固定配置。検索中も表示したままにする（新規記録は検索状態と無関係）。
        content
        .overlay(alignment: .bottomTrailing) {
            addCoffeeFAB
                .padding(.trailing, 16)
                .padding(.bottom, 16)
        }
        .navigationTitle(String(localized: "コーヒー記録"))
        .navigationBarTitleDisplayMode(.large)
        .searchable(
            text: Binding(
                get: { viewModel.searchQuery },
                set: { viewModel.searchQuery = $0 }
            ),
            prompt: String(localized: "コーヒー名・カフェ名・メモで検索")
        )
        .task {
            guard let uid = appState.uid else { return }
            viewModel.onAppear(userId: uid)
        }
        .onDisappear {
            viewModel.onDisappear()
        }
        .errorToast(message: viewModel.error) {
            viewModel.onErrorDismissed()
        }
        .sheet(isPresented: $isPresentingEditor) {
            CoffeeEditorView(
                mode: CoffeeEditorViewModelModeCreate.shared,
                appState: appState,
                initialCafe: nil
            )
        }
        .sheet(item: $editingCoffee) { coffee in
            CoffeeEditorView(
                mode: CoffeeEditorViewModelModeEdit(coffeeId: coffee.id),
                appState: appState,
                initialCafe: coffee.cafe
            )
        }
    }

    // MARK: - 追加 FAB

    /// bottom-trailing 固定の「コーヒーを記録」FAB。
    private var addCoffeeFAB: some View {
        Button {
            isPresentingEditor = true
        } label: {
            Image(systemName: "plus")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Circle().fill(Color.accentColor))
                .shadow(color: Color.accentColor.opacity(0.4), radius: 12, x: 0, y: 6)
        }
        .accessibilityLabel(String(localized: "コーヒーを記録"))
    }

    // MARK: - コンテンツ

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            ProgressView()
        } else if viewModel.sections.isEmpty && viewModel.searchQuery.isEmpty {
            emptyView
        } else if viewModel.sections.isEmpty {
            // 検索クエリはあるがヒット 0 件
            ContentUnavailableView.search(text: viewModel.searchQuery)
        } else {
            coffeeList
        }
    }

    private var emptyView: some View {
        ContentUnavailableView(
            String(localized: "まだコーヒー記録がありません"),
            systemImage: "cup.and.saucer",
            description: Text(
                String(localized: "右下の + ボタンか、マップのカフェ検索からカフェを選んで記録しましょう")
            )
        )
    }

    private var coffeeList: some View {
        List {
            adSection
            ForEach(viewModel.sections) { section in
                Section {
                    ForEach(section.records) { coffee in
                        NavigationLink {
                            CoffeeDetailView(coffeeId: coffee.id, appState: appState)
                        } label: {
                            CoffeeRow(coffee: coffee)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                viewModel.onCoffeeDeleted(
                                    id: coffee.id,
                                    photoFileNames: coffee.photos.compactMap(\.fileName)
                                )
                            } label: {
                                Label(
                                    String(localized: "削除"),
                                    systemImage: "trash"
                                )
                            }
                        }
                        .contextMenu {
                            Button {
                                editingCoffee = coffee
                            } label: {
                                Label(String(localized: "編集"), systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                deletionTarget = coffee
                            } label: {
                                Label(String(localized: "削除"), systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    Text(Self.monthHeaderText(yearMonth: section.yearMonth))
                        .accessibilityAddTraits(.isHeader)
                }
            }
        }
        .listStyle(.plain)
        .confirmationDialog(
            String(localized: "コーヒー記録を削除"),
            isPresented: Binding(
                get: { deletionTarget != nil },
                set: { isPresented in if !isPresented { deletionTarget = nil } }
            ),
            titleVisibility: .visible,
            presenting: deletionTarget
        ) { coffee in
            Button(String(localized: "削除"), role: .destructive) {
                viewModel.onCoffeeDeleted(
                    id: coffee.id,
                    photoFileNames: coffee.photos.compactMap(\.fileName)
                )
                deletionTarget = nil
            }
            Button(String(localized: "キャンセル"), role: .cancel) {}
        } message: { _ in
            Text(String(localized: "この記録と写真は完全に削除されます。この操作は取り消せません。"))
        }
        .background(
            // List 自体の実測幅からインラインアダプティブバナーの幅を計算する（iPad マルチタスキング
            // でも正確な幅になる）。`.plain` リストの左右余白は概算値（`Self.adHorizontalMargin`）を
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

    /// `.plain` リストの左右余白概算（実測値より狭めに見積もり、バナーがはみ出さないようにする）。
    private static let adHorizontalMargin: CGFloat = 16
    /// インラインアダプティブバナーの上限高さ（行の高さになじむ値）。
    private static let adMaxHeight: CGFloat = 100

    /// リスト先頭のインラインアダプティブバナー（requirements.md §11-3）。
    ///
    /// `List` の `Section` は中身が空でも行の余白・区切り線を描画しうるため、ここで
    /// `adLoader.isLoaded` を直接見て**未ロード時は Section 自体を List の body に含めない**
    /// （`CafeDetailView.adSection` と同じ対応。ローダーは `coffeeList` の `List` に付けた
    /// `.background(GeometryReader).task` が保持・駆動する）。
    ///
    /// `BannerViewRepresentable` には受信済みサイズ（`adLoader.loadedAdSize`）で明示
    /// `.frame(width:height:)` を与える（公式 SwiftUI サンプル `BannerContentView.swift` と
    /// 同じ構成。サイズを明示しないと SDK 側のサイズ検証で "Invalid ad width or height" が
    /// 発生し受信済み広告が無効化されることがある。2026-07-14 実機診断で確認）。行内での
    /// センタリングは外側の `HStack` + `Spacer` で行い、representable 自体は伸縮させない。
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

    // MARK: - 月ヘッダ文字列の生成

    /// `"YYYY-MM"`（ゼロパディング）を `"YYYY年M月"`（月はゼロ埋めしない）へ変換する。
    ///
    /// 想定外のフォーマットが来た場合はそのまま `yearMonth` を返す（フォールバック）。
    static func monthHeaderText(yearMonth: String) -> String {
        let parts = yearMonth.split(separator: "-")
        guard parts.count == 2, let month = Int(parts[1]) else {
            return yearMonth
        }
        return String(localized: "\(parts[0])年\(month)月")
    }
}

// MARK: - CoffeeRow

/// コーヒー記録一覧の行コンポーネント。
struct CoffeeRow: View {

    let coffee: CoffeeRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(coffee.cafe?.name ?? String(localized: "セルフ抽出"))
                .font(.headline)
                .foregroundStyle(.primary)

            Text(coffee.name)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(formattedDate)
                .font(.caption)
                .foregroundStyle(.secondary)

            starRating
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    // MARK: - Private

    private var formattedDate: String {
        let d = coffee.visitedOn
        return String(
            format: "%04d/%02d/%02d",
            Int(d.year),
            Int(d.monthNumber),
            Int(d.dayOfMonth)
        )
    }

    private var starRating: some View {
        StarRatingView(rating: coffee.rating?.doubleValue, size: .caption2)
    }

    private var accessibilityDescription: String {
        let cafeName = coffee.cafe?.name ?? String(localized: "セルフ抽出")
        let ratingStr: String
        if let rating = coffee.rating?.doubleValue {
            ratingStr = rating.truncatingRemainder(dividingBy: 1) == 0
                ? "\(Int(rating))星"
                : "\(rating)星"
        } else {
            ratingStr = String(localized: "未評価")
        }
        return "\(cafeName), \(coffee.name), \(formattedDate), \(ratingStr)"
    }
}

// MARK: - Preview (CoffeeRow 単体)

#Preview("CoffeeRow") {
    List {
        CoffeeRow(coffee: PreviewSamples.sampleCoffeeRecord)
        CoffeeRow(coffee: PreviewSamples.sampleCoffeeRecordSelfBrew)
    }
}

// MARK: - Preview (空状態)

#Preview("空状態") {
    NavigationStack {
        ContentUnavailableView(
            String(localized: "まだコーヒー記録がありません"),
            systemImage: "cup.and.saucer",
            description: Text(
                String(localized: "右下の + ボタンか、マップのカフェ検索からカフェを選んで記録しましょう")
            )
        )
        .navigationTitle(String(localized: "コーヒー記録"))
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Preview (一覧 Demo)

#Preview("一覧 Demo") {
    NavigationStack {
        List {
            ForEach(PreviewSamples.sampleCoffeeRecords) { coffee in
                CoffeeRow(coffee: coffee)
            }
        }
        .listStyle(.plain)
        .navigationTitle(String(localized: "コーヒー記録"))
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Preview (月別セクション Demo)

#Preview("月別セクション Demo") {
    let sections: [CoffeeListViewModel.MonthSection] = [
        CoffeeListViewModel.MonthSection(
            yearMonth: "2026-06",
            records: [PreviewSamples.sampleCoffeeRecord, PreviewSamples.sampleCoffeeRecordSelfBrew]
        ),
        CoffeeListViewModel.MonthSection(
            yearMonth: "2026-05",
            records: [PreviewSamples.sampleCoffeeRecordWithoutPhotos]
        ),
    ]
    NavigationStack {
        List {
            ForEach(sections) { section in
                Section {
                    ForEach(section.records) { coffee in
                        CoffeeRow(coffee: coffee)
                    }
                } header: {
                    Text(CoffeeListView.monthHeaderText(yearMonth: section.yearMonth))
                        .accessibilityAddTraits(.isHeader)
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(String(localized: "コーヒー記録"))
        .navigationBarTitleDisplayMode(.large)
    }
}
