import Foundation
import SharedLogic

/// Google Places Photo Media API から写真 URL を取得する薄いローダー。
///
/// 状態は持たない（URL を返すだけのファクトリクラス）。
/// `AppState` の `init` で組み立てて `placePhotoLoader` として公開する。
///
/// ## キャッシュ方針
///
/// Places 利用規約により Photo Media の永続キャッシュは禁止。
/// `URLSession` / `AsyncImage` 内部の標準 HTTP キャッシュ（メモリ + ディスク短期）のみ許容する。
/// `photoUri` JSON レスポンス自体も保持しない（毎表示時に Photo Media API を再叩き）。
@MainActor
final class PlacePhotoLoader {

    // `CafeRepository`（Kotlin interface）は Sendable 非準拠。`fetchUrl` から呼ぶだけの
    // 参照であり再代入もされないため `nonisolated(unsafe)` で個別に対処する
    // （ファイル全体を `@preconcurrency import` にする必要はない。SW6-5）。
    private nonisolated(unsafe) let repository: any CafeRepository

    init(repository: any CafeRepository) {
        self.repository = repository
    }

    /// `photoName` に対応する写真の表示用 URL を取得する。
    ///
    /// - Parameters:
    ///   - photoName: `Cafe.photoReferences` の要素（`"places/{placeId}/photos/{ref}"` 形式）
    ///   - maxWidthPx: 取得する写真の最大幅（px）
    /// - Returns: Google CDN の時限署名 URL
    /// - Throws: API 呼び出し失敗時、または返値が有効な URL でない場合
    func fetchUrl(photoName: String, maxWidthPx: Int) async throws -> URL {
        let urlString = try await repository.photoMediaUrl(
            photoName: photoName,
            maxWidthPx: KotlinInt(int: Int32(maxWidthPx)),
            maxHeightPx: nil
        )
        guard let url = URL(string: urlString) else {
            throw PlacePhotoLoaderError.invalidUrl(urlString)
        }
        return url
    }
}

// MARK: - Error

enum PlacePhotoLoaderError: LocalizedError {
    case invalidUrl(String)

    var errorDescription: String? {
        switch self {
        case .invalidUrl(let raw):
            return "Invalid photo URL: \(raw)"
        }
    }
}
