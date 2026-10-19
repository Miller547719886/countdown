import AppKit
import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let iconset = root.appendingPathComponent("Resources/AppIcon.iconset", isDirectory: true)
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func drawIcon(size: Int, url: URL) throws {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    guard let context = NSGraphicsContext.current?.cgContext else {
        throw NSError(domain: "JiedianIcon", code: 1)
    }

    let s = CGFloat(size)
    let paper = NSColor(calibratedRed: 0.97, green: 0.95, blue: 0.91, alpha: 1)
    let ink = NSColor(calibratedRed: 0.10, green: 0.095, blue: 0.08, alpha: 1)
    let red = NSColor(calibratedRed: 0.72, green: 0.17, blue: 0.09, alpha: 1)
    let rule = NSColor(calibratedRed: 0.71, green: 0.67, blue: 0.60, alpha: 1)

    let radius = s * 0.205
    let body = NSBezierPath(roundedRect: NSRect(x: s * 0.055, y: s * 0.055, width: s * 0.89, height: s * 0.89), xRadius: radius, yRadius: radius)
    paper.setFill()
    body.fill()

    context.saveGState()
    body.addClip()

    let tabWidth = s * 0.22
    red.setFill()
    NSRect(x: s * 0.055, y: s * 0.055, width: tabWidth, height: s * 0.89).fill()

    ink.setFill()
    for index in 0..<3 {
        let y = s * (0.67 - CGFloat(index) * 0.17)
        NSRect(x: s * 0.37, y: y, width: s * 0.39, height: s * 0.027).fill()
    }

    rule.setFill()
    NSRect(x: s * 0.37, y: s * 0.33, width: s * 0.39, height: s * 0.012).fill()
    NSRect(x: s * 0.37, y: s * 0.24, width: s * 0.25, height: s * 0.012).fill()

    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont(name: "Songti-SC-Bold", size: s * 0.14) ?? NSFont.boldSystemFont(ofSize: s * 0.14),
        .foregroundColor: paper,
        .paragraphStyle: paragraph
    ]
    let glyph = "截"
    let textRect = NSRect(x: s * 0.055, y: s * 0.39, width: tabWidth, height: s * 0.24)
    glyph.draw(in: textRect, withAttributes: attributes)

    context.restoreGState()
    image.unlockFocus()

    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "JiedianIcon", code: 2)
    }
    try png.write(to: url)
}

let outputs: [(Int, String)] = [
    (16, "icon_16x16.png"), (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"), (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"), (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"), (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"), (1024, "icon_512x512@2x.png")
]

for (size, name) in outputs {
    try drawIcon(size: size, url: iconset.appendingPathComponent(name))
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconset.path, "-o", root.appendingPathComponent("Resources/AppIcon.icns").path]
try process.run()
process.waitUntilExit()
if process.terminationStatus != 0 {
    throw NSError(domain: "JiedianIcon", code: Int(process.terminationStatus))
}
print("Generated Resources/AppIcon.icns")
