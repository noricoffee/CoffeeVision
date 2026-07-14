import AppTrackingTransparency
import UIKit

/// 広告プレプロンプト → 直接 ATT 許諾ダイアログ、を束ねるコーディネータ（requirements.md §11-4）。
///
/// - 自前のプレプロンプト（`AdPrePromptView`）+ 直接の ATT 呼び出しが §11-4 の正である。
/// - **UMP（`UserMessagingPlatform`）の呼び出しは撤去済み**（2026-07-14）。
///   `requestConsentInfoUpdate` → `loadAndPresentIfRequired` を経由すると、AdMob コンソール側に
///   ATT メッセージ（IDFA 説明）が構成されている場合、**GDPR 圏外でも ATT が `.notDetermined` なら
///   UMP が `consentStatus` を `.required` 扱いにする**ため、`.required` ガードを付けても
///   コンソール構成（フォールバックの Google テスト用 App ID には ATT メッセージが構成済み）次第で
///   素通りしてしまい、自前のプレプロンプト + ATT の直後にさらに UMP 側の英語ダイアログが
///   二重表示される（2026-07-14 実機確認で 2 度目も再現）。「条件を狭めて呼ぶ」系のアプローチは
///   コンソール構成に挙動が依存し解決しないと判断し、UMP の呼び出し自体を撤去した。
///   日本のみ配信で GDPR フォームは不要なため実害はない。EU 配信を始める場合は GDPR フォーム実装として
///   UMP を再導入すること
/// - Google Mobile Ads SDK（SPM）の内部依存として UMP SDK のリンク自体は外れていない（コードから呼ばないだけ）
/// - `requestConsentInfoUpdate` を呼ばない構成のため `UMPConsentInformation.sharedInstance.canRequestAds`
///   は常に `false` になる。**このプロパティを広告ロードのゲートに使ってはいけない**
///   （`NativeAdLoader` / 呼び出し側は参照していない。今後も参照しないこと）
/// - ATT が「許可」以外（拒否 / 制限 / 未定）のときは非パーソナライズ広告（NPA）にフォールバックする。
///   各広告リクエストは `isPersonalizedAdsAllowed` を見て NPA extras を付与するかを判断する
///   （`NativeAdLoader.makeRequest()` 参照）
@MainActor
enum AdConsentCoordinator {

    /// 現在の ATT 許諾状態に基づき、パーソナライズ広告をリクエストしてよいか。
    static var isPersonalizedAdsAllowed: Bool {
        ATTrackingManager.trackingAuthorizationStatus == .authorized
    }

    /// データ利用同意オンボーディング（広告プレプロンプト）の直後に 1 回だけ呼ぶ。
    ///
    /// Google Mobile Ads SDK 自体の起動（`MobileAds.shared.start()`）はこのフローの完了を待たず
    /// アプリ起動時に行う（`iOSApp.init()` 参照。SDK 起動自体は同意の有無に依存しない）。
    /// ここでは ATT 許諾ダイアログの表示のみを行う（UMP は呼ばない。上記クラスコメント参照）。
    static func run() async {
        await requestATTAuthorizationIfNeeded()
    }

    // MARK: - ATT

    private static func requestATTAuthorizationIfNeeded() async {
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            ATTrackingManager.requestTrackingAuthorization { _ in
                continuation.resume()
            }
        }
    }
}

/// 広告のクリックスルー表示（App Store / Safari 遷移等）に必要な `rootViewController` を解決する。
///
/// Places 由来のデータは一切扱わないため規約上の懸念はない（表示先の解決のみ）。
enum RootViewControllerProvider {
    @MainActor
    static var current: UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: \.isKeyWindow)?
            .rootViewController
    }
}
