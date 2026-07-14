import GoogleMobileAds
import Observation

/// カフェ詳細 / マップ検索ドロップダウン / コーヒー記録・分析タブ下部固定の 4 面で共有する
/// ネイティブ広告ローダー（requirements.md §11）。
///
/// - 自動リフレッシュなし。呼び出し側（`InlineNativeAdCard` / `BottomBarNativeAdView`）が
///   画面表示（push / タブ遷移）のたびに `load()` を呼ぶ
/// - ロード失敗・オフライン時は `nativeAd` が nil のままになり、呼び出し側が枠ごと畳む
///   （プレースホルダなし）
/// - Places 由来のデータ（店名 / カテゴリ等）は広告リクエストに一切含めない
///   （Google Maps Platform 規約遵守。`makeRequest()` はキーワード・カスタムターゲティング
///   等を一切設定しない素のリクエストのみを組み立てる）
@MainActor
@Observable
final class NativeAdLoader: NSObject {

    private(set) var nativeAd: NativeAd?
    private(set) var isLoading = false
    private(set) var loadFailed = false

    private let adUnitID: String
    private var adLoader: AdLoader?

    init(adUnitID: String) {
        self.adUnitID = adUnitID
    }

    /// 画面表示のたびに呼ぶ。ロード中の再入は無視する（多重リクエスト防止）。
    func load() {
        guard !isLoading else { return }
        isLoading = true
        loadFailed = false

        let adLoader = AdLoader(
            adUnitID: adUnitID,
            rootViewController: RootViewControllerProvider.current,
            adTypes: [.native],
            options: nil
        )
        adLoader.delegate = self
        self.adLoader = adLoader
        adLoader.load(Self.makeRequest())
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

// MARK: - NativeAdLoaderDelegate

extension NativeAdLoader: NativeAdLoaderDelegate {
    func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
        nativeAd.rootViewController = RootViewControllerProvider.current
        self.nativeAd = nativeAd
        isLoading = false
        loadFailed = false
    }
}

// MARK: - AdLoaderDelegate

extension NativeAdLoader: AdLoaderDelegate {
    func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
        isLoading = false
        loadFailed = true
        print("[CoffeeVision] NativeAdLoader load failed (adUnitID=\(adUnitID)): \(error)")
    }
}
