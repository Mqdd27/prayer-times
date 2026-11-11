// Builds AppIcon.icns from an illustration.
// Usage: swift make-icon.swift <image> && iconutil -c icns AppIcon.iconset && rm -r AppIcon.iconset
import AppKit

let src = NSImage(contentsOfFile: CommandLine.arguments[1])!
let bitmap = NSBitmapImageRep(data: src.tiffRepresentation!)!
// Paper color of the illustration, so the artwork blends into the icon body
let paper = bitmap.colorAt(x: 4, y: 4)!

func render(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current!.imageInterpolation = .high
    let s = CGFloat(px)
    // macOS icon grid: 824/1024 body centered, ~185/1024 corner radius
    let inset = s * 100 / 1024, body = NSRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let shape = NSBezierPath(roundedRect: body, xRadius: s * 185 / 1024, yRadius: s * 185 / 1024)
    paper.setFill(); shape.fill()
    shape.addClip()
    // The artwork has ~7% empty margin; scale it up a touch so the scene fills the body
    let art = body.insetBy(dx: -body.width * 0.04, dy: -body.height * 0.04)
    src.draw(in: art, from: .zero, operation: .sourceOver, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let dir = "AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
for (name, px) in [("16x16", 16), ("16x16@2x", 32), ("32x32", 32), ("32x32@2x", 64), ("128x128", 128),
                   ("128x128@2x", 256), ("256x256", 256), ("256x256@2x", 512)] {  // 512@1x would duplicate 256@2x
    try! render(px).write(to: URL(fileURLWithPath: "\(dir)/icon_\(name).png"))
}
