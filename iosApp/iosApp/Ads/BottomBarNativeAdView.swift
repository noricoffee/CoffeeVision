import SwiftUI

/// コーヒー記録タブ / 分析タブの下部固定広告（requirements.md §11-3）。
///
/// - タブバー直上に固定表示する共通コンポーネント。呼び出し側で `.safeAreaInset(edge: .bottom)` に載せる
/// - 画面表示（push / タブ遷移）のたびに 1 回ロードする（自動リフレッシュなし）
/// - ロード中・失敗・オフライン時は高さ 0 に畳む（プレースホルダなし）。FAB 等は
///   このビューが畳まれると自動的に元の位置へ戻る（呼び出し側のレイアウトに依存しない）
struct BottomBarNativeAdView: View {

    let adUnitID: String

    @State private var loader: NativeAdLoader?

    var body: some View {
        Group {
            if let nativeAd = loader?.nativeAd {
                NativeAdContainerView(nativeAd: nativeAd, layout: .compact)
                    .frame(height: 64)
                    .background(.bar)
            }
        }
        .task(id: adUnitID) {
            let loader = loader ?? NativeAdLoader(adUnitID: adUnitID)
            self.loader = loader
            loader.load()
        }
    }
}
