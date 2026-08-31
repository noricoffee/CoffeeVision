import LinkPresentation
import SwiftUI
import UIKit

// MARK: - ActivityShareSheet

/// `UIActivityViewController` の SwiftUI ラッパー。
///
/// `ShareLink` は `RandomAccessCollection where Element: Transferable` しか渡せず、
/// 画像ファイル URL とキャプション文字列を同時に渡せないため（ASO-7②-a）、
/// 複数種類のアイテムを扱える `UIActivityViewController` を使う。
struct ActivityShareSheet: UIViewControllerRepresentable {

    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // 更新不要（アイテムは生成時に固定）
    }
}

// MARK: - ShareCardActivityItemSource

/// 共有カード画像を `UIActivityViewController` へ渡すためのアイテムソース。
///
/// `ShareLink` の `SharePreview` が担っていた「share sheet 上部のサムネイル + タイトル」表示を
/// `activityViewControllerLinkMetadata` で再現する。実体（ファイル URL）はそれ以外のメソッドで返す。
///
/// `nonisolated`: `UIActivityItemSource` は UIKit（share sheet のプロセス内処理）が任意のタイミング・
/// スレッドから呼び出す ObjC プロトコルで、Kotlin interface 実装クラスと同じ理由で MainActor に
/// 拘束しない。保持するのは `let` の値のみ（`UIImage` / `URL` / `String`）で可変状態を持たない。
nonisolated final class ShareCardActivityItemSource: NSObject, UIActivityItemSource {

    private let image: UIImage
    private let fileURL: URL
    private let previewTitle: String

    init(image: UIImage, fileURL: URL, previewTitle: String) {
        self.image = image
        self.fileURL = fileURL
        self.previewTitle = previewTitle
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        fileURL
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        fileURL
    }

    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = previewTitle
        metadata.imageProvider = NSItemProvider(object: image)
        return metadata
    }
}
