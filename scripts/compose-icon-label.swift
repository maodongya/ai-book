#!/usr/bin/env swift
import AppKit
import Foundation

guard CommandLine.arguments.count >= 3 else {
    fputs("Usage: compose-icon-label.swift <input.png> <output.png>\n", stderr)
    exit(1)
}

let inputPath = CommandLine.arguments[1]
let outputPath = CommandLine.arguments[2]

guard let image = NSImage(contentsOfFile: inputPath) else {
    fputs("Failed to load \(inputPath)\n", stderr)
    exit(1)
}

guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    fputs("Failed to decode image\n", stderr)
    exit(1)
}

let width = cgImage.width
let height = cgImage.height

guard let outputRep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: width,
    pixelsHigh: height,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fputs("Failed to create bitmap\n", stderr)
    exit(1)
}

NSGraphicsContext.saveGraphicsState()
defer { NSGraphicsContext.restoreGraphicsState() }
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: outputRep)

NSGraphicsContext.current?.imageInterpolation = .high
image.draw(
    in: NSRect(x: 0, y: 0, width: width, height: height),
    from: .zero,
    operation: .copy,
    fraction: 1
)

let text = "ai-book"
let fontSize = CGFloat(width) * 0.058
let font =
    NSFont(name: "Georgia-Bold", size: fontSize)
    ?? NSFont(name: "Times New Roman Bold", size: fontSize)
    ?? NSFont.systemFont(ofSize: fontSize, weight: .semibold)

let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.42)
shadow.shadowOffset = NSSize(width: 0, height: -2)
shadow.shadowBlurRadius = 5

let gold = NSColor(calibratedRed: 0.82, green: 0.64, blue: 0.30, alpha: 1)
let attributes: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: gold,
    .shadow: shadow,
    .kern: -0.4,
]

let attributed = NSAttributedString(string: text, attributes: attributes)
let textSize = attributed.size()

// Center on the book cover panel inside the gold frame.
let centerX = CGFloat(width) * 0.575
let centerY = CGFloat(height) * 0.492
let textRect = NSRect(
    x: centerX - textSize.width / 2,
    y: centerY - textSize.height / 2,
    width: textSize.width,
    height: textSize.height
)

attributed.draw(in: textRect)

guard let pngData = outputRep.representation(using: .png, properties: [:]) else {
    fputs("Failed to encode PNG\n", stderr)
    exit(1)
}

do {
    try pngData.write(to: URL(fileURLWithPath: outputPath))
    print("Wrote \(outputPath)")
} catch {
    fputs("Failed to write \(outputPath): \(error)\n", stderr)
    exit(1)
}
