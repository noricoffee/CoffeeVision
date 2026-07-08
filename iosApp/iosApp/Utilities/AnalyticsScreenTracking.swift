import SwiftUI
import FirebaseAnalytics

/// SwiftUI 向けの画面表示イベント（`screen_view`）トラッキング。
///
/// UIKit の自動 screen tracking は SwiftUI の `View` 階層には効かないため、
/// 各画面のルート View に `.trackScreen("screen_name")` を明示的に付与する。
///
/// - `analyticsConsent` が false の間は `Analytics.setAnalyticsCollectionEnabled(false)`
///   により内部で収集が抑止されるため、呼び出し側で同意状態を分岐する必要はない
/// - 画面名は英語 snake_case で一貫させる（`AnalyticsParameterScreenName` /
///   `AnalyticsParameterScreenClass` に同じ値を渡す）
extension View {

    /// この View が表示されるたびに `screen_view` イベントを送信する。
    ///
    /// - Parameter name: 画面名（英語 snake_case）。`screen_name` / `screen_class` の両方に使う
    func trackScreen(_ name: String) -> some View {
        onAppear {
            Analytics.logEvent(AnalyticsEventScreenView, parameters: [
                AnalyticsParameterScreenName: name,
                AnalyticsParameterScreenClass: name
            ])
        }
    }
}
