import GoogleMobileAds
import SwiftUI

/// コーヒー記録タブ / 分析タブの下部固定アンカーアダプティブバナー（requirements.md §11-3）。
///
/// - タブバー直上に固定表示する共通コンポーネント。呼び出し側で `.safeAreaInset(edge: .bottom)` に載せる
/// - 呼び出し側が `loader`（`BannerAdLoader`）を所有する
/// - 画面表示（push / タブ遷移）のたびに 1 回ロードする（自動リフレッシュなし）
/// - ロード中・失敗・オフライン時は高さ 0 に畳む（プレースホルダなし）。FAB 等は
///   このビューが畳まれると自動的に元の位置へ戻る（呼び出し側のレイアウトに依存しない）
/// - 幅の実測には `.background(GeometryReader { ... })` を使う（`Color.clear` は常に実体化される
///   ため `.task` が確実に発火する。`Group { if let ... }` に付けると発火しないことがある。
///   2026-07-14 実機診断で確認）
struct AnchoredBannerAdView: View {

    var loader: BannerAdLoader

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
                        loader.load(adSize: largeAnchoredAdaptiveBanner(width: proxy.size.width))
                    }
            }
        )
    }
}
