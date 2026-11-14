import Foundation
import os

/// アプリ全体で使う `os.Logger` のファクトリ（SL-8）。
///
/// `print` は Release ビルドでも stdout へ出るため、uid のような個人に紐づく値が端末の
/// コンソールに残る。`os.Logger` は**文字列補間を既定で `private` として伏せる**ので、
/// `#if DEBUG` を書かずに本番でのログ漏れを防げる（公開してよい定型文だけ
/// `privacy: .public` を明示する）。
///
/// - `subsystem` はここで一元化し、呼び出し側は `category` だけを指定する。
/// - `nonisolated` 指定は `FirebaseRepositories/` 配下の `nonisolated final class`
///   （Kotlin ランタイムが任意スレッドから呼ぶ実装）からも使うため。
///   `Logger` は `Sendable` なので、格納プロパティに持たせても `Sendable` 適合は壊れない。
nonisolated enum AppLog {

    /// ロガーの subsystem。`Bundle.main` から取れないケース（テスト等）だけ固定値へフォールバックする。
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.noricoffee.coffeevision"

    /// 指定カテゴリのロガーを返す。
    ///
    /// - Parameter category: Console.app / `log stream` での絞り込み単位（画面名・機能名）。
    static func logger(category: String) -> Logger {
        Logger(subsystem: subsystem, category: category)
    }
}
