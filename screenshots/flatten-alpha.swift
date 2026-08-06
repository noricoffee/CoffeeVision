// App Store Connect 提出用に、スクリーンショットのアルファチャンネルを除去する。
//
// simctl のスクリーンショットは全ピクセル不透明でもアルファチャンネルを持つ。
// ASC は「alpha channels or transparencies を含む画像」を受け付けないため、
// 白背景に合成してアルファ無しの PNG として書き出す。
//
// 使い方: xcrun swift flatten-alpha.swift <入力ディレクトリ> <出力ディレクトリ>

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let args = CommandLine.arguments
guard args.count == 3 else {
    FileHandle.standardError.write("usage: flatten-alpha.swift <入力ディレクトリ> <出力ディレクトリ>\n".data(using: .utf8)!)
    exit(1)
}
let inputDir = URL(fileURLWithPath: args[1])
let outputDir = URL(fileURLWithPath: args[2])
try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

let files = try FileManager.default.contentsOfDirectory(at: inputDir, includingPropertiesForKeys: nil)
    .filter { $0.pathExtension.lowercased() == "png" }
    .sorted { $0.lastPathComponent < $1.lastPathComponent }

guard !files.isEmpty else {
    FileHandle.standardError.write("入力ディレクトリに PNG がありません: \(inputDir.path)\n".data(using: .utf8)!)
    exit(1)
}

var failed = 0
for file in files {
    guard let source = CGImageSourceCreateWithURL(file as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        print("読み込み失敗: \(file.lastPathComponent)")
        failed += 1
        continue
    }

    let width = image.width
    let height = image.height

    // alphaInfo = .noneSkipLast にすることで、書き出される PNG がアルファを持たなくなる
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ) else {
        print("コンテキスト生成失敗: \(file.lastPathComponent)")
        failed += 1
        continue
    }

    // 透過部分が黒く落ちないよう白で塗ってから合成する
    context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

    guard let flattened = context.makeImage() else {
        print("画像生成失敗: \(file.lastPathComponent)")
        failed += 1
        continue
    }

    let outURL = outputDir.appendingPathComponent(file.lastPathComponent)
    guard let dest = CGImageDestinationCreateWithURL(outURL as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        print("書き出し先の生成失敗: \(file.lastPathComponent)")
        failed += 1
        continue
    }
    CGImageDestinationAddImage(dest, flattened, nil)
    if CGImageDestinationFinalize(dest) {
        print("OK  \(file.lastPathComponent)  \(width)x\(height)")
    } else {
        print("書き出し失敗: \(file.lastPathComponent)")
        failed += 1
    }
}

print("---")
print("完了: \(files.count - failed) / \(files.count) 枚")
exit(failed == 0 ? 0 : 1)
