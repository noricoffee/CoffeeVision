import GoogleMobileAds
import SwiftUI

/// `BannerView`（UIKit）を SwiftUI に橋渡しする薄いラッパー。
///
/// サイズは `BannerView` 自身の `intrinsicContentSize`（ロードされた広告の実サイズ）に委ねる。
/// 明示的な `.frame()` は付けない（呼び出し側で必要ならレイアウトのみ調整する）。
struct BannerViewRepresentable: UIViewRepresentable {

    let bannerView: BannerView

    func makeUIView(context: Context) -> BannerView {
        bannerView
    }

    func updateUIView(_ uiView: BannerView, context: Context) {
        // 表示内容は BannerAdLoader が管理する（ここでは何もしない）。
    }
}
