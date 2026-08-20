import FirebaseRemoteConfig

/// アプリ起動時に Firebase Remote Config の fetch + activate を 1 回だけ行う中立的な入口。
///
/// `RemoteConfig` はシングルトンのため、ここでの `fetchAndActivate()` は
/// `ApplePoiFilterConfig` / `ReviewPrompt` など**全キー**に等しく効く。
/// 個別機能側は取得済みの値を読むだけにし、fetch のトリガーはこの 1 箇所へ集約する
/// （依存関係が名前から追えず、機能を消したら他機能の Remote Config も止まる事故を防ぐため。
/// ASO-1 実装時に切り出し）。
enum RemoteConfigBootstrap {

    /// アプリ起動時に 1 回呼ぶ。Remote Config の最新値を fetch + activate する。
    ///
    /// 失敗しても無視する。各機能側は未取得時のフォールバック
    /// （bundled デフォルト / 既定 ON 等）で動作を保証する設計のため致命的ではない。
    static func fetchAndActivate() async {
        do {
            _ = try await RemoteConfig.remoteConfig().fetchAndActivate()
        } catch {
            print("[CoffeeVision] RemoteConfigBootstrap.fetchAndActivate failed (ignored): \(error)")
        }
    }
}
