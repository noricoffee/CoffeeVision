import SwiftUI

/// アプリ表示テーマの選択肢。
///
/// `@AppStorage("appAppearance")` の値として `rawValue`（String）を永続化する。
/// `AppRootView` で `preferredColorScheme` に変換して適用する。
enum AppAppearance: String, CaseIterable {
    case system
    case light
    case dark

    /// SwiftUI の `preferredColorScheme` に渡す値。
    /// `system` の場合は `nil`（OS 設定に追従）。
    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    /// 設定画面の `Picker` ラベルに表示する文字列。
    var displayName: String {
        switch self {
        case .system:
            return String(localized: "システム")
        case .light:
            return String(localized: "ライト")
        case .dark:
            return String(localized: "ダーク")
        }
    }
}
