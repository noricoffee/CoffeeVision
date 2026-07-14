import GoogleMobileAds
import SwiftUI

/// マップ検索ドロップダウンで使うインラインアダプティブバナー（requirements.md §11-2）。
///
/// - 呼び出し側が `loader`（`BannerAdLoader`）を所有する。この View は自身の実測幅から
///   `inlineAdaptiveBanner(width:maxHeight:)` のサイズを計算してロードをトリガーするだけで、
///   ロード状態そのものは持たない
/// - 幅の実測には `.background(GeometryReader { ... })` を使う（`Color.clear` は常に実体化される
///   ため `.task` が確実に発火する。`Group { if let ... }` に付けると発火しないことがある。
///   2026-07-14 実機診断で確認）
/// - ロード中・失敗・オフライン時は高さ 0 に畳む（プレースホルダなし）
/// - `BannerViewRepresentable` には受信済みサイズ（`loader.loadedAdSize`）で明示 `.frame(width:height:)`
///   を与える（公式 SwiftUI サンプル `BannerContentView.swift` と同じ構成）。サイズを明示しないと
///   SwiftUI がレイアウト中に異なる frame を与えてしまい、SDK 側のサイズ検証で
///   "Invalid ad width or height" が発生し受信済み広告が無効化されることがある
///   （2026-07-14 実機診断で確認）。外側の `.frame(maxWidth: .infinity)` はスロット全体の
///   センタリング用で、representable 自体は伸縮させない。
struct InlineBannerAdView: View {

    var loader: BannerAdLoader
    let maxHeight: CGFloat

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
                            adSize: inlineAdaptiveBanner(width: proxy.size.width, maxHeight: maxHeight)
                        )
                    }
            }
        )
    }
}
