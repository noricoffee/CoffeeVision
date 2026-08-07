import Foundation
// `@preconcurrency`: Kotlin の suspend 関数は ObjC の completion-handler メソッドとして export され、
// Swift 側では `@concurrent` な async として import される。MainActor 上から非 Sendable な
// `any CafeRepository` を受け手にして await すると、受け手を別の分離ドメインへ「送る」ことになり
// data race エラーになる（リリース CI run 31203044578）。
@preconcurrency import SharedLogic

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
    // 参照であり再代入もされないため `nonisolated(unsafe)` を付ける。
    //
    // SW6-5 では「これで足りる（ファイル全体を `@preconcurrency import` にする必要はない）」と
    // 結論したが、それは Xcode 27 beta 上での検証だった。リリース用の Xcode 26.6 では
    // `nonisolated(unsafe)` だけでは 34 行目の await が通らないため `@preconcurrency import` を併用する。
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
