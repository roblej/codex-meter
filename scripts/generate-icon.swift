import AppKit
import Foundation

guard CommandLine.arguments.count == 3 else {
    fputs("usage: generate-icon.swift <source.png> <output.appiconset>\n", stderr)
    exit(1)
}

let sourceURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
let fileManager = FileManager.default

guard let sourceImage = NSImage(contentsOf: sourceURL) else {
    fputs("Unable to read source icon: \(sourceURL.path)\n", stderr)
    exit(2)
}

try? fileManager.removeItem(at: outputDirectory)
try fileManager.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

let variants: [(name: String, pixels: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for variant in variants {
    let size = variant.pixels
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw NSError(domain: "CodexMeterIcon", code: 1)
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    sourceImage.draw(
        in: NSRect(x: 0, y: 0, width: size, height: size),
        from: NSRect(origin: .zero, size: sourceImage.size),
        operation: .copy,
        fraction: 1
    )
    NSGraphicsContext.restoreGraphicsState()

    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "CodexMeterIcon", code: 2)
    }
    try png.write(to: outputDirectory.appendingPathComponent(variant.name))
}

let contents: [String: Any] = [
    "images": [
        ["filename": "icon_16x16.png", "idiom": "mac", "scale": "1x", "size": "16x16"],
        ["filename": "icon_16x16@2x.png", "idiom": "mac", "scale": "2x", "size": "16x16"],
        ["filename": "icon_32x32.png", "idiom": "mac", "scale": "1x", "size": "32x32"],
        ["filename": "icon_32x32@2x.png", "idiom": "mac", "scale": "2x", "size": "32x32"],
        ["filename": "icon_128x128.png", "idiom": "mac", "scale": "1x", "size": "128x128"],
        ["filename": "icon_128x128@2x.png", "idiom": "mac", "scale": "2x", "size": "128x128"],
        ["filename": "icon_256x256.png", "idiom": "mac", "scale": "1x", "size": "256x256"],
        ["filename": "icon_256x256@2x.png", "idiom": "mac", "scale": "2x", "size": "256x256"],
        ["filename": "icon_512x512.png", "idiom": "mac", "scale": "1x", "size": "512x512"],
        ["filename": "icon_512x512@2x.png", "idiom": "mac", "scale": "2x", "size": "512x512"]
    ],
    "info": ["author": "xcode", "version": 1]
]
let contentsData = try JSONSerialization.data(
    withJSONObject: contents,
    options: [.prettyPrinted, .sortedKeys]
)
try contentsData.write(to: outputDirectory.appendingPathComponent("Contents.json"))
