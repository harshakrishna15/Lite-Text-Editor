import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
let resources = root.appendingPathComponent("Sources/LiteTextEditor/Resources", isDirectory: true)

struct IconRepresentation {
    let type: String
    let pixels: Int
}

let representations = [
    IconRepresentation(type: "icp4", pixels: 16),
    IconRepresentation(type: "icp5", pixels: 32),
    IconRepresentation(type: "ic07", pixels: 128),
    IconRepresentation(type: "ic08", pixels: 256),
    IconRepresentation(type: "ic09", pixels: 512),
    IconRepresentation(type: "ic10", pixels: 1024),
    IconRepresentation(type: "ic11", pixels: 32),
    IconRepresentation(type: "ic12", pixels: 64),
    IconRepresentation(type: "ic13", pixels: 256),
    IconRepresentation(type: "ic14", pixels: 512)
]

func roundedRect(_ rect: NSRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

func drawText(_ text: String, in rect: NSRect, size: CGFloat, weight: NSFont.Weight, color: NSColor) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center

    let font = NSFont.systemFont(ofSize: size, weight: weight)
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: paragraph
    ]
    let attributed = NSAttributedString(string: text, attributes: attributes)
    let measured = attributed.boundingRect(
        with: rect.size,
        options: [.usesLineFragmentOrigin, .usesFontLeading]
    )
    let textRect = NSRect(
        x: rect.minX,
        y: rect.midY - measured.height / 2,
        width: rect.width,
        height: measured.height
    )
    attributed.draw(in: textRect)
}

func drawLine(from start: NSPoint, to end: NSPoint, width: CGFloat, color: NSColor) {
    let path = NSBezierPath()
    path.move(to: start)
    path.line(to: end)
    path.lineWidth = width
    path.lineCapStyle = .round
    color.setStroke()
    path.stroke()
}

func drawIcon() {
    let canvas = NSRect(x: 0, y: 0, width: 1024, height: 1024)
    NSColor.clear.setFill()
    canvas.fill()

    let baseRect = NSRect(x: 54, y: 54, width: 916, height: 916)
    let basePath = roundedRect(baseRect, radius: 210)

    let baseShadow = NSShadow()
    baseShadow.shadowColor = NSColor.black.withAlphaComponent(0.14)
    baseShadow.shadowOffset = NSSize(width: 0, height: -18)
    baseShadow.shadowBlurRadius = 28
    NSGraphicsContext.saveGraphicsState()
    baseShadow.set()
    NSColor.white.setFill()
    basePath.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSColor(calibratedWhite: 0.88, alpha: 1).setStroke()
    basePath.lineWidth = 5
    basePath.stroke()

    let documentRect = NSRect(x: 254, y: 168, width: 516, height: 688)
    let documentPath = roundedRect(documentRect, radius: 52)
    let documentShadow = NSShadow()
    documentShadow.shadowColor = NSColor.black.withAlphaComponent(0.12)
    documentShadow.shadowOffset = NSSize(width: 0, height: -10)
    documentShadow.shadowBlurRadius = 16
    NSGraphicsContext.saveGraphicsState()
    documentShadow.set()
    NSColor.white.setFill()
    documentPath.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSColor.black.setStroke()
    documentPath.lineWidth = 18
    documentPath.stroke()

    let fold = NSBezierPath()
    fold.move(to: NSPoint(x: 636, y: 856))
    fold.line(to: NSPoint(x: 770, y: 722))
    fold.line(to: NSPoint(x: 636, y: 722))
    fold.close()
    NSColor.white.setFill()
    fold.fill()

    NSColor.black.setStroke()
    fold.lineWidth = 14
    fold.stroke()

    drawLine(
        from: NSPoint(x: 330, y: 662),
        to: NSPoint(x: 574, y: 662),
        width: 16,
        color: NSColor.black.withAlphaComponent(0.42)
    )

    drawText(
        "LTE",
        in: NSRect(x: 288, y: 388, width: 448, height: 190),
        size: 168,
        weight: .heavy,
        color: NSColor.black
    )

    drawLine(
        from: NSPoint(x: 330, y: 332),
        to: NSPoint(x: 692, y: 332),
        width: 18,
        color: NSColor.black.withAlphaComponent(0.36)
    )
    drawLine(
        from: NSPoint(x: 330, y: 284),
        to: NSPoint(x: 622, y: 284),
        width: 18,
        color: NSColor.black.withAlphaComponent(0.28)
    )
}

func renderIcon(pixels: Int) throws -> Data {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: NSColorSpaceName.deviceRGB,
        bitmapFormat: [],
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw NSError(domain: "IconGeneration", code: 1)
    }

    rep.size = NSSize(width: pixels, height: pixels)

    guard let context = NSGraphicsContext(bitmapImageRep: rep) else {
        throw NSError(domain: "IconGeneration", code: 2)
    }

    let previousContext = NSGraphicsContext.current
    NSGraphicsContext.current = context
    NSGraphicsContext.saveGraphicsState()
    context.imageInterpolation = NSImageInterpolation.high
    let scale = CGFloat(pixels) / 1024
    let transform = NSAffineTransform()
    transform.scale(by: scale)
    transform.concat()
    drawIcon()
    NSGraphicsContext.restoreGraphicsState()
    NSGraphicsContext.current = previousContext

    guard let data = rep.representation(using: NSBitmapImageRep.FileType.png, properties: [:]) else {
        throw NSError(domain: "IconGeneration", code: 3)
    }

    return data
}

func encodedUInt32(_ value: UInt32) -> Data {
    var value = value.bigEndian
    return Data(bytes: &value, count: MemoryLayout<UInt32>.size)
}

func icnsChunk(type: String, data: Data) throws -> Data {
    guard let typeData = type.data(using: .ascii), typeData.count == 4 else {
        throw NSError(domain: "IconGeneration", code: 4)
    }
    guard data.count <= Int(UInt32.max) - 8 else {
        throw NSError(domain: "IconGeneration", code: 5)
    }

    var chunk = Data()
    chunk.append(typeData)
    chunk.append(encodedUInt32(UInt32(data.count + 8)))
    chunk.append(data)
    return chunk
}

var chunks = Data()
var renderedImages: [Int: Data] = [:]

for representation in representations {
    let imageData = try renderedImages[representation.pixels] ?? renderIcon(pixels: representation.pixels)
    renderedImages[representation.pixels] = imageData
    chunks.append(try icnsChunk(type: representation.type, data: imageData))
}

var iconData = Data("icns".utf8)
iconData.append(encodedUInt32(UInt32(chunks.count + 8)))
iconData.append(chunks)
try iconData.write(
    to: resources.appendingPathComponent("AppIcon.icns"),
    options: .atomic
)

print("Generated AppIcon.icns")
