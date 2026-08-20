import Foundation

/// アプリ内から参照する法務・サポート系の外部リンク。
///
/// App Store ガイドライン 5.1.1(i) はプライバシーポリシーへのリンクを
/// App Store Connect のメタデータと「アプリ内のアクセスできる場所」の両方に
/// 置くことを要求している。オンボーディング（初回起動時のみ表示）と
/// 設定画面（常時アクセス可能）の両方から同じ URL を参照するため、ここに集約する。
///
/// URL の正本は `docs/app-store-metadata.md` §6.4。
enum LegalLinks {

    /// プライバシーポリシー（GitHub Pages で公開）。
    static let privacyPolicy = URL(string: "https://noricoffee.github.io/CoffeeVision/privacy-policy.html")!

    /// サポートページ（FAQ + 問い合わせ先、GitHub Pages で公開）。
    static let support = URL(string: "https://noricoffee.github.io/CoffeeVision/support.html")!
}
