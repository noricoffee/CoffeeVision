// App Store 提出用に、スクリーンショットへキャッチコピーを焼き込む。
//
// レイアウト: クリーム背景を全面に敷き、上部にコピー（2 行）、
// 下にスクリーンショットを角丸＋影のカードとして配置する。カードの下端は
// 画面外へ逃がし、「まだ続く」ことを示す。
//
// 出力はアルファチャンネルを持たない PNG なので、flatten-alpha.swift を
// 通す必要はない（ASC へそのままアップロードできる）。
//
// 使い方: xcrun swift compose-captions.swift <入力ディレクトリ> <出力ディレクトリ>

import Foundation
import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers

// MARK: - コピー（文言の正は docs/app-store-metadata.md §5）

/// ファイル名 → コピーの行。読点で改行して 2 行に割り、文字を大きく見せる。
let captions: [String: [String]] = [
    "01-analyze-summary.png": ["味覚の輪郭が、", "見えてくる"],
    "02-analyze-suggest.png": ["好みから、", "次の一杯が見えてくる"],
    "03-map.png":             ["お気に入りの一杯を", "発見しよう"],
    "04-record-list.png":     ["一杯ずつ、", "積み上がっていく"],
    "05-record-editor.png":   ["味の記憶を、", "5 つの軸で"],
    "06-cafe-detail.png":     ["もちろん", "カフェの情報もチェック"],
]

// MARK: - デザイン定数

let canvasWidth = 1320
let canvasHeight = 2868

/// クリーム（生成り）背景。
let backgroundColor = CGColor(red: 0.965, green: 0.937, blue: 0.898, alpha: 1)
/// 濃茶の文字色。AccentColor の light 値 #8B5A2B。
let textColor = CGColor(red: 0x8B / 255.0, green: 0x5A / 255.0, blue: 0x2B / 255.0, alpha: 1)

let fontName = "HiraginoSans-W6" as CFString
let fontSize: CGFloat = 82
let lineHeight: CGFloat = 116
let topMargin: CGFloat = 200        // キャンバス上端 → 1 行目のベースラインまで
let gapBelowText: CGFloat = 150     // コピー最終行 → カード上端
let cardWidthRatio: CGFloat = 0.84
let cardCornerRadius: CGFloat = 56

// MARK: - 実行

let args = CommandLine.arguments
guard args.count == 3 else {
    FileHandle.standardError.write("usage: compose-captions.swift <入力ディレクトリ> <出力ディレクトリ>\n".data(using: .utf8)!)
    exit(1)
}
let inputDir = URL(fileURLWithPath: args[1])
let outputDir = URL(fileURLWithPath: args[2])
try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

let font = CTFontCreateWithName(fontName, fontSize, nil)

/// 1 行を中央揃えで描く。描画幅がカードに収まらない場合は縮めて返す。
func drawCenteredLine(_ text: String, in context: CGContext, baselineY: CGFloat, maxWidth: CGFloat) {
    var usedFont = font
    var line = CTLineCreateWithAttributedString(NSAttributedString(
        string: text,
        attributes: [
            kCTFontAttributeName as NSAttributedString.Key: usedFont,
            kCTForegroundColorAttributeName as NSAttributedString.Key: textColor,
        ]
    ))
    var width = CTLineGetTypographicBounds(line, nil, nil, nil)

    // 想定外に長い文言が来ても破綻させない（収まるまで 2pt ずつ縮める）
    var size = fontSize
    while width > maxWidth && size > 40 {
        size -= 2
        usedFont = CTFontCreateWithName(fontName, size, nil)
        line = CTLineCreateWithAttributedString(NSAttributedString(
            string: text,
            attributes: [
                kCTFontAttributeName as NSAttributedString.Key: usedFont,
                kCTForegroundColorAttributeName as NSAttributedString.Key: textColor,
            ]
        ))
        width = CTLineGetTypographicBounds(line, nil, nil, nil)
    }

    context.textPosition = CGPoint(x: (CGFloat(canvasWidth) - CGFloat(width)) / 2, y: baselineY)
    CTLineDraw(line, context)
}

let files = try FileManager.default.contentsOfDirectory(at: inputDir, includingPropertiesForKeys: nil)
    .filter { $0.pathExtension.lowercased() == "png" }
    .sorted { $0.lastPathComponent < $1.lastPathComponent }

var failed = 0
for file in files {
    let name = file.lastPathComponent
    guard let lines = captions[name] else {
        print("コピー未定義のためスキップ: \(name)")
        failed += 1
        continue
    }
    guard let source = CGImageSourceCreateWithURL(file as CFURL, nil),
          let shot = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        print("読み込み失敗: \(name)")
        failed += 1
        continue
    }

    guard let context = CGContext(
        data: nil,
        width: canvasWidth,
        height: canvasHeight,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ) else {
        print("コンテキスト生成失敗: \(name)")
        failed += 1
        continue
    }

    // CoreGraphics は原点が左下。上端からの距離で考えたいので y を反転して扱う。
    func flip(_ yFromTop: CGFloat) -> CGFloat { CGFloat(canvasHeight) - yFromTop }

    context.setFillColor(backgroundColor)
    context.fill(CGRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight))

    // --- コピー ---
    let cardWidth = CGFloat(canvasWidth) * cardWidthRatio
    for (index, line) in lines.enumerated() {
        let baselineFromTop = topMargin + CGFloat(index) * lineHeight
        drawCenteredLine(line, in: context, baselineY: flip(baselineFromTop), maxWidth: cardWidth)
    }

    // --- スクリーンショットのカード ---
    let cardTop = topMargin + CGFloat(lines.count - 1) * lineHeight + gapBelowText
    let cardHeight = cardWidth * CGFloat(shot.height) / CGFloat(shot.width)
    let cardRect = CGRect(
        x: (CGFloat(canvasWidth) - cardWidth) / 2,
        y: flip(cardTop) - cardHeight,   // 下端はキャンバス外に出る（意図どおり）
        width: cardWidth,
        height: cardHeight
    )

    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -18), blur: 44,
                      color: CGColor(red: 0.25, green: 0.15, blue: 0.06, alpha: 0.28))
    context.beginPath()
    context.addPath(CGPath(roundedRect: cardRect, cornerWidth: cardCornerRadius,
                           cornerHeight: cardCornerRadius, transform: nil))
    context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.beginPath()
    context.addPath(CGPath(roundedRect: cardRect, cornerWidth: cardCornerRadius,
                           cornerHeight: cardCornerRadius, transform: nil))
    context.clip()
    context.draw(shot, in: cardRect)
    context.restoreGState()

    guard let composed = context.makeImage() else {
        print("画像生成失敗: \(name)")
        failed += 1
        continue
    }
    let outURL = outputDir.appendingPathComponent(name)
    guard let dest = CGImageDestinationCreateWithURL(outURL as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        print("書き出し先の生成失敗: \(name)")
        failed += 1
        continue
    }
    CGImageDestinationAddImage(dest, composed, nil)
    if CGImageDestinationFinalize(dest) {
        print("OK  \(name)  「\(lines.joined())」")
    } else {
        print("書き出し失敗: \(name)")
        failed += 1
    }
}

print("---")
print("完了: \(files.count - failed) / \(files.count) 枚")
exit(failed == 0 ? 0 : 1)
