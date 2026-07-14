import AppTrackingTransparency
import UIKit
import UserMessagingPlatform

/// 広告プレプロンプト → UMP 同意更新 → ATT 許諾ダイアログ、を束ねるコーディネータ（requirements.md §11-4）。
///
/// - 自前のプレプロンプト（`AdPrePromptView`）+ 直接の ATT 呼び出しが §11-4 の正である。
///   UMP 側が提示する同意メッセージ UI はここでは使わない
/// - 呼び出し元（`AdPrePromptView` 経由）は既存のデータ利用同意オンボーディング直後の 1 回のみ `run()` を呼ぶ
/// - 配信地域は日本のみ確定のため、通常は `consentStatus` が `.required` にならず UMP フォームは表示されない。
///   ただし **`loadAndPresentIfRequired` を無条件に呼ぶと、AdMob コンソール側にメッセージが構成されている
///   場合（フォールバックの Google テスト用 App ID には "Our App wants to stay free…" という
///   IDFA 説明メッセージが構成済み）に、自前のプレプロンプト + ATT の直後へさらに UMP 側の英語ダイアログが
///   二重表示されてしまう**（2026-07-14 実機確認で発覚）。そのため `consentStatus == .required`
///   のときだけフォームを提示するようガードする（日本配信では該当しないため実質 no-op のまま維持され、
///   将来 EU 配信するときは GDPR フォームだけがこの分岐を通る）
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

        // `loadAndPresentIfRequired` を無条件に呼ぶと、AdMob コンソール側に構成されたメッセージ
        // （フォールバックの Google テスト用 App ID には IDFA 説明メッセージが構成済み）が
        // 自前のプレプロンプト + ATT の直後に二重表示されてしまう。日本配信では通常 `.required`
        // にならないため、明示的にガードして無条件呼び出しを避ける。
        guard UMPConsentInformation.sharedInstance.consentStatus == .required else { return }
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
