import AppKit
import Foundation
// Original geometric disk/leaf mark. Drawn as vectors at each required icon size.
let output = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
for (name, size) in [("icon_16x16",16),("icon_16x16@2x",32),("icon_32x32",32),("icon_32x32@2x",64),("icon_128x128",128),("icon_128x128@2x",256),("icon_256x256",256),("icon_256x256@2x",512),("icon_512x512",512),("icon_512x512@2x",1024)] {
    guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
          let context = NSGraphicsContext(bitmapImageRep: bitmap) else { fatalError("Cannot render icon") }
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = context
    let scale = CGFloat(size) / 1024
    let transform = NSAffineTransform(); transform.scale(by: scale); transform.concat()
    let background = NSBezierPath(roundedRect: NSRect(x: 60, y: 60, width: 904, height: 904), xRadius: 210, yRadius: 210)
    NSColor(calibratedRed: 0.08, green: 0.23, blue: 0.42, alpha: 1).setFill(); background.fill()
    let ring = NSBezierPath(ovalIn: NSRect(x: 220, y: 220, width: 584, height: 584))
    NSColor(calibratedRed: 0.87, green: 0.95, blue: 1, alpha: 1).setStroke(); ring.lineWidth = 70; ring.stroke()
    let center = NSBezierPath(ovalIn: NSRect(x: 440, y: 440, width: 144, height: 144))
    NSColor.white.setFill(); center.fill()
    let leaf = NSBezierPath()
    leaf.move(to: NSPoint(x: 580, y: 570)); leaf.curve(to: NSPoint(x: 850, y: 810), controlPoint1: NSPoint(x: 530, y: 790), controlPoint2: NSPoint(x: 780, y: 850))
    leaf.curve(to: NSPoint(x: 580, y: 570), controlPoint1: NSPoint(x: 890, y: 600), controlPoint2: NSPoint(x: 710, y: 530)); leaf.close()
    NSColor(calibratedRed: 0.22, green: 0.82, blue: 0.64, alpha: 1).setFill(); leaf.fill()
    NSGraphicsContext.restoreGraphicsState()
    guard let png = bitmap.representation(using: .png, properties: [:]) else { fatalError("Cannot encode icon") }
    try png.write(to: output.appendingPathComponent(name + ".png"))
}
