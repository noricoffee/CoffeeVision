import Foundation
import ImageIO
import UIKit

/// Documents 配下の `photos/` ディレクトリへのファイル I/O を司るユーティリティ。
///
/// ## 設計方針
///
/// - 公開 API は `fileName`（ファイル名のみ）を受け取る。絶対パスを呼び出し側に露出しない
/// - `localPath` のセマンティクス（`photos/{fileName}`）はここで内部的に組み立てる
/// - iOS の Documents URL は起動ごとに変わるため、DBには相対パスのみ保存し、
///   ファイルアクセス時は毎回 `photosDirectoryURL` から解決する
/// - 全関数 `static`。インスタンス不要
enum PhotoFileStore {

    // MARK: - Directory

    /// `<Documents>/photos/` ディレクトリの URL。
    static var photosDirectoryURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("photos", isDirectory: true)
    }

    /// `photos/` ディレクトリが存在しない場合に作成する。
    static func ensurePhotosDirectoryExists() throws {
        let url = photosDirectoryURL
        var isDir: ObjCBool = false
        if !FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) || !isDir.boolValue {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    // MARK: - CRUD

    /// `fileName` で指定したファイルを `photos/` ディレクトリに保存する。
    ///
    /// 既存ファイルは atomic write で上書きする。
    static func save(data: Data, fileName: String) throws {
        try ensurePhotosDirectoryExists()
        let fileURL = photosDirectoryURL.appendingPathComponent(fileName)
        try data.write(to: fileURL, options: .atomic)
    }

    /// `fileName` で指定したファイルを `UIImage` として読み込む。
    ///
    /// ファイルが存在しない / 読み込み失敗時は `nil` を返す。
    static func loadImage(fileName: String) -> UIImage? {
        let fileURL = photosDirectoryURL.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        return UIImage(contentsOfFile: fileURL.path)
    }

    // MARK: - サムネイル（一覧表示向け）

    /// 縮小デコード結果のメモリキャッシュ（キー: `"\(fileName)#\(maxPixelSize)"`）。
    ///
    /// `NSCache` はスレッドセーフなため、`loadThumbnail` から並行アクセスしても安全。
    private static let thumbnailCache = NSCache<NSString, UIImage>()

    /// `fileName` で指定したファイルを、`maxPixelSize`（長辺 px）へ縮小デコードして読み込む。
    ///
    /// 一覧行のような「多数のセルを同時にスクロールする」表示向け。`loadImage(fileName:)` の
    /// フルデコード（`UIImage(contentsOfFile:)`）と異なり `CGImageSourceCreateThumbnailAtIndex`
    /// でデコード時点から縮小するため、スクロール中に長辺 2048px の JPEG を毎行フルデコードする
    /// コストを避けられる（`ImageDownsampler` と同じ API・考え方。詳細は同ファイルのコメント）。
    ///
    /// - この関数は（`PhotoFileStore` 自体に actor / `@MainActor` 注釈が無いため）`nonisolated`。
    ///   `@MainActor` の呼び出し元から `await` すると、本体はメインスレッドを離れて実行される
    ///   （`Task.detached` 等を呼び出し側で明示する必要はない）
    /// - キャッシュヒット時は同期的に即返る
    /// - ファイルが存在しない・デコード失敗時は `nil`
    static func loadThumbnail(fileName: String, maxPixelSize: Int) async -> UIImage? {
        let cacheKey = "\(fileName)#\(maxPixelSize)" as NSString
        if let cached = thumbnailCache.object(forKey: cacheKey) {
            return cached
        }

        let fileURL = photosDirectoryURL.appendingPathComponent(fileName)
        guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil) else { return nil }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }

        let image = UIImage(cgImage: cgImage)
        thumbnailCache.setObject(image, forKey: cacheKey)
        return image
    }

    /// `fileName` で指定したファイルを削除する。
    ///
    /// ファイルが存在しない場合は no-op（エラーを throw しない）。
    static func delete(fileName: String) throws {
        let fileURL = photosDirectoryURL.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        try FileManager.default.removeItem(at: fileURL)
    }

    /// `photos/` ディレクトリ全体を削除する。
    ///
    /// アカウント削除時に端末ローカルの全写真を消去するために使う。
    /// ディレクトリが存在しない場合は no-op（エラーを throw しない）。
    static func deleteAllPhotos() throws {
        let url = photosDirectoryURL
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }
}
