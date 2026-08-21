import SwiftUI
import UIKit

/// 現在の画面が乗っている `UINavigationController` のエッジスワイプで戻るジェスチャー
/// (`interactivePopGestureRecognizer`) を一時的に無効化するための透明な補助 View。
///
/// SwiftUI の `.navigationBarBackButtonHidden(_:)` は戻るボタンの表示のみを制御し、
/// エッジスワイプでの戻る操作までは止められない。処理中は「戻る」の全経路
/// （ボタン / スワイプ）を封じたい画面（例: `AccountView` のサインアウト /
/// アカウント削除処理中）で `.background(InteractivePopGestureLock(isLocked:))` として使う。
///
/// 実体を持たない `UIViewController` を SwiftUI 階層に挿入し、その `navigationController` を
/// 辿って `interactivePopGestureRecognizer.isEnabled` を切り替える。画面を離れるとき
/// （`viewWillDisappear`）は必ず解除し、他の画面のスワイプ操作を巻き込まないようにする。
struct InteractivePopGestureLock: UIViewControllerRepresentable {

    /// `true` のときスワイプで戻る操作を無効化する。
    let isLocked: Bool

    func makeUIViewController(context: Context) -> LockingViewController {
        LockingViewController()
    }

    func updateUIViewController(_ uiViewController: LockingViewController, context: Context) {
        uiViewController.isLocked = isLocked
    }

    /// 画面には何も描画しない、ロック制御専用のホスト `UIViewController`。
    final class LockingViewController: UIViewController {

        var isLocked = false {
            didSet { applyLock() }
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            // `makeUIViewController` 時点では `navigationController` が未確定のことがあるため、
            // 表示確定時にも改めて反映する。
            applyLock()
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            // 画面を離れるときは常に解除する（次にこの `UINavigationController` に積まれる
            // 別画面のスワイプ操作を巻き込まないため）。
            navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        }

        private func applyLock() {
            navigationController?.interactivePopGestureRecognizer?.isEnabled = !isLocked
        }
    }
}
