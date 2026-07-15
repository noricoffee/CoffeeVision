import GoogleMobileAds
import SwiftUI

/// 分析タブの下部固定アンカーアダプティブバナー（requirements.md §11-3）。
///
/// - 呼び出し側で `.safeAreaInset(edge: .top)` または `.safeAreaInset(edge: .bottom)` に載せる、
///   上下どちらの固定枠にも使える汎用コンポーネント（現状は分析タブの下部固定のみで使用）。
///   コーヒー記録タブは当初この上部固定を使っていたが、スクロールしても消えず画面を占有する
///   ことへのユーザー要望を受け、`CoffeeListView` はリスト先頭のインライン配置
///   （`CoffeeListView.adSection`、`InlineBannerAdView` は使わず同等の自前実装）に変更済み
///   （2026-07-15）。分析タブは通常スクロールコンテンツの下に固定枠を置きたい用途のため、
///   引き続きこのコンポーネントを使う
/// - 呼び出し側が `loader`（`BannerAdLoader`）を所有する
/// - 画面表示（push / タブ遷移）のたびに 1 回ロードする（自動リフレッシュなし）
/// - ロード中・失敗・オフライン時は高さ 0 に畳む（プレースホルダなし）。FAB 等は
///   このビューが畳まれると自動的に元の位置へ戻る（呼び出し側のレイアウトに依存しない）
/// - 幅の実測には `.background(GeometryReader { ... })` を使う（`Color.clear` は常に実体化される
///   ため `.task` が確実に発火する。`Group { if let ... }` に付けると発火しないことがある。
///   2026-07-14 実機診断で確認）
/// - `BannerViewRepresentable` には受信済みサイズ（`loader.loadedAdSize`）で明示 `.frame(width:height:)`
///   を与える（公式 SwiftUI サンプル `BannerContentView.swift` と同じ構成）。サイズを明示しないと
///   SwiftUI がレイアウト中に異なる frame を与えてしまい、SDK 側のサイズ検証で
///   "Invalid ad width or height" が発生し受信済み広告が無効化されることがある
///   （2026-07-14 実機診断で確認）。外側の `.frame(maxWidth: .infinity)` はスロット全体の
///   センタリング用で、representable 自体は伸縮させない。
/// - サイズは `inlineAdaptiveBanner(width:maxHeight:)`（`Self.maxHeight = 90`）で計算する。
///   2026-07-15: 当初は `largeAnchoredAdaptiveBanner(width:)` を使っていたが、実測で高さが
///   126pt 程度まで育ち圧迫感があったため標準的な高さ（〜90pt）に抑える方針に変更した。
///   **GADAdSize.h（v13.6.0）を実際に確認したところ、非 Large のアンカーアダプティブ関数
///   （`portraitAnchoredAdaptiveBanner` / `landscapeAnchoredAdaptiveBanner` /
///   `currentOrientationAnchoredAdaptiveBanner`）は全て非推奨で、代替として案内されているのは
///   `largeAnchoredAdaptiveBanner` のみだった**（アンカー系に「非推奨でない標準版」は存在しない）。
///   非推奨 API を使わずに高さを確実に抑える手段として、`inlineAdaptiveBanner(width:maxHeight:)`
///   （非推奨ではない）を採用した。幅は実測値のまま渡すため画面幅適応は維持され、固定 320×50
///   バナーへは落とさない。`maxHeight = 90` は非推奨版の標準アンカーアダプティブが返していた
///   高さレンジ（50〜90pt）の上限に合わせた値
struct AnchoredBannerAdView: View {

    var loader: BannerAdLoader

    /// バナー高さの上限。非推奨の「標準」アンカーアダプティブバナーが返していた高さレンジ
    /// （50〜90pt）の上限に合わせている（上記クラスコメント参照）。
    private static let maxHeight: CGFloat = 90

    var body: some View {
        ZStack {
            if loader.isLoaded, let bannerView = loader.bannerView, let loadedAdSize = loader.loadedAdSize {
                BannerViewRepresentable(bannerView: bannerView)
                    .frame(width: loadedAdSize.width, height: loadedAdSize.height)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: (loader.isLoaded && loader.loadedAdSize != nil) ? nil : 0)
        .background(
            GeometryReader { proxy in
                Color.clear
                    .task(id: proxy.size.width) {
                        // レイアウト測定の過渡状態（ゴミ幅）でリクエストしない
                        // （`BannerAdLoader.minimumRequestableWidth` 参照。2026-07-14 実機診断で確認）。
                        guard proxy.size.width >= BannerAdLoader.minimumRequestableWidth else { return }
                        loader.load(
                            adSize: inlineAdaptiveBanner(width: proxy.size.width, maxHeight: Self.maxHeight)
                        )
                    }
            }
        )
    }
}
