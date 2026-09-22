// Renders a simple book-themed app icon (SF Symbol on a colored rounded square)
// into an .iconset directory. Run with: swift generate_icon.swift <output.iconset>
import AppKit

let outputDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

let sizes: [(Int, String)] = [
    (16, "icon_16x16"),
    (32, "icon_16x16@2x"),
    (32, "icon_32x32"),
    (64, "icon_32x32@2x"),
    (128, "icon_128x128"),
    (256, "icon_128x128@2x"),
    (256, "icon_256x256"),
    (512, "icon_256x256@2x"),
    (512, "icon_512x512"),
    (1024, "icon_512x512@2x"),
]

func renderIcon(size: Int) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let bgRect = NSRect(x: 0, y: 0, width: size, height: size)
    let cornerRadius = CGFloat(size) * 0.22
    let path = NSBezierPath(roundedRect: bgRect, xRadius: cornerRadius, yRadius: cornerRadius)
    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.20, green: 0.45, blue: 0.95, alpha: 1.0),
        NSColor(calibratedRed: 0.35, green: 0.20, blue: 0.85, alpha: 1.0),
    ])
    gradient?.draw(in: path, angle: -90)

    let symbolConfig = NSImage.SymbolConfiguration(pointSize: CGFloat(size) * 0.55, weight: .semibold)
    if let symbol = NSImage(systemSymbolName: "book.closed.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(symbolConfig) {
        let tinted = symbol.copy() as! NSImage
        tinted.isTemplate = false
        let symbolSize = tinted.size
        let origin = NSPoint(x: (CGFloat(size) - symbolSize.width) / 2, y: (CGFloat(size) - symbolSize.height) / 2)

        NSColor.white.set()
        let rect = NSRect(origin: origin, size: symbolSize)
        tinted.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)
        rect.fill(using: .sourceAtop)
    }

    image.unlockFocus()
    return image
}

for (size, name) in sizes {
    let image = renderIcon(size: size)
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else { continue }
    let path = "\(outputDir)/\(name).png"
    try? png.write(to: URL(fileURLWithPath: path))
}

print("Wrote iconset to \(outputDir)")
