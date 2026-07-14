import GoogleMobileAds
import Observation

/// カフェ詳細 / マップ検索ドロップダウン / コーヒー記録・分析タブ下部固定の 4 面で共有する
/// アダプティブバナー広告ローダー（requirements.md §11）。
///
/// - 自動リフレッシュなし。呼び出し側（`InlineBannerAdView` / `AnchoredBannerAdView`）が
///   画面表示（push / タブ遷移）のたびに `load(adSize:)` を呼ぶ
/// - ロード失敗・オフライン時は `isLoaded` が `false` のままになり、呼び出し側が枠ごと畳む
///   （プレースホルダなし）
/// - Places 由来のデータ（店名 / カテゴリ等）は広告リクエストに一切含めない
///   （Google Maps Platform 規約遵守。`makeRequest()` はキーワード・カスタムターゲティング
///   等を一切設定しない素のリクエストのみを組み立てる）
/// - ロードトリガーは呼び出し側で常に実体化されるビュー（`ZStack` / `Color.clear` 等）に
///   `.task` を付けて呼ぶこと。`Group { if let ... }` に付けると条件が偽の初回描画時に
///   `.task` の付け先が実体化されず発火しないことがある（2026-07-14 実機診断で確認）。
@MainActor
@Observable
final class BannerAdLoader: NSObject {

    private(set) var bannerView: BannerView?
    private(set) var isLoading = false
    private(set) var isLoaded = false
    private(set) var loadFailed = false

    private let adUnitID: String

    init(adUnitID: String) {
        self.adUnitID = adUnitID
    }

    /// 画面表示のたびに呼ぶ。ロード中の再入は無視する（多重リクエスト防止）。
    /// 初回は `adSize` で `BannerView` を生成し、2 回目以降は既存のビューを使い回して再ロードする。
    func load(adSize: AdSize) {
        guard !isLoading else { return }
        isLoading = true
        loadFailed = false

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
    }

    func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
        isLoading = false
        isLoaded = false
        loadFailed = true
        print("[CoffeeVision] BannerAdLoader load failed (adUnitID=\(adUnitID)): \(error)")
    }
}
