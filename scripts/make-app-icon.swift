// Draws the app icon, a TV remote on an indigo squircle, as a 1024 px PNG.
//   swift scripts/make-app-icon.swift <output.png>
// scripts/make-app-icon.sh turns it into Resources/AppIcon.icns.
import AppKit

let size: CGFloat = 1024
let output = URL(fileURLWithPath: CommandLine.arguments[1])

let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8, samplesPerPixel: 4,
    hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

func shadowed(_ blur: CGFloat, _ offset: CGFloat, _ alpha: CGFloat, draw: () -> Void) {
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowBlurRadius = blur
    shadow.shadowOffset = NSSize(width: 0, height: -offset)
    shadow.shadowColor = NSColor.black.withAlphaComponent(alpha)
    shadow.set()
    draw()
    NSGraphicsContext.restoreGraphicsState()
}

// Squircle background, inset like Apple's icon grid.
let tile = NSRect(x: 100, y: 100, width: 824, height: 824)
let tilePath = NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185)
shadowed(28, 12, 0.35) {
    color(0x4F46E5).setFill()
    tilePath.fill()
}
NSGradient(starting: color(0x6366F1), ending: color(0x312E81))!.draw(in: tilePath, angle: -90)

// Signal waves, top right: the remote talking to the TV.
NSGraphicsContext.saveGraphicsState()
tilePath.addClip()
for (index, radius) in [CGFloat(60), 105, 150].enumerated() {
    let wave = NSBezierPath()
    wave.appendArc(withCenter: NSPoint(x: 640, y: 700), radius: radius, startAngle: 10, endAngle: 80)
    wave.lineWidth = 26
    wave.lineCapStyle = .round
    color(0xFFFFFF, 0.85 - CGFloat(index) * 0.22).setStroke()
    wave.stroke()
}
NSGraphicsContext.restoreGraphicsState()

// The remote, tilted a little.
let transform = NSAffineTransform()
transform.translateX(by: 470, yBy: 480)
transform.rotate(byDegrees: -16)
transform.concat()

let body = NSRect(x: -140, y: -330, width: 280, height: 640)
let bodyPath = NSBezierPath(roundedRect: body, xRadius: 140, yRadius: 140)
shadowed(36, 20, 0.45) {
    color(0xE5E7EB).setFill()
    bodyPath.fill()
}
NSGradient(starting: color(0xFFFFFF), ending: color(0xD1D5DB))!.draw(in: bodyPath, angle: -90)

let dark = color(0x1F2937)

// D-pad ring with the OK button and four arrow notches.
let ringCenter = NSPoint(x: 0, y: 150)
NSBezierPath(ovalIn: NSRect(x: ringCenter.x - 105, y: ringCenter.y - 105, width: 210, height: 210)).fill(with: dark)
NSBezierPath(ovalIn: NSRect(x: ringCenter.x - 46, y: ringCenter.y - 46, width: 92, height: 92))
    .fill(with: color(0xF3F4F6))
for angle in stride(from: CGFloat(0), to: 360, by: 90) {
    let radians = angle * .pi / 180
    let point = NSPoint(x: ringCenter.x + cos(radians) * 76, y: ringCenter.y + sin(radians) * 76)
    NSBezierPath(ovalIn: NSRect(x: point.x - 9, y: point.y - 9, width: 18, height: 18))
        .fill(with: color(0x9CA3AF))
}

// Back and Home buttons.
for x in [CGFloat(-62), 62] {
    NSBezierPath(ovalIn: NSRect(x: x - 34, y: -40, width: 68, height: 68)).fill(with: dark)
}

// Volume rocker.
let rocker = NSBezierPath(roundedRect: NSRect(x: -34, y: -280, width: 68, height: 190), xRadius: 34, yRadius: 34)
rocker.fill(with: dark)
for y in [CGFloat(-125), -245] {
    NSBezierPath(rect: NSRect(x: -14, y: y - 4, width: 28, height: 8)).fill(with: color(0xF3F4F6))
}
NSBezierPath(rect: NSRect(x: -4, y: -139, width: 8, height: 28)).fill(with: color(0xF3F4F6))

// Power LED.
NSBezierPath(ovalIn: NSRect(x: -12, y: 266, width: 24, height: 24)).fill(with: color(0xEF4444))

extension NSBezierPath {
    func fill(with color: NSColor) {
        color.setFill()
        fill()
    }
}

NSGraphicsContext.current = nil
try bitmap.representation(using: .png, properties: [:])!.write(to: output)
print("Wrote \(output.path)")
