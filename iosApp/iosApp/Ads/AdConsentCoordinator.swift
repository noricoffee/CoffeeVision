import AppTrackingTransparency
import UIKit
import UserMessagingPlatform

/// 広告プレプロンプト → UMP 同意更新 → ATT 許諾ダイアログ、を束ねるコーディネータ（requirements.md §11-4）。
///
/// - 呼び出し元（`AdPrePromptView` 経由）は既存のデータ利用同意オンボーディング直後の 1 回のみ `run()` を呼ぶ
/// - 配信地域は日本のみ確定のため UMP の同意フォームは通常表示されない。UMP SDK 自体は AdMob の
///   組み込み要件として導入し、`requestConsentInfoUpdate` → `loadAndPresentIfRequired` を毎セッション呼ぶ
///   （フォーム不要な地域では内部で no-op になる）
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
    /// ここでは UMP の同意更新と ATT 許諾ダイアログの表示のみを行う。
    static func run() async {
        await updateUMPConsentInfo()
        await requestATTAuthorizationIfNeeded()
    }

    // MARK: - UMP（配信地域は日本のみのためフォームは通常表示されない）

    private static func updateUMPConsentInfo() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            UMPConsentInformation.sharedInstance.requestConsentInfoUpdate(
                with: UMPRequestParameters()
            ) { _ in
                continuation.resume()
            }
        }

        // 日本配信のみのため通常は no-op（フォームが必要な地域のときだけ内部で表示される）。
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            UMPConsentForm.loadAndPresentIfRequired(from: nil) { _ in
                continuation.resume()
            }
        }
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
