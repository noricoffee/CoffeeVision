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
struct InlineBannerAdView: View {

    var loader: BannerAdLoader
    let maxHeight: CGFloat

    var body: some View {
        ZStack {
            if loader.isLoaded, let bannerView = loader.bannerView {
                BannerViewRepresentable(bannerView: bannerView)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: loader.isLoaded ? nil : 0)
        .background(
            GeometryReader { proxy in
                Color.clear
                    .task(id: proxy.size.width) {
                        guard proxy.size.width > 0 else { return }
                        loader.load(
                            adSize: inlineAdaptiveBanner(width: proxy.size.width, maxHeight: maxHeight)
                        )
                    }
            }
        )
    }
}
