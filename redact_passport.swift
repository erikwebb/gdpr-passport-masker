import AppKit
import CoreText

// Secure Passport Redactor Engine
// Usage: redact_passport <inputPath> <outputPath> <layoutChoice> <hotelName>

guard CommandLine.arguments.count > 4 else {
    print("Usage: redact_passport <inputPath> <outputPath> <layoutChoice> <hotelName>")
    exit(1)
}

let inputPath = CommandLine.arguments[1]
let outputPath = CommandLine.arguments[2]
let layoutChoice = CommandLine.arguments[3]
let hotelName = CommandLine.arguments[4]

guard let image = NSImage(contentsOfFile: inputPath) else {
    print("Failed to load image: \(inputPath)")
    exit(1)
}

guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    print("Failed to get CGImage")
    exit(1)
}

let width = cgImage.width
let height = cgImage.height
let colorSpace = CGColorSpaceCreateDeviceRGB()

guard let context = CGContext(
    data: nil,
    width: width,
    height: height,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    print("Failed to create CGContext")
    exit(1)
}

// 1. Draw original image
let rect = CGRect(x: 0, y: 0, width: width, height: height)
context.draw(cgImage, in: rect)

// In top-down image space (0% = top, 100% = bottom):
// Option 1 (Photo Page Only):
//   - Black Box: Bottom 18% with inset gap
//   - Watermark: 18% to 75%
// Option 2 (Photo + Signature):
//   - Black Box: Bottom 8% with inset gap
//   - Watermark: 8% to 62.5%

let blackBoxPercent: Double
let wmMinYPercent: Double
let wmMaxYPercent: Double

if layoutChoice == "1" {
    blackBoxPercent = 0.18
    wmMinYPercent = 0.18
    wmMaxYPercent = 0.75
} else {
    blackBoxPercent = 0.08
    wmMinYPercent = 0.08
    wmMaxYPercent = 0.625
}

// 2. Draw solid black redaction bar with a small inset gap around edges
let insetX = max(10.0, Double(width) * 0.03)
let insetY = max(6.0, Double(height) * 0.015)
let barHeight = max(12.0, (Double(height) * blackBoxPercent) - (insetY * 0.5))

let blackBarRect = CGRect(
    x: insetX,
    y: insetY,
    width: Double(width) - (2 * insetX),
    height: barHeight
)

context.setFillColor(NSColor.black.cgColor)
context.fill(blackBarRect)

// 3. Draw Watermark in the specified Y range
let wmMinY = Double(height) * wmMinYPercent
let wmMaxY = Double(height) * wmMaxYPercent
let wmRect = CGRect(x: 0, y: wmMinY, width: Double(width), height: wmMaxY - wmMinY)

context.saveGState()
context.clip(to: wmRect)

let watermarkText = "FOR \(hotelName.uppercased()) CHECK-IN ONLY"

let fontSize = max(18.0, Double(width) / 20.0)
let font = NSFont.boldSystemFont(ofSize: fontSize)
let attributes: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: NSColor(calibratedRed: 0.85, green: 0.15, blue: 0.15, alpha: 0.45),
    .strokeColor: NSColor.black.withAlphaComponent(0.6),
    .strokeWidth: -2.0
]

let attributedString = NSAttributedString(string: watermarkText, attributes: attributes)
let line = CTLineCreateWithAttributedString(attributedString)
let textSize = attributedString.size()

context.translateBy(x: Double(width) / 2.0, y: (wmMinY + wmMaxY) / 2.0)
context.rotate(by: -22.0 * .pi / 180.0)

let stepX = textSize.width + 50.0
let stepY = textSize.height + 40.0

let diagonalLength = sqrt(Double(width * width + height * height))
let startX = -diagonalLength
let endX = diagonalLength
let startY = -diagonalLength
let endY = diagonalLength

var y = startY
var lineCount = 0
while y < endY {
    let offsetX = (lineCount % 2 == 0) ? 0.0 : (stepX / 2.0)
    var x = startX + offsetX
    while x < endX {
        context.textPosition = CGPoint(x: x, y: y)
        CTLineDraw(line, context)
        x += stepX
    }
    y += stepY
    lineCount += 1
}

context.restoreGState()

// 4. Save output image
guard let newCgImage = context.makeImage() else {
    print("Failed to create new CGImage")
    exit(1)
}

let newBitmap = NSBitmapImageRep(cgImage: newCgImage)
let fileExtension = (outputPath as NSString).pathExtension.lowercased()

var fileData: Data?
if fileExtension == "jpg" || fileExtension == "jpeg" {
    fileData = newBitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.9])
} else {
    fileData = newBitmap.representation(using: .png, properties: [:])
}

guard let data = fileData else {
    print("Failed to encode image data")
    exit(1)
}

try data.write(to: URL(fileURLWithPath: outputPath))
print("Successfully saved redacted and watermarked image to: \(outputPath)")