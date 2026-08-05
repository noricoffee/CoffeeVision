#!/usr/bin/env swift
// generate_app_icon.swift
// CoffeeVision — App Icon + LaunchLogo generator
//
// Usage: swift iosApp/scripts/generate_app_icon.swift
// (run from repo root)
//
// Outputs:
//   iosApp/iosApp/Assets.xcassets/AppIcon.appiconset/icon-light-1024.png
//   iosApp/iosApp/Assets.xcassets/AppIcon.appiconset/icon-dark-1024.png
//   iosApp/iosApp/Assets.xcassets/AppIcon.appiconset/icon-tinted-1024.png
//   iosApp/iosApp/Assets.xcassets/LaunchLogo.imageset/launch-logo.png
//
// Mark: an almond-shaped eye outline (CoffeeVision's "Vision") with a
// cup & saucer inside. Everything is drawn from NSBezierPath — no SF
// Symbols — because SF Symbols may not be used as an app icon / logo
// per Apple's license terms.

import AppKit
import Foundation

// MARK: - Helpers

func hexColor(_ hex: String, alpha: CGFloat = 1.0) -> NSColor {
    var h = hex.trimmingCharacters(in: .init(charactersIn: "#"))
    if h.count == 6 { h += "FF" }
    let val = UInt64(h, radix: 16)!
    let r = CGFloat((val >> 24) & 0xFF) / 255
    let g = CGFloat((val >> 16) & 0xFF) / 255
    let b = CGFloat((val >> 8)  & 0xFF) / 255
    let a = CGFloat(val & 0xFF)         / 255
    return NSColor(srgbRed: r, green: g, blue: b, alpha: a * alpha)
}

func oval(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat) -> NSBezierPath {
    NSBezierPath(ovalIn: NSRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2))
}
func disc(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) -> NSBezierPath {
    NSBezierPath(ovalIn: NSRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
}

/// Almond eye outline: two mirrored cubic arcs meeting at points.
func eyeOutline(_ c: CGFloat, w: CGFloat, h: CGFloat) -> NSBezierPath {
    let p = NSBezierPath()
    let k = h / 0.75   // control-point height so the arc peaks at h
    p.move(to: NSPoint(x: c - w, y: c))
    p.curve(to: NSPoint(x: c + w, y: c),
            controlPoint1: NSPoint(x: c - w * 0.45, y: c + k),
            controlPoint2: NSPoint(x: c + w * 0.45, y: c + k))
    p.curve(to: NSPoint(x: c - w, y: c),
            controlPoint1: NSPoint(x: c + w * 0.45, y: c - k),
            controlPoint2: NSPoint(x: c - w * 0.45, y: c - k))
    p.close()
    return p
}

/// Cup + saucer, drawn from paths. `u` = total cup width. Holes are punched by
/// re-running `bg` inside a clip, so `bg` must repaint whatever is behind the cup.
func drawCup(cx: CGFloat, cy: CGFloat, u: CGFloat, ink: NSColor, bg: () -> Void) {
    ink.setFill()

    // saucer: a thin ring. Its inner ellipse leaves the gap around the cup's foot.
    oval(cx, cy - 0.2056 * u, 0.500 * u, 0.1682 * u).fill()
    NSGraphicsContext.saveGraphicsState()
    oval(cx, cy - 0.1900 * u, 0.345 * u, 0.0880 * u).addClip(); bg()
    NSGraphicsContext.restoreGraphicsState()

    // handle: outer disc, then punch its hole
    disc(cx + 0.373 * u, cy + 0.0934 * u, 0.093 * u).fill()
    NSGraphicsContext.saveGraphicsState()
    disc(cx + 0.373 * u, cy + 0.0934 * u, 0.035 * u).addClip(); bg()
    NSGraphicsContext.restoreGraphicsState()

    // body: near-cylindrical sides (7% taper), rounded foot
    ink.setFill()
    let yTop = cy + 0.2262 * u, yMid = cy
    let body = NSBezierPath()
    body.move(to: NSPoint(x: cx - 0.337 * u, y: yTop))
    body.line(to: NSPoint(x: cx - 0.312 * u, y: yMid))
    body.curve(to: NSPoint(x: cx + 0.312 * u, y: yMid),
               controlPoint1: NSPoint(x: cx - 0.300 * u, y: yMid - 0.300 * u),
               controlPoint2: NSPoint(x: cx + 0.300 * u, y: yMid - 0.300 * u))
    body.line(to: NSPoint(x: cx + 0.337 * u, y: yTop))
    body.close()
    body.fill()

    // rim: outer ellipse, then punch the opening
    oval(cx, cy + 0.2262 * u, 0.339 * u, 0.1476 * u).fill()
    NSGraphicsContext.saveGraphicsState()
    oval(cx, cy + 0.2262 * u, 0.280 * u, 0.0916 * u).addClip(); bg()
    NSGraphicsContext.restoreGraphicsState()
}

// MARK: - App Icon render

func renderAppIcon(top: NSColor, bottom: NSColor, ink: NSColor, to path: String) {
    let size: CGFloat = 1024
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(size), pixelsHigh: Int(size),
        bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ctx

    // bg closure: full-canvas vertical gradient, angle -90 (top → bottom)
    let bg = { NSGradient(starting: top, ending: bottom)!
        .draw(in: NSRect(x: 0, y: 0, width: size, height: size), angle: -90) }
    bg()

    let c = size / 2
    let eye = eyeOutline(c, w: 0.375 * size, h: 0.215 * size)
    eye.lineWidth = 0.040 * size
    eye.lineJoinStyle = .round
    eye.lineCapStyle = .round
    ink.setStroke()
    eye.stroke()
    drawCup(cx: c, cy: c, u: 0.361 * size, ink: ink, bg: bg)

    NSGraphicsContext.restoreGraphicsState()

    let png = rep.representation(using: .png, properties: [:])!
    let url = URL(fileURLWithPath: path)
    try! png.write(to: url)
    print("Wrote: \(path)")
}

// MARK: - Launch Logo render

func renderLaunchLogo(to path: String) {
    // Transparent background, cream mark + wordmark on top.
    // The full lockup (mark + wordmark) is first rendered into an
    // intermediate transparent canvas at a "natural" position, then its
    // content bounding box (alpha > 0) is measured and the lockup is
    // re-composited shifted so that bounding box sits centered in the
    // final canvas. `UILaunchScreen` centers the image's frame on screen,
    // so asymmetric transparent padding around the visible content would
    // otherwise show up as an off-center mark on the launch screen. Measuring
    // the actual rendered bbox (rather than hardcoding an offset) keeps this
    // correct if the mark size / wordmark ever changes.

    let width: CGFloat = 512
    let height: CGFloat = 512

    // 1) Render the lockup into an intermediate canvas.
    let lockupRep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(width), pixelsHigh: Int(height),
        bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    let lockupCtx = NSGraphicsContext(bitmapImageRep: lockupRep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = lockupCtx

    // Clear (fully transparent background). `.copy` overwrites the alpha
    // channel too, unlike the default `.sourceOver`, which would leave
    // the canvas opaque black instead of transparent.
    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: width, height: height).fill(using: .copy)

    let ink = hexColor("#FBF3E8")

    // Render the eye + cup mark into its own transparent square canvas.
    let markSize: CGFloat = width * 0.62
    let mark = NSImage(size: NSSize(width: markSize, height: markSize))
    mark.lockFocus()
    let markBg = {
        NSColor.clear.setFill()
        NSRect(x: 0, y: 0, width: markSize, height: markSize).fill(using: .copy)
    }
    markBg()
    let mc = markSize / 2
    let eye = eyeOutline(mc, w: 0.375 * markSize, h: 0.215 * markSize)
    eye.lineWidth = 0.040 * markSize
    eye.lineJoinStyle = .round
    eye.lineCapStyle = .round
    ink.setStroke()
    eye.stroke()
    drawCup(cx: mc, cy: mc, u: 0.361 * markSize, ink: ink, bg: markBg)
    mark.unlockFocus()

    let markOrigin = NSPoint(x: (width - markSize) / 2, y: height * 0.42)
    mark.draw(at: markOrigin, from: .zero, operation: .sourceOver, fraction: 1.0)

    // Draw "CoffeeVision" wordmark below the mark
    let font = NSFont.systemFont(ofSize: width * 0.11, weight: .semibold)
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: ink
    ]
    let text = "CoffeeVision" as NSString
    let textSize = text.size(withAttributes: attrs)
    let textX = (width - textSize.width) / 2
    let gap: CGFloat = width * 0.04
    let textY = markOrigin.y - gap - textSize.height
    text.draw(at: NSPoint(x: textX, y: textY), withAttributes: attrs)

    NSGraphicsContext.restoreGraphicsState()

    // 2) Measure the lockup's content bounding box (alpha > 0). NSBitmapImageRep
    //    pixel rows run top-down, the opposite of the bottom-up drawing space
    //    used above, so the y axis must be flipped when converting the bbox
    //    back into a drawing-space shift.
    var minXc = Int(width), maxXc = -1, minYc = Int(height), maxYc = -1
    for y in 0..<lockupRep.pixelsHigh {
        for x in 0..<lockupRep.pixelsWide {
            if let c = lockupRep.colorAt(x: x, y: y), c.alphaComponent > 0.01 {
                if x < minXc { minXc = x }
                if x > maxXc { maxXc = x }
                if y < minYc { minYc = y }
                if y > maxYc { maxYc = y }
            }
        }
    }
    // Solve for the integer shift that makes minX'+maxX' == width-1 (and
    // likewise for y, after accounting for the axis flip above) so that
    // left/right and top/bottom padding come out equal.
    let shiftX = (((width - 1) - CGFloat(minXc + maxXc)) / 2).rounded()
    let shiftY = ((CGFloat(minYc + maxYc) - (height - 1)) / 2).rounded()

    // 3) Composite the lockup onto the final canvas, shifted so its content
    //    bounding box sits centered (equal top/bottom, left/right padding).
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(width), pixelsHigh: Int(height),
        bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ctx
    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: width, height: height).fill(using: .copy)
    lockupRep.draw(in: NSRect(x: shiftX, y: shiftY, width: width, height: height))
    NSGraphicsContext.restoreGraphicsState()

    let png = rep.representation(using: .png, properties: [:])!
    let url = URL(fileURLWithPath: path)
    try! png.write(to: url)
    print("Wrote: \(path)")
}

// MARK: - Main

// Resolve output directories relative to script location or CWD
// Expect to be run from repo root: swift iosApp/scripts/generate_app_icon.swift
let cwd = FileManager.default.currentDirectoryPath
let assetBase = "\(cwd)/iosApp/iosApp/Assets.xcassets"
let appIconDir = "\(assetBase)/AppIcon.appiconset"
let launchLogoDir = "\(assetBase)/LaunchLogo.imageset"

// Ensure LaunchLogo.imageset directory exists
try! FileManager.default.createDirectory(atPath: launchLogoDir, withIntermediateDirectories: true)

print("Generating App Icons...")

// Light variant
renderAppIcon(
    top: hexColor("#8B5E3C"),
    bottom: hexColor("#4E3020"),
    ink: hexColor("#FBF3E8"),
    to: "\(appIconDir)/icon-light-1024.png"
)

// Dark variant
renderAppIcon(
    top: hexColor("#3A2418"),
    bottom: hexColor("#1C0F08"),
    ink: hexColor("#FBF3E8"),
    to: "\(appIconDir)/icon-dark-1024.png"
)

// Tinted variant (greyscale; system overlays its tint color)
renderAppIcon(
    top: hexColor("#4A4A4A"),
    bottom: hexColor("#1A1A1A"),
    ink: hexColor("#E0E0E0"),
    to: "\(appIconDir)/icon-tinted-1024.png"
)

print("\nGenerating Launch Logo...")
renderLaunchLogo(to: "\(launchLogoDir)/launch-logo.png")

print("\nDone. Verifying sizes...")
for file in [
    "\(appIconDir)/icon-light-1024.png",
    "\(appIconDir)/icon-dark-1024.png",
    "\(appIconDir)/icon-tinted-1024.png",
    "\(launchLogoDir)/launch-logo.png"
] {
    if let img = NSImage(contentsOfFile: file) {
        let rep = img.representations.first
        print("  \(URL(fileURLWithPath: file).lastPathComponent): \(rep?.pixelsWide ?? -1) x \(rep?.pixelsHigh ?? -1)")
    }
}
