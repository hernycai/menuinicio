import AppKit
import Foundation
let output = CommandLine.arguments[1]
let manager = FileManager.default
try manager.createDirectory(atPath: output, withIntermediateDirectories: true)
let size = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
NSColor(calibratedRed: 0.055, green: 0.055, blue: 0.065, alpha: 1).setFill()
NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: size, height: size), xRadius: 235, yRadius: 235).fill()
let red = NSColor(calibratedRed: 0.98, green: 0.16, blue: 0.20, alpha: 1)
let ring = NSBezierPath(ovalIn: NSRect(x: 225, y: 170, width: 574, height: 574))
ring.lineWidth = 78
red.setStroke()
ring.stroke()
NSColor(calibratedRed: 0.055, green: 0.055, blue: 0.065, alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: 432, y: 590, width: 160, height: 280)).fill()
let stem = NSBezierPath()
stem.move(to: NSPoint(x: 512, y: 880)); stem.line(to: NSPoint(x: 512, y: 520))
stem.lineCapStyle = .round; stem.lineWidth = 86; red.setStroke(); stem.stroke()
image.unlockFocus()
guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else { fatalError("Unable to render app icon") }
let source = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("rojo-icon-1024.png")
try png.write(to: source)
for s in [16, 32, 128, 256, 512] {
    let one = URL(fileURLWithPath: output).appendingPathComponent("icon_\(s)x\(s).png")
    let two = URL(fileURLWithPath: output).appendingPathComponent("icon_\(s)x\(s)@2x.png")
    for (url, pixels) in [(one, s), (two, s * 2)] {
        let task = Process(); task.executableURL = URL(fileURLWithPath: "/usr/bin/sips")
        task.arguments = ["-z", "\(pixels)", "\(pixels)", source.path, "--out", url.path]
        task.standardOutput = FileHandle.nullDevice; task.standardError = FileHandle.standardError
        try task.run(); task.waitUntilExit(); guard task.terminationStatus == 0 else { fatalError("sips failed") }
    }
}
try? manager.removeItem(at: source)
