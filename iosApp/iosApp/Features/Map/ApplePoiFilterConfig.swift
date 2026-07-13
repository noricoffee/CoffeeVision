import Foundation
import FirebaseRemoteConfig

/// Apple `.cafe` POI の名前ヒューリスティック除外キーワードを Firebase Remote Config から配信するプロバイダ
/// （名前フィルタの Remote Config 外部注入、2026-07-13）。
///
/// ## 設計方針
///
/// - Remote Config キー `map_poi_excluded_name_keywords`（JSON 文字列配列）を取得・parse する
/// - **parse に成功したら bundled デフォルトを完全に置き換える**（和集合ではない —
///   Firebase コンソールの見た目と実挙動を一致させるため。空配列で配信すればフィルタを
///   実質無効化できる）
/// - remote 未取得（初回起動・オフライン含む）/ 空文字 / parse 失敗のときは bundled デフォルトに
///   フォールバックする。つまりコンソールにパラメータが存在しなくても現行挙動と完全同一
/// - fetch は起動時に 1 回（`fetchAndActivate()`）。`minimumFetchInterval` は SDK 既定（12h）のまま
enum ApplePoiFilterConfig {

    private static let remoteConfigKey = "map_poi_excluded_name_keywords"

    /// Apple `.cafe` 誤分類の非カフェ（法人本社 / レンタルスペース / コンカフェ等）を
    /// 名前の部分一致で除外する bundled デフォルトキーワード一覧。
    ///
    /// 除外理由: Apple 地図データの `.cafe` カテゴリには稀にこれらが誤分類され、
    /// タップしても Google Places 側で解決できず「該当なし」になるため事前に弾く。
    private static let defaultExcludedNameKeywords: Set<String> = [
        "株式会社", "(株)", "（株）", "有限会社", "合同会社",
        "本社", "事務所", "オフィス", "レンタルスペース", "貸会議室", "貸スペース",
        "コワーキング", "シェアオフィス", "コンカフェ", "コンセプトカフェ", "ガールズバー",
    ]

    /// 現在有効な除外キーワード一覧。
    ///
    /// Remote Config の値を JSON decode できたときはその内容（空配列も含む）をそのまま返し、
    /// 未取得・空文字・parse 失敗のときは `defaultExcludedNameKeywords` を返す。
    static var excludedNameKeywords: Set<String> {
        // 未取得のキーは stringValue が空文字を返す（FIRRemoteConfigValue は non-optional）。
        let rawValue = RemoteConfig.remoteConfig().configValue(forKey: remoteConfigKey).stringValue
        guard !rawValue.isEmpty,
              let data = rawValue.data(using: .utf8),
              let keywords = try? JSONDecoder().decode([String].self, from: data) else {
            return defaultExcludedNameKeywords
        }
        return Set(keywords)
    }

    /// アプリ起動時に 1 回呼ぶ。Remote Config の最新値を fetch + activate する。
    ///
    /// 失敗しても無視する（bundled デフォルトへフォールバックする設計のため致命的ではない）。
    static func fetchAndActivate() async {
        do {
            _ = try await RemoteConfig.remoteConfig().fetchAndActivate()
        } catch {
            print("[CoffeeVision] ApplePoiFilterConfig.fetchAndActivate failed (ignored): \(error)")
        }
    }
}
