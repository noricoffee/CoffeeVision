import Foundation
import ImageIO
import UIKit

/// PhotosPicker から取得した画像データを保存用にダウンサンプリング + JPEG 変換するユーティリティ。
///
/// ## 設計方針
///
/// - `UIImage(data:)` によるフルデコードを避け、`CGImageSourceCreateThumbnailAtIndex` を使う。
///   これはデコード時点で `maxPixelSize` へ縮小するため、48MP 級の元画像でもピークメモリが
///   フルデコード（約190MB）まで乗らない
/// - このアプリで写真を最大解像度で使う箇所は共有カード書き出し（1080×1350px）のみで、
///   長辺 2048px あれば全用途を満たす（詳細は `docs/data-model.md` §1.4 Photo）
/// - 全関数 `static`。インスタンス不要（`PhotoFileStore` と同じ書き方）
enum ImageDownsampler {

    // MARK: - 定数

    /// 保存時の長辺上限（px）。
    static let maxPixelSize = 2048

    /// JPEG 圧縮品質。
    static let jpegQuality: CGFloat = 0.8

    // MARK: - ダウンサンプリング

    /// `data`（元画像）を `maxPixelSize` へダウンサンプリングし、JPEG に変換する。
    ///
    /// - `maxPixelSize` は長辺の上限。元画像の長辺がこれ以下の場合は
    ///   `CGImageSourceCreateThumbnailAtIndex` が**拡大せず原寸のまま**サムネイルを返す
    ///   （`kCGImageSourceCreateThumbnailFromImageAlways: true` は「常にサムネイルを生成する」の意味であり、
    ///   `maxPixelSize` を超えない画像を無理に拡大するものではない。実機確認済み）
    /// - `kCGImageSourceCreateThumbnailWithTransform: true` で EXIF の向き情報をピクセルに焼き込む。
    ///   これが無いと縦向き写真が横倒しで保存される
    /// - 戻り値の `widthPx` / `heightPx` は**ダウンサンプリング後の実ピクセル数**。
    ///   これをそのまま `Photo.width` / `height` に使うことで二重デコードを避けられる
    ///
    /// `@concurrent`: JPEG エンコードを含む CPU バウンドな処理。呼び出し元（`handlePickerSelection`、
    /// `@MainActor`）で実行させないために明示している。付け忘れても診断は出ず、
    /// `NonisolatedNonsendingByDefault` 下では呼び出し元アクター上で実行されるだけなので注意
    /// （`.claude/rules/swift-ios.md` SW6-3 参照）。
    @concurrent
    static func downsampledJPEG(
        from data: Data,
        maxPixelSize: Int,
        quality: CGFloat
    ) async -> (jpegData: Data, widthPx: Int32, heightPx: Int32)? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }

        guard let jpegData = UIImage(cgImage: cgImage).jpegData(compressionQuality: quality) else {
            return nil
        }

        return (jpegData: jpegData, widthPx: Int32(cgImage.width), heightPx: Int32(cgImage.height))
    }

    /// `data`（元画像 or 既にダウンサンプリング済みの JPEG）を `maxPixelSize` へ縮小デコードし、
    /// `UIImage` として返す（JPEG 再エンコードはしない）。
    ///
    /// 記録写真エディタの「保存前サムネイル」用途。`downsampledJPEG` と異なり保存はしないため
    /// JPEG エンコードのコストを払わない。デコード方針は `PhotoFileStore.loadThumbnail` と同じ。
    ///
    /// `@concurrent`: `downsampledJPEG` と同じ理由（CPU バウンドなデコードをメインスレッドで
    /// 走らせない）。
    @concurrent
    static func downsampledImage(from data: Data, maxPixelSize: Int) async -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }
}
