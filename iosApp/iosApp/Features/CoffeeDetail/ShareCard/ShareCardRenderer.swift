import SwiftUI
import UIKit
import SharedLogic

// MARK: - ShareCardRenderer

/// `CoffeeShareCardView` を PNG 画像としてレンダリングし、一時ファイルへ書き出すユーティリティ。
///
/// `ImageRenderer` は `@MainActor` 拘束のため、レンダリング関数も `@MainActor` にする。
enum ShareCardRenderer {

    enum RenderError: Error {
        case imageGenerationFailed
    }

    /// レンダリング結果。プレビュー表示用の `UIImage` と share sheet 用の一時ファイル URL の両方を返す。
    struct Result {
        let image: UIImage
        let fileURL: URL
    }

    /// カードをレンダリングして PNG を一時ディレクトリへ書き出す。
    ///
    /// - ライトテーマ固定（`.environment(\.colorScheme, .light)`。端末のダーク設定に依存させない）
    /// - 出力解像度は `scale = 3` を掛けた 1080×1350px（4:5、`docs/requirements.md` §2 2-12）
    @MainActor
    static func render(coffee: CoffeeRecord) throws -> Result {
        let content = CoffeeShareCardView(coffee: coffee)
            .environment(\.colorScheme, .light)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 3

        guard let uiImage = renderer.uiImage, let data = uiImage.pngData() else {
            throw RenderError.imageGenerationFailed
        }

        let fileName = "coffeevision-share-\(UUID().uuidString).png"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try data.write(to: url, options: .atomic)

        return Result(image: uiImage, fileURL: url)
    }
}
