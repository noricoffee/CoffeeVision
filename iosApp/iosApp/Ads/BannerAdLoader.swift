import GoogleMobileAds
import Observation

/// カフェ詳細 / マップ検索ドロップダウンの 2 面で共有するアダプティブバナー広告ローダー
/// （requirements.md §11。コーヒー記録・分析タブの 2 面は 2026-07-16 に撤去済み。git 履歴で復元可能）。
///
/// - 自動リフレッシュなし。呼び出し側（`InlineBannerAdView`）が
///   画面表示（push / タブ遷移）のたびに `load(adSize:)` を呼ぶ
/// - ロード失敗・オフライン時は `isLoaded` が `false` のままになり、呼び出し側が枠ごと畳む
///   （プレースホルダなし）
/// - Places 由来のデータ（店名 / カテゴリ等）は広告リクエストに一切含めない
///   （Google Maps Platform 規約遵守。`makeRequest()` はキーワード・カスタムターゲティング
///   等を一切設定しない素のリクエストのみを組み立てる）
/// - ロードトリガーは呼び出し側で常に実体化されるビュー（`ZStack` / `Color.clear` 等）に
///   `.task` を付けて呼ぶこと。`Group { if let ... }` に付けると条件が偽の初回描画時に
///   `.task` の付け先が実体化されず発火しないことがある（2026-07-14 実機診断で確認）。
/// - `.task(id: proxy.size.width)` はレイアウト測定の過渡状態（実測 0 に近いゴミ幅）で
///   何度も発火しうる。過渡幅で即リクエストすると「ゴミ幅でロード中に正しい幅の再発火が
///   `isLoading` ガードで破棄され、幅が変化しないので `task(id:)` が再発火せず回復不能になる」
///   実機バグが起きたため（2026-07-14）、以下の 2 段構えで堅牢化している:
///   1. **呼び出し側**（`InlineBannerAdView` / `CafeDetailView`）が
///      `minimumRequestableWidth` 未満の幅ではそもそも `load(adSize:)` を呼ばない
///   2. **`pendingAdSize` 方式**: それでも `isLoading` 中に新しい `load(adSize:)` が来たら
///      破棄せず `pendingAdSize` に保存し、現在のロード完了（成功 / 失敗どちらでも）後に
///      追いかけてロードする。「最後に要求されたサイズが最終的に必ずロードされる」ことを保証する
@MainActor
@Observable
final class BannerAdLoader: NSObject {

    /// 幅の実測値がこれ未満のときは `load(adSize:)` を呼ばないこと（呼び出し側の責務）。
    /// iPad の Slide Over / Split View の実用上の最小幅（約 320pt）よりかなり小さい値なので、
    /// 正常なレイアウトでこの値を下回ることは実質ない。レイアウト測定の過渡状態（実測 0 に
    /// 近いゴミ幅）を弾くためのしきい値（2026-07-14 実機診断で発覚した不具合対応）。
    static let minimumRequestableWidth: CGFloat = 150

    private(set) var bannerView: BannerView?
    private(set) var isLoading = false
    private(set) var isLoaded = false
    private(set) var loadFailed = false
    /// 受信済み広告の実サイズ（`bannerViewDidReceiveAd` 時点の `bannerView.adSize.size`）。
    /// `BannerViewRepresentable` に明示 `.frame(width:height:)` を与えるために公開する
    /// （公式 SwiftUI サンプル `BannerContentView.swift` と同じ構成。representable にサイズを
    /// 明示しないと SwiftUI がレイアウト中に異なるサイズへ frame を変えてしまい、SDK 側の
    /// サイズ検証で "Invalid ad width or height" が発生し、受信済み広告が無効化されることがある。
    /// 2026-07-14 実機診断で確認）。
    private(set) var loadedAdSize: CGSize?

    private let adUnitID: String

    /// 現在ロード済み（またはロード中）のサイズ。同一サイズへの重複リクエストを避けるために使う。
    private var currentSize: AdSize?
    /// `isLoading` 中に来た最新のロード要求。現在のロードが完了(成功/失敗)したら追いかけてロードする。
    private var pendingAdSize: AdSize?
    /// 一度でも広告を受信したことがあるか。以後の失敗で表示中の広告を畳まないための記録。
    private var hasEverReceivedAd = false

    init(adUnitID: String) {
        self.adUnitID = adUnitID
    }

    /// 画面表示のたびに呼ぶ。
    /// - ロード中に呼ばれた場合は破棄せず `pendingAdSize` に保存し、完了後に追いかけてロードする
    /// - 既に同一サイズでロード済みのときは no-op（無限リロード防止）
    /// - 初回は `adSize` で `BannerView` を生成し、2 回目以降は既存のビューを使い回して再ロードする
    func load(adSize: AdSize) {
        guard !isLoading else {
            pendingAdSize = adSize
            return
        }
        if isLoaded, let currentSize, isAdSizeEqualToSize(size1: currentSize, size2: adSize) {
            return
        }
        isLoading = true
        loadFailed = false
        currentSize = adSize

        let bannerView: BannerView
        if let existing = self.bannerView {
            bannerView = existing
            bannerView.adSize = adSize
        } else {
            bannerView = BannerView(adSize: adSize)
            bannerView.adUnitID = adUnitID
            bannerView.isAutoloadEnabled = false
            bannerView.delegate = self
            self.bannerView = bannerView
        }
        bannerView.rootViewController = RootViewControllerProvider.current
        bannerView.load(Self.makeRequest())
    }

    /// 現在のロード完了（成功/失敗どちらでも）後に呼ぶ。`pendingAdSize` があれば追いかけてロードする。
    private func loadPendingIfNeeded() {
        guard let pendingAdSize else { return }
        self.pendingAdSize = nil
        load(adSize: pendingAdSize)
    }

    /// Places 由来のデータを一切含まない素の広告リクエストを生成する。
    /// ATT が「許可」以外のときは非パーソナライズ広告（NPA）としてリクエストする
    /// （requirements.md §11-4、AdMob の標準的な NPA 指定方式）。
    private static func makeRequest() -> Request {
        let request = Request()
        if !AdConsentCoordinator.isPersonalizedAdsAllowed {
            let extras = Extras()
            extras.additionalParameters = ["npa": "1"]
            request.register(extras)
        }
        return request
    }
}

// MARK: - BannerViewDelegate

extension BannerAdLoader: BannerViewDelegate {
    func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        isLoading = false
        isLoaded = true
        loadFailed = false
        hasEverReceivedAd = true
        loadedAdSize = bannerView.adSize.size
        loadPendingIfNeeded()
    }

    func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
        isLoading = false
        loadFailed = true
        // 一度でも受信済みなら、表示中の広告を失敗で畳まない。未受信のときだけ畳む。
        if !hasEverReceivedAd {
            isLoaded = false
        }
        print("[CoffeeVision] BannerAdLoader load failed (adUnitID=\(adUnitID)): \(error)")
        loadPendingIfNeeded()
    }
}
