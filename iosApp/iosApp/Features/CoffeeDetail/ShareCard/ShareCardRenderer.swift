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
    /// - `UIImage` の生成（`ImageRenderer.uiImage`）は `@MainActor` 必須だが、PNG エンコードと
    ///   ファイル書き込みは `writeToTemporaryFile` へ切り出し、メインスレッドから外す
    ///   （コードレビュー #6 指摘。エンコード自体は CPU バウンドで、共有シート表示の一拍に直結していた）
    @MainActor
    static func render(coffee: CoffeeRecord) async throws -> Result {
        let content = CoffeeShareCardView(coffee: coffee)
            .environment(\.colorScheme, .light)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 3

        guard let uiImage = renderer.uiImage else {
            throw RenderError.imageGenerationFailed
        }

        guard let url = await writeToTemporaryFile(uiImage) else {
            throw RenderError.imageGenerationFailed
        }

        return Result(image: uiImage, fileURL: url)
    }

    /// `image` を PNG エンコードし、一時ディレクトリへ書き出す。
    ///
    /// `@concurrent`: PNG エンコード（`pngData()`）は CPU バウンドな処理。既定 MainActor 分離下で
    /// `@concurrent` を付け忘れると診断なしに呼び出し元（MainActor）上で実行され続けてしまうため
    /// 明示する（`ImageDownsampler.downsampledJPEG` と同じ理由・同じ書き方）。
    @concurrent
    private static func writeToTemporaryFile(_ image: UIImage) async -> URL? {
        guard let data = image.pngData() else { return nil }

        let fileName = "coffeevision-share-\(UUID().uuidString).png"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}
