import SwiftUI

/// カフェ詳細 / マップ検索ドロップダウンで使うインライン広告カード（requirements.md §11-1, §11-2）。
///
/// - 画面表示のたびに 1 回ロードする（自動リフレッシュなし）
/// - ロード中・失敗・オフライン時は高さ 0 の `EmptyView` に畳む（プレースホルダなし）
struct InlineNativeAdCard: View {

    let adUnitID: String

    @State private var loader: NativeAdLoader?

    var body: some View {
        Group {
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
