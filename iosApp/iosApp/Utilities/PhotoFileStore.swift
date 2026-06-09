import Foundation
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

    /// `fileName` で指定したファイルを削除する。
    ///
    /// ファイルが存在しない場合は no-op（エラーを throw しない）。
    static func delete(fileName: String) throws {
        let fileURL = photosDirectoryURL.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        try FileManager.default.removeItem(at: fileURL)
    }
}
