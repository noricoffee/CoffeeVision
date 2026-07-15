import GoogleMobileAds
import SwiftUI

/// コーヒー記録タブ（上部固定）/ 分析タブ（下部固定）で使うアンカーアダプティブバナー
/// （requirements.md §11-3）。
///
/// - 呼び出し側で `.safeAreaInset(edge: .top)` または `.safeAreaInset(edge: .bottom)` に載せる、
///   上下どちらの固定枠にも使える汎用コンポーネント。コーヒー記録タブは FAB との近接誤タップ懸念
///   （AdMob ポリシーリスク）+ タブバー / 広告 / FAB の下部 3 段渋滞を解消するため上部固定、
///   分析タブは FAB が無いため引き続き下部固定（2026-07-15）
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
struct AnchoredBannerAdView: View {

    var loader: BannerAdLoader

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
                        loader.load(adSize: largeAnchoredAdaptiveBanner(width: proxy.size.width))
                    }
            }
        )
    }
}
