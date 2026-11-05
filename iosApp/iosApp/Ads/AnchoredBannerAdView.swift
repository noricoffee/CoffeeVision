import GoogleMobileAds
import SwiftUI

/// 全タブ常設の下部固定広告帯（requirements.md §11-5、`docs/ui-ux-guidelines.md`「下部固定広告帯」）。
///
/// ## サイズ: `inlineAdaptiveBanner(width:maxHeight:)`、`maxHeight` は `Self.maxAdHeight`（50pt、Google 推奨の下限）
///
/// 当初は「アンカード用の帯なのでアンカード用のサイズを使う」判断で `currentOrientationAnchoredAdaptiveBanner(width:)`
/// → （非推奨のため）`largeAnchoredAdaptiveBanner(width:)` の順に検討したが、**サイズ選択と高さの見た目は
/// 独立した問題だった**。`largeAnchoredAdaptiveBanner` は高さ上限が「device のポートレート高さの 20%、
/// 常に 50-150pt」で、実機シミュレータでの目視確認で画面の約 15% を占め、常設帯としては大きすぎると
/// ユーザーが判断した。**高さの天井が欲しいだけなので、アンカード用の関数である必要はない** —
/// 撤去済みの旧インライン広告（カフェ詳細画面 / マップ検索結果一覧）と同じ `inlineAdaptiveBanner(width:maxHeight:)`
/// （非推奨ではない）に `maxHeight: Self.maxAdHeight`（50pt）を渡す方式に変更した。
/// **この帯はアンカード配置（下部固定）だが、サイズ計算はインライン用の関数を使っている**。
/// 次に触る人が「アンカード帯なのにインラインサイズを使っている」と見て `largeAnchoredAdaptiveBanner`
/// 等へ戻さないこと — 高さを固定したいという要件が先にあり、そのために意図してこの関数を選んでいる。
/// **`maxAdHeight` をこれ以上下げない理由は `maxAdHeight` 自体の doc コメント参照**（Google 推奨の下限）。
///
/// ## その他のサイズ・ロード関連の作法
///
/// - 幅の実測 / ロード発火は撤去済みの旧インライン広告と同じ作法
///   （`.background(GeometryReader { Color.clear.task(id: proxy.size.width) })` +
///   `BannerAdLoader.minimumRequestableWidth` ガード。2026-07-14 実機診断で確立した対処で、
///   外すと「ゴミ幅でロードして回復不能」「`.task` が発火しない」が再発する）
/// - `BannerViewRepresentable` には受信済みサイズ（`loader.loadedAdSize`）で明示 `.frame(width:height:)`
///   を与える（サイズを明示しないと SDK 側のサイズ検証で無効化されることがある）
///
/// ## 高さは常時 `Self.maxAdHeight` を確保する（撤去済みの旧インライン広告とは作法が違う）
///
/// **撤去済みの旧インライン広告（カフェ詳細のセクション間 / 検索結果の 3 件目の後）は
/// 「未受信・失敗時は高さ 0 に畳む」作法だった**。これはコンテンツの流れの中に挟まる 1 枠の作法で、
/// その枠だけが現れたり消えたりしても周囲の行がその分ずれるだけで済む。**この常設帯は違う**。高さ 0 で畳んで
/// ロード完了時に `Self.maxAdHeight` へ広がると、`VStack` で縦に並んでいる `content`（`RootTabView`）の
/// 高さも同時に変わり、**タブバーごと画面上へ跳ねる**（`.claude/rules/swift-ios.md`「幅・高さを持つ要素を
/// `if` で条件生成しない」と同じ問題が、`if` ではなく `.frame(height:)` の出し分けで起きた実例。
/// 2026-09-19 ユーザー実機確認で発覚）。そのため **`AnchoredBannerAdBar` は読み込み状態に関わらず
/// 高さを `Self.maxAdHeight` に固定**し、受信した広告（`loadedAdSize.height` は `maxAdHeight` 以下になりうる）は
/// その枠の中に中央寄せで配置する。未ロード・失敗・オフラインのいずれでも `Self.maxAdHeight` 分の
/// 無地の帯（`Color(.systemBackground)`）がそのまま残る（プレースホルダというより「常設の帯の一部」）。
///
/// ## 自動リフレッシュ: クライアント側タイマー（`isAutoloadEnabled` は不採用）
///
/// 常設枠のため自動リフレッシュが要る（無しだと 1 セッション 1 インプレッションで終わる）。
/// `BannerView.isAutoloadEnabled` を有効にする案を検討したが、以下の理由で不採用とした:
///
/// - 公式リファレンス（`GADBannerView.h` / developers.google.com/admob/ios/api/reference/Classes/GADBannerView）
///   は「有効にすると `load(_:)` を呼ばなくてよくなる」としか書いておらず、SDK が自動生成する
///   リフレッシュ用リクエストに、こちらの `Request`（`BannerAdLoader.makeRequest()` の NPA extras 含む）が
///   反映されるのかが確認できない
/// - developers.google.com/admob/ios/banner「Refresh an ad」は「広告ユニット側でリフレッシュを設定していれば
///   SDK がその値を尊重する」「表示中のときだけリフレッシュする」とだけ述べ、リフレッシュ間隔は
///   AdMob コンソール側の広告ユニット設定に依存する。コードから完全に制御できないため、
///   ATT 拒否ユーザーへの NPA 徹底という規約遵守が要る箇所をコンソール設定に委ねるのはリスクが高いと判断
/// - `GADRequestConfiguration.publisherPrivacyPersonalizationState`（`GADRequestConfiguration.h`）は
///   「設定はすべての広告リクエストに適用される」ためグローバルな NPA 担保の候補ではあるが、
///   「autoload のリフレッシュ要求にも適用されるか」を明言した記述は見つからなかった
///
/// 上記の不確実性を避けるため、**`isAutoloadEnabled` は `false` のまま**（他の 2 面と同じ）にし、
/// 既存の `load(adSize:forceReload:)` 経路（毎回 `makeRequest()` で NPA extras を都度評価）を
/// 60 秒間隔のクライアント側タイマーから呼ぶ方式にした。`scenePhase == .active` のときのみ動かし、
/// バックグラウンドでは止める（AdMob の下限 30 秒を守った 60 秒間隔）。
private struct AnchoredBannerAdBar: View {

    var loader: BannerAdLoader
    /// 同意フロー（データ利用同意オンボーディング → 広告プレプロンプト → ATT）が閉じるまでは
    /// `false`。閉じるまでロードを開始しない（起動と同時にロードすると ATT が `.notDetermined` の
    /// ままリクエストが飛び、セッション最初のインプレッションが必ず NPA になるため）。
    var canLoad: Bool

    @Environment(\.scenePhase) private var scenePhase

    private static let refreshInterval: Duration = .seconds(60)
    /// 常設帯として大きすぎないよう抑えた高さの天井（ユーザー実機確認で決定。上記クラス doc 参照）。
    /// **この帯自体の高さでもある**（読み込み状態に関わらず常時この高さを確保する。下記 `body` 参照）。
    ///
    /// **50 は Google Mobile Ads SDK が定める実質的な下限であり、これ以上小さくしない。**
    /// `GADAdSize.h` の `GADInlineAdaptiveBannerAdSizeWithWidthAndMaxHeight` の doc コメント:
    /// 「`maxHeight` は 32px 以上必須、50px 以上を推奨（"Must be at least 32 px, but a max height of
    /// 50 px or higher is recommended."）」。32px まで機械的には下げられるが、それは Google が
    /// 推奨する範囲の外（32-49px）に踏み込むことを意味する。**「もっと小さくしたい」という要望が
    /// 今後来ても、50 未満へは下げない**（60→50 は「標準バナー相当まで削った」結果であり、
    /// これは Google 非推奨領域への突入とは別物）。
    private static let maxAdHeight: CGFloat = 50

    var body: some View {
        // 高さは読み込み状態に関わらず常時 `maxAdHeight` を確保する（上記クラス doc「高さは常時
        // maxAdHeight を確保する」参照。ロード完了時に 0→maxAdHeight へ変化すると VStack 越しに
        // タブバーごと跳ねるため、`if` 相当の出し分けをしない）。受信した広告は枠内に中央寄せで配置する。
        ZStack {
            if loader.isLoaded, let bannerView = loader.bannerView, let loadedAdSize = loader.loadedAdSize {
                BannerViewRepresentable(bannerView: bannerView)
                    .frame(width: loadedAdSize.width, height: loadedAdSize.height)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(height: Self.maxAdHeight)
        // 背景は常時描く（未ロード時も無地の帯が見える状態が正しい。上記参照）。
        // `.ignoresSafeArea` はホームインジケータの裏まで背景だけ伸ばすため
        // （`docs/ui-ux-guidelines.md`「下部固定広告帯」）。
        .background(
            Color(.systemBackground)
                .ignoresSafeArea(.container, edges: .bottom)
        )
        // 幅の実測 / ロード発火専用（2026-07-14 の作法。上記の背景伸長とは無関係）。
        .background(
            GeometryReader { proxy in
                Color.clear
                    .task(id: LoadContext(width: proxy.size.width, scenePhase: scenePhase, canLoad: canLoad)) {
                        await manageLoadAndRefresh(width: proxy.size.width)
                    }
            }
        )
    }

    /// 幅・`scenePhase`・`canLoad` のいずれかが変わるたびに `.task(id:)` 経由で呼び直される。
    /// 初回ロード（無条件）→ フォアグラウンドのときだけ 60 秒間隔のリフレッシュループへ進む。
    private func manageLoadAndRefresh(width: CGFloat) async {
        guard canLoad, width >= BannerAdLoader.minimumRequestableWidth else { return }
        loader.load(adSize: inlineAdaptiveBanner(width: width, maxHeight: Self.maxAdHeight))

        guard scenePhase == .active else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: Self.refreshInterval)
            guard !Task.isCancelled else { return }
            loader.load(
                adSize: inlineAdaptiveBanner(width: width, maxHeight: Self.maxAdHeight),
                forceReload: true
            )
        }
    }

    private struct LoadContext: Equatable {
        let width: CGFloat
        let scenePhase: ScenePhase
        let canLoad: Bool
    }
}

/// `RootTabView` を下部固定広告帯で包む modifier（requirements.md §11-5）。
/// `AppRootView` の ready 分岐にのみ適用する。
///
/// **`VStack(spacing:)` で `content` と広告帯を縦に並べる**（`.safeAreaInset(edge: .bottom)` は
/// 不採用）。`.safeAreaInset` はビューのフレームを縮めずセーフエリアの報告値だけを増やすため、
/// iOS 26 の浮動タブバーのように「自身のフレーム基準で画面下端に描画する」コンポーネントには効かず、
/// `content`（`RootTabView`）のフレームが画面全体のまま広告帯の背景の裏に隠れてしまった
/// （2026-09-19 ユーザー実機確認で発覚）。`VStack` は `content` に実際に縮んだフレームを与えるため、
/// `RootTabView` 内の浮動タブバーもその縮んだフレームの下端（= 広告帯の直上）に描画される。
///
/// - `spacing` は**常時 8pt**（タブバーとの間の最低余白。誤タップ防止）。`AnchoredBannerAdBar` 自体が
///   常時高さを確保する帯になった（読み込み状態で高さが変わらない）ため、この余白も出し分けない
///   — 出し分けると結局「未ロード時は隙間だけ残る／ロード完了時に隙間が現れて跳ねる」という
///   同じ種類の問題が spacing 側で再発する
/// - `.errorToast` より外側 / `.preferredColorScheme` より内側に適用する順序は
///   `docs/ui-ux-guidelines.md`「下部固定広告帯」を参照
private struct BottomAdBannerModifier: ViewModifier {

    var loader: BannerAdLoader
    var canLoad: Bool

    private static let tabBarSpacing: CGFloat = 8

    func body(content: Content) -> some View {
        VStack(spacing: Self.tabBarSpacing) {
            content
            AnchoredBannerAdBar(loader: loader, canLoad: canLoad)
                .ignoresSafeArea(.keyboard, edges: .bottom)
        }
    }
}

extension View {
    /// 全タブ常設の下部固定アダプティブバナー広告帯を適用する（requirements.md §11-5）。
    /// - Parameters:
    ///   - loader: この枠専用の `BannerAdLoader`（呼び出し側が所有・保持する）
    ///   - canLoad: 同意フローが閉じているか。`false` の間はロードもリフレッシュも開始しない
    func bottomAdBanner(loader: BannerAdLoader, canLoad: Bool) -> some View {
        modifier(BottomAdBannerModifier(loader: loader, canLoad: canLoad))
    }
}
