#!/usr/bin/swift
// Generates AppIcon-1024.png for PetruVim at exactly 1024x1024 pixels.
// Run: swift scripts/generate_icon.swift <output_path>

import AppKit
import CoreGraphics

let px = 1024

// Create a 1024x1024 bitmap context (1:1 pixels, no Retina scaling)
guard let ctx = CGContext(
    data: nil,
    width: px, height: px,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fputs("Error: failed to create CGContext\n", stderr); exit(1)
}

let bounds = CGRect(x: 0, y: 0, width: px, height: px)
let size = CGFloat(px)

// Background: deep terminal dark
ctx.setFillColor(CGColor(red: 0.09, green: 0.10, blue: 0.14, alpha: 1.0))
let bgPath = CGPath(roundedRect: bounds, cornerWidth: 224, cornerHeight: 224, transform: nil)
ctx.addPath(bgPath)
ctx.fillPath()

// Subtle inner glow ring
ctx.setFillColor(CGColor(red: 0.18, green: 0.85, blue: 0.42, alpha: 0.06))
let glowPath = CGPath(roundedRect: bounds.insetBy(dx: 40, dy: 40), cornerWidth: 190, cornerHeight: 190, transform: nil)
ctx.addPath(glowPath)
ctx.fillPath()

// Draw "V" and block cursor using NSAttributedString inside NSGraphicsContext
let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: false)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = nsCtx

let green = NSColor(calibratedRed: 0.18, green: 0.85, blue: 0.42, alpha: 1.0)
let font = NSFont.monospacedSystemFont(ofSize: 530, weight: .bold)
let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: green]
let str = NSAttributedString(string: "V", attributes: attrs)
let sz = str.size()
let letterOrigin = NSPoint(x: (size - sz.width) / 2 - 28, y: (size - sz.height) / 2 + 28)
str.draw(at: letterOrigin)

// Block cursor
NSColor(calibratedRed: 0.18, green: 0.85, blue: 0.42, alpha: 0.9).setFill()
NSRect(x: letterOrigin.x + sz.width + 6, y: letterOrigin.y + 10, width: 52, height: 78).fill()

NSGraphicsContext.restoreGraphicsState()

// Save PNG
guard let cgImage = ctx.makeImage() else {
    fputs("Error: failed to create CGImage\n", stderr); exit(1)
}

let rep = NSBitmapImageRep(cgImage: cgImage)
rep.size = NSSize(width: px, height: px)
guard let pngData = rep.representation(using: .png, properties: [:]) else {
    fputs("Error: failed to encode PNG\n", stderr); exit(1)
}

let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon-1024.png"
do {
    try pngData.write(to: URL(fileURLWithPath: outputPath))
    print("Generated \(outputPath) (\(pngData.count / 1024) KB)")
} catch {
    fputs("Error writing: \(error)\n", stderr); exit(1)
}
