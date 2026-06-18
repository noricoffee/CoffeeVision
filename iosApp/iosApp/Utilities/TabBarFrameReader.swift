import SwiftUI
import UIKit

/// タブバー内の検索タブ（`Tab(role: .search)`）の global フレームを読み取る `UIViewRepresentable`。
///
/// ## 設計方針
/// - private API 名（`UITabBarButtonLabel` 等）には直接依存しない
/// - 幾何条件でタブアイテムサブビューを絞り込む:
///   1. ほぼ正方形（width と height の差が 4pt 未満）
///   2. タブバー幅の半分未満（他タブとの区別ではなく、検索 FAB の "補助ビュー" を探すための条件）
///   3. クラス名に `"Auxiliary"` または `"Search"` を含むものを優先
/// - `layoutSubviews` / `didMoveToWindow` のたびに再報告し、回転・レイアウト変化に追従する
/// - `lastFrame` と比較して変化があった場合のみコールバックを呼ぶ（不要な再描画を防ぐ）
///
/// ## 使い方
/// ```swift
/// .background(
///     TabBarFrameReader { frame in
///         tabBarSearchFrame = frame
///     }
/// )
/// ```
struct TabBarFrameReader: UIViewRepresentable {

    /// 検索タブの global フレームが確定・変化するたびに呼ばれるコールバック。
    var onFrameChanged: (CGRect) -> Void

    func makeUIView(context: Context) -> FrameReaderView {
        let view = FrameReaderView()
        view.onFrameChanged = onFrameChanged
        return view
    }

    func updateUIView(_ uiView: FrameReaderView, context: Context) {
        uiView.onFrameChanged = onFrameChanged
    }

    // MARK: - FrameReaderView

    final class FrameReaderView: UIView {

        var onFrameChanged: ((CGRect) -> Void)?
        private var lastFrame: CGRect = .zero

        // MARK: - ライフサイクル

        override func didMoveToWindow() {
            super.didMoveToWindow()
            reportSearchTabFrame()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            reportSearchTabFrame()
        }

        // MARK: - フレーム取得

        private func reportSearchTabFrame() {
            guard let tabBar = findTabBar() else { return }
            guard let frame = searchTabFrame(in: tabBar) else { return }
            guard frame != lastFrame else { return }
            lastFrame = frame
            // SwiftUI の状態更新は Main スレッドで行う
            DispatchQueue.main.async { [weak self] in
                self?.onFrameChanged?(frame)
            }
        }

        // MARK: - UITabBar 探索

        /// (1) responder chain を遡る → (2) windowScene.windows の rootViewController 階層を再帰探索
        private func findTabBar() -> UITabBar? {
            // (1) responder chain
            var responder: UIResponder? = self
            while let r = responder {
                if let tabBarController = r as? UITabBarController {
                    return tabBarController.tabBar
                }
                responder = r.next
            }

            // (2) windowScene.windows の rootViewController を再帰探索
            let scenes = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
            for scene in scenes {
                for window in scene.windows {
                    if let tabBar = findTabBar(in: window.rootViewController) {
                        return tabBar
                    }
                }
            }
            return nil
        }

        private func findTabBar(in viewController: UIViewController?) -> UITabBar? {
            guard let vc = viewController else { return nil }
            if let tabBarController = vc as? UITabBarController {
                return tabBarController.tabBar
            }
            for child in vc.children {
                if let found = findTabBar(in: child) {
                    return found
                }
            }
            if let presented = vc.presentedViewController {
                if let found = findTabBar(in: presented) {
                    return found
                }
            }
            return nil
        }

        // MARK: - 検索タブフレーム特定

        /// タブバーの subviews から検索タブ aux view を幾何条件で絞り込み、global 座標を返す。
        private func searchTabFrame(in tabBar: UITabBar) -> CGRect? {
            let tabBarWidth = tabBar.bounds.width
            guard tabBarWidth > 0 else { return nil }

            // 幾何条件: ほぼ正方形 かつ タブバー幅の半分未満
            let candidates = tabBar.subviews.filter { sub in
                let w = sub.frame.width
                let h = sub.frame.height
                guard w > 0, h > 0 else { return false }
                let isSquarish = abs(w - h) < 4
                let isNarrow = w < tabBarWidth * 0.5
                return isSquarish && isNarrow
            }

            guard !candidates.isEmpty else { return nil }

            // クラス名に "Auxiliary" または "Search" を含むものを優先
            let preferred = candidates.first { sub in
                let name = String(describing: type(of: sub))
                return name.contains("Auxiliary") || name.contains("Search")
            }
            let target = preferred ?? candidates.last

            guard let sub = target else { return nil }
            // global 座標（window 基準）へ変換
            let globalFrame = sub.convert(sub.bounds, to: nil)
            guard globalFrame != .zero else { return nil }
            return globalFrame
        }
    }
}
