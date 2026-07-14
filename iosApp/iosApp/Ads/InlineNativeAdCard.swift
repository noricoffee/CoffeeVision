import SwiftUI

/// カフェ詳細 / マップ検索ドロップダウンで使うインライン広告カード（requirements.md §11-1, §11-2）。
///
/// - 画面表示のたびに 1 回ロードする（自動リフレッシュなし）
/// - ロード中・失敗・オフライン時は高さ 0 の `EmptyView` に畳む（プレースホルダなし）
struct InlineNativeAdCard: View {

    let adUnitID: String

    @State private var loader: NativeAdLoader?

    var body: some View {
        // `Group { if let ... }` は未ロード時（子が EmptyView 相当）に `.task` の付け先が
        // 実体化されず発火しない不具合があったため、常に実体化される `ZStack` を root にする
        // （2026-07-14 実機診断で確認）。
        ZStack {
            if let nativeAd = loader?.nativeAd {
                NativeAdContainerView(nativeAd: nativeAd, layout: .card)
                    .frame(minHeight: 96)
            }
        }
        .task(id: adUnitID) {
            let loader = loader ?? NativeAdLoader(adUnitID: adUnitID)
            self.loader = loader
            loader.load()
        }
    }
}
