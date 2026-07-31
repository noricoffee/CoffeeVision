import FirebaseCrashlytics
import FirebaseRemoteConfig
import StoreKit
import UIKit

/// 分析タブで傾向信号が初めて出た瞬間に App Store のレビュー依頼ダイアログを 1 回だけ提示する
/// （requirements.md 9-8 / ASO-1）。
///
/// ## ゲート（上から順に評価。1 つでも外れたら何もしない）
///
/// 1. Remote Config `review_prompt_enabled`（Bool、キルスイッチ）。未取得・未設定のときは
///    出荷時 ON として扱う（詳細は `isEnabledByRemoteConfig` 参照）
/// 2. マイルストーンフラグ未設定（`UserDefaults`。`AppState.adConsentFlowShownKey` と同じ運用）
/// 3. 前回起動でクラッシュしていない（`Crashlytics.crashlytics().didCrashDuringPreviousExecution()`）。
///    Crashlytics は `iOSApp.swift` で常時有効化済みのため追加導入は不要
/// 4. 約 1.5 秒の遅延（タブを開いた直後にダイアログが被さると何を評価するのか分からないため）
/// 5. `UIWindowScene` を解決して `AppStore.requestReview(in:)`
///
/// ## フラグを立てるタイミング
///
/// `requestReview(in:)` は実際にダイアログが表示されたかを返さない（Apple 側の年 3 回上限や
/// OS 設定で出ないことがある）ため、成功可否では分岐できない。**提示を試みた時点**
/// （= ゲート 1〜3 を通過し `UIWindowScene` の解決にも成功した時点）でフラグを立てて確定させる。
enum ReviewPrompt {

    private static let remoteConfigKey = "review_prompt_enabled"
    private static let milestoneShownKey = "hasRequestedReviewAtFirstSignal"
    private static let presentationDelayNanoseconds: UInt64 = 1_500_000_000

    /// 分析タブで傾向信号（`readiness.hasAnySignal`）が初めて `true` になったときに呼ぶ。
    ///
    /// マイルストーンフラグがあるため、2 回目以降の呼び出しは（`.task` / `.onChange` の両方から
    /// 呼ばれても）即座に no-op で返る。
    ///
    /// ## 呼び出し元による遅延中キャンセルの扱いの違い（既知の制約）
    ///
    /// `AnalysisView` の `.task` 経由の呼び出しはビューのライフサイクルに紐づく構造化タスクのため、
    /// 1.5 秒の遅延中にユーザーが分析タブを離れると `Task.isCancelled` で検知して抑止できる。
    /// 一方 `.onChange` 経由の呼び出しは `Task { }` で起こす非構造化タスクのため、遅延中にタブを
    /// 離れてもキャンセルされず、遅延後に「今どのタブが前面か」を `ReviewPrompt` 側から知る手段が
    /// ないため、他タブの上にダイアログが出うる。提示は端末あたり 1 回きりのため影響は限定的だが、
    /// 解消するには呼び出し元を `.task(id:)` へ作り替える必要がある（未対応）。
    @MainActor
    static func requestIfFirstSignalReached() async {
        guard isEnabledByRemoteConfig else { return }
        guard !UserDefaults.standard.bool(forKey: milestoneShownKey) else { return }
        guard !Crashlytics.crashlytics().didCrashDuringPreviousExecution() else { return }

        try? await Task.sleep(nanoseconds: presentationDelayNanoseconds)
        // `try?` はキャンセル時に nil を返すだけで実行が次行へ進んでしまうため、
        // 明示的にキャンセルを確認してから続ける（下記クラスコメントの制約も参照）。
        guard !Task.isCancelled else { return }

        guard let scene = activeWindowScene else { return }

        // 「提示を試みた時点」で確定させる。requestReview(in:) は実際にダイアログが
        // 出たかを返さないため、成功可否では分岐しない（クラスコメント参照）。
        UserDefaults.standard.set(true, forKey: milestoneShownKey)
        AppStore.requestReview(in: scene)
    }

    // MARK: - Private

    /// Remote Config `review_prompt_enabled` の実効値。
    ///
    /// `FIRRemoteConfigValue` はキーが存在しない場合でも non-optional な `boolValue`
    /// （型の静的既定値である `false`）を返すため、`boolValue` だけを見ると「未設定」と
    /// 「明示的に false」を区別できない（`ApplePoiFilterConfig.excludedNameKeywords` が文字列キーの
    /// 空文字既定値で直面したのと同型の罠）。区別には `FIRRemoteConfigValue.source` を使う。
    /// `source == .static` は「remote にも in-app defaults にも値が存在しない」ことを意味する
    /// （Firebase SDK `FIRRemoteConfig.h` の `FIRRemoteConfigSourceStatic` コメント:
    /// "The data doesn't exist, return a static initialized value."）。このときだけ
    /// `true`（出荷時 ON）を返す。コンソールで明示的に `false` を配信すればキルスイッチとして効く。
    private static var isEnabledByRemoteConfig: Bool {
        let value = RemoteConfig.remoteConfig().configValue(forKey: remoteConfigKey)
        guard value.source != .static else { return true }
        return value.boolValue
    }

    /// レビュー依頼ダイアログの表示先となる、フォアグラウンドでアクティブな `UIWindowScene` を解決する。
    ///
    /// `RootViewControllerProvider`（`Ads/AdConsentCoordinator.swift`）は `UIViewController` を
    /// 返す形のため流用できず、ここで `connectedScenes` から直接解決する。
    @MainActor
    private static var activeWindowScene: UIWindowScene? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive })
    }
}
