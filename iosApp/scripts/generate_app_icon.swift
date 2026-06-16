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

// MARK: - App Icon render

func renderAppIcon(top: NSColor, bottom: NSColor, cup: NSColor, to path: String) {
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

    // Background gradient (top → bottom in screen coords; angle -90 = top-to-bottom)
    let grad = NSGradient(starting: top, ending: bottom)!
    grad.draw(in: NSRect(x: 0, y: 0, width: size, height: size), angle: -90)

    // SF Symbol: cup.and.saucer.fill at ~52% of canvas
    let pointSize = size * 0.52
    let cfg = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .regular)
    if let base = NSImage(systemSymbolName: "cup.and.saucer.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(cfg) {
        let s = base.size
        // Tint the symbol with the desired cup color
        let tinted = NSImage(size: s)
        tinted.lockFocus()
        base.draw(in: NSRect(origin: .zero, size: s))
        cup.set()
        NSRect(origin: .zero, size: s).fill(using: .sourceAtop)
        tinted.unlockFocus()
        // Center in canvas
        let origin = NSPoint(x: (size - s.width) / 2, y: (size - s.height) / 2)
        tinted.draw(at: origin, from: .zero, operation: .sourceOver, fraction: 1.0)
    }

    NSGraphicsContext.restoreGraphicsState()

    let png = rep.representation(using: .png, properties: [:])!
    let url = URL(fileURLWithPath: path)
    try! png.write(to: url)
    print("Wrote: \(path)")
}

// MARK: - Launch Logo render

func renderLaunchLogo(to path: String) {
    // Transparent background, cream cup + wordmark on top
    // Using single image (system adapts via Assets catalog appearance)
    // We render a single light-mode logo (cream on transparent).
    // The Assets catalog LaunchLogo.imageset will use this for "Any" appearance.
    // A dark variant can be added later if needed.

    let width: CGFloat = 512
    let height: CGFloat = 512
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

    // Clear (fully transparent background)
    NSColor.clear.set()
    NSRect(x: 0, y: 0, width: width, height: height).fill()

    let creamColor = hexColor("#FBF3E8")

    // Draw cup symbol (~40% of width, centered horizontally)
    let symbolSize: CGFloat = width * 0.40
    let symCfg = NSImage.SymbolConfiguration(pointSize: symbolSize, weight: .regular)
    if let base = NSImage(systemSymbolName: "cup.and.saucer.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(symCfg) {
        let tinted = NSImage(size: base.size)
        tinted.lockFocus()
        base.draw(in: NSRect(origin: .zero, size: base.size))
        creamColor.set()
        NSRect(origin: .zero, size: base.size).fill(using: .sourceAtop)
        tinted.unlockFocus()
        // Position: center horizontally, upper portion
        let symX = (width - base.size.width) / 2
        let symY = height * 0.45   // roughly centered, leaving room for text below
        tinted.draw(at: NSPoint(x: symX, y: symY), from: .zero, operation: .sourceOver, fraction: 1.0)
    }

    // Draw "CoffeeVision" wordmark
    let font = NSFont.systemFont(ofSize: width * 0.11, weight: .semibold)
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: creamColor
    ]
    let text = "CoffeeVision" as NSString
    let textSize = text.size(withAttributes: attrs)
    let textX = (width - textSize.width) / 2
    // Place text below the symbol with a small gap
    let gap: CGFloat = width * 0.04
    let textY = height * 0.45 - gap - textSize.height
    text.draw(at: NSPoint(x: textX, y: textY), withAttributes: attrs)

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
    bottom: hexColor("#5A3A22"),
    cup: hexColor("#FBF3E8"),
    to: "\(appIconDir)/icon-light-1024.png"
)

// Dark variant
renderAppIcon(
    top: hexColor("#3A2418"),
    bottom: hexColor("#1C0F08"),
    cup: hexColor("#FBF3E8"),
    to: "\(appIconDir)/icon-dark-1024.png"
)

// Tinted variant (greyscale; system overlays its tint color)
renderAppIcon(
    top: hexColor("#4A4A4A"),
    bottom: hexColor("#1A1A1A"),
    cup: hexColor("#E0E0E0"),
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
