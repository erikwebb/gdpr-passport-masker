import AppKit
import CoreText
import Foundation
import ImageIO
import CoreGraphics

// Secure Passport Redactor Engine
// Usage: redact_passport <inputPath> <outputPath> <hotelName> [layoutChoice]

guard CommandLine.arguments.count >= 4 else {
    print("Usage: redact_passport <inputPath> <outputPath> <hotelName> [layoutChoice]")
    exit(1)
}

let inputPath = CommandLine.arguments[1]
let outputPath = CommandLine.arguments[2]

let hotelName: String
let layoutChoice: String

if CommandLine.arguments.count == 4 {
    hotelName = CommandLine.arguments[3]
    layoutChoice = "auto"
} else {
    let arg3 = CommandLine.arguments[3]
    let arg4 = CommandLine.arguments[4]
    if arg3 == "1" || arg3 == "2" || arg3 == "auto" {
        layoutChoice = arg3
        hotelName = arg4
    } else {
        hotelName = arg3
        layoutChoice = arg4
    }
}

// Helper function to load image or PDF while preserving full native resolution, orientation, and color space
func loadImage(from path: String) -> (image: CGImage, dpi: (Double, Double), colorSpace: CGColorSpace)? {
    let url = URL(fileURLWithPath: path)
    let ext = url.pathExtension.lowercased()

    if ext == "pdf" {
        guard let pdfDoc = CGPDFDocument(url as CFURL), let page = pdfDoc.page(at: 1) else {
            return nil
        }
        let box = page.getBoxRect(.mediaBox)
        let rotationAngle = page.rotationAngle
        // Render PDF at high-resolution 300 DPI print/scan quality
        let dpi: CGFloat = 300.0
        let scale = dpi / 72.0
        var width = Int(ceil(box.width * scale))
        var height = Int(ceil(box.height * scale))
        if rotationAngle == 90 || rotationAngle == 270 {
            swap(&width, &height)
        }

        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        ctx.setAllowsAntialiasing(true)
        ctx.setShouldAntialias(true)
        ctx.interpolationQuality = .high

        // White background for PDFs
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))

        ctx.saveGState()
        if rotationAngle != 0 {
            let rad = CGFloat(rotationAngle) * .pi / 180.0
            ctx.translateBy(x: CGFloat(width) / 2, y: CGFloat(height) / 2)
            ctx.rotate(by: rad)
            ctx.translateBy(x: -box.width * scale / 2, y: -box.height * scale / 2)
        }
        ctx.scaleBy(x: scale, y: scale)
        ctx.drawPDFPage(page)
        ctx.restoreGState()

        guard let cg = ctx.makeImage() else { return nil }
        return (cg, (Double(dpi), Double(dpi)), colorSpace)
    }

    guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }

    // Use thumbnail transform to automatically handle EXIF rotation without downsampling
    let options: [CFString: Any] = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceShouldCacheImmediately: true
    ]
    guard let cgImage = CGImageSourceCreateThumbnailAtIndex(src, 0, options as CFDictionary) else {
        guard let directImage = CGImageSourceCreateImageAtIndex(src, 0, [kCGImageSourceShouldCache: true] as CFDictionary) else {
            return nil
        }
        let colorSpace = directImage.colorSpace ?? (CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB())
        return (directImage, (72.0, 72.0), colorSpace)
    }

    var dpiX: Double = 72.0
    var dpiY: Double = 72.0
    if let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any] {
        if let dx = props[kCGImagePropertyDPIWidth] as? Double { dpiX = dx }
        if let dy = props[kCGImagePropertyDPIHeight] as? Double { dpiY = dy }
    }

    let colorSpace = cgImage.colorSpace ?? (CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB())
    return (cgImage, (dpiX, dpiY), colorSpace)
}

guard let (cgImage, dpi, colorSpace) = loadImage(from: inputPath) else {
    print("Failed to load image: \(inputPath)")
    exit(1)
}

let width = cgImage.width
let height = cgImage.height

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

context.setAllowsAntialiasing(true)
context.setShouldAntialias(true)
context.interpolationQuality = .high

// 1. Draw original image at exact native pixel resolution
let rect = CGRect(x: 0, y: 0, width: width, height: height)
context.draw(cgImage, in: rect)

// Determine spread layout (2-page vs 1-page):
// Aspect ratio > 1.15 indicates a 2-page spread (signature page top, photo page bottom)
// Single passport photo page is landscape (height / width ≈ 0.70 < 1.15)
let isSpread: Bool
if layoutChoice == "1" {
    isSpread = false
} else if layoutChoice == "2" {
    isSpread = true
} else {
    // "auto" or unspecified: autodetect based on aspect ratio
    isSpread = (Double(height) / Double(width) > 1.15)
}

let blackBoxPercent: Double
if isSpread {
    // 2-page spread: MRZ occupies bottom ~8-10% of total image
    blackBoxPercent = 0.10
} else {
    // Single photo page: MRZ occupies bottom ~18% of total image
    blackBoxPercent = 0.18
}

// 2. Draw solid black redaction bar with proportional margin gap
let insetX = max(4.0, Double(width) * 0.03)
let insetY = max(3.0, Double(height) * 0.015)
let barHeight = max(8.0, (Double(height) * blackBoxPercent) - (insetY * 0.5))

let blackBarRect = CGRect(
    x: insetX,
    y: insetY,
    width: Double(width) - (2 * insetX),
    height: barHeight
)

context.setFillColor(NSColor.black.cgColor)
context.fill(blackBarRect)

// 3. Draw Watermark
// OCR-friendly styling:
// - Keep document title ("PASSPORT") and country header ("UNITED STATES OF AMERICA") clear
// - Use soft translucent red without harsh black stroke to avoid interfering with OCR
// - Wide line spacing to protect data without creating an impenetrable wall of text
let watermarkText = "FOR \(hotelName.uppercased()) CHECK-IN ONLY"

let fontSize = max(14.0, Double(width) / 24.0)
let font = NSFont.boldSystemFont(ofSize: fontSize)
let attributes: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: NSColor(calibratedRed: 0.85, green: 0.15, blue: 0.15, alpha: 0.36),
    .strokeColor: NSColor(calibratedRed: 0.65, green: 0.10, blue: 0.10, alpha: 0.40),
    .strokeWidth: -1.0
]

let attributedString = NSAttributedString(string: watermarkText, attributes: attributes)
let line = CTLineCreateWithAttributedString(attributedString)
let textSize = attributedString.size()

let stepX = textSize.width + 100.0
let diagonalLength = sqrt(Double(width * width + height * height))

func drawWatermarkLines(in clipRect: CGRect, verticalStep: Double) {
    context.saveGState()
    context.clip(to: clipRect)
    context.translateBy(x: clipRect.midX, y: clipRect.midY)
    context.rotate(by: -20.0 * .pi / 180.0)

    var y = -diagonalLength
    var lineCount = 0
    while y < diagonalLength {
        let offsetX = (lineCount % 2 == 0) ? 0.0 : (stepX / 2.0)
        var x = -diagonalLength + offsetX
        while x < diagonalLength {
            context.textPosition = CGPoint(x: x, y: y)
            CTLineDraw(line, context)
            x += stepX
        }
        y += verticalStep
        lineCount += 1
    }
    context.restoreGState()
}

if isSpread {
    // 2-page spread:
    // Zone A (Photo & personal data): 10% to 43% (keeps header at 45%-52% clear)
    let photoMinY = Double(height) * 0.10
    let photoMaxY = Double(height) * 0.43
    let photoRect = CGRect(x: 0, y: photoMinY, width: Double(width), height: photoMaxY - photoMinY)
    drawWatermarkLines(in: photoRect, verticalStep: Double(height) * 0.14)

    // Zone B (Signature & upper page): 58% to 82%
    let sigMinY = Double(height) * 0.58
    let sigMaxY = Double(height) * 0.82
    let sigRect = CGRect(x: 0, y: sigMinY, width: Double(width), height: sigMaxY - sigMinY)
    drawWatermarkLines(in: sigRect, verticalStep: Double(height) * 0.14)
} else {
    // Single page: 18% to 65% (keeps top passport header clear)
    let wmMinY = Double(height) * 0.18
    let wmMaxY = Double(height) * 0.65
    let wmRect = CGRect(x: 0, y: wmMinY, width: Double(width), height: wmMaxY - wmMinY)
    drawWatermarkLines(in: wmRect, verticalStep: Double(height) * 0.18)
}

// 4. Save output image maintaining resolution and metadata
guard let newCgImage = context.makeImage() else {
    print("Failed to create new CGImage")
    exit(1)
}

let outUrl = URL(fileURLWithPath: outputPath)
let fileExtension = outUrl.pathExtension.lowercased()

if fileExtension == "pdf" {
    let pdfData = NSMutableData()
    let ptWidth = Double(width) * 72.0 / dpi.0
    let ptHeight = Double(height) * 72.0 / dpi.1
    var mediaBox = CGRect(x: 0, y: 0, width: ptWidth, height: ptHeight)
    guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
          let pdfCtx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
        print("Failed to create PDF context")
        exit(1)
    }
    pdfCtx.beginPage(mediaBox: &mediaBox)
    pdfCtx.draw(newCgImage, in: mediaBox)
    pdfCtx.endPage()
    pdfCtx.closePDF()
    do {
        try (pdfData as Data).write(to: outUrl)
        print("Successfully saved redacted and watermarked image to: \(outputPath)")
    } catch {
        print("Failed to write PDF: \(error)")
        exit(1)
    }
} else {
    let uti: CFString
    switch fileExtension {
    case "jpg", "jpeg":
        uti = "public.jpeg" as CFString
    case "heic", "heif":
        uti = "public.heic" as CFString
    case "tiff", "tif":
        uti = "public.tiff" as CFString
    default:
        uti = "public.png" as CFString
    }

    guard let dest = CGImageDestinationCreateWithURL(outUrl as CFURL, uti, 1, nil) else {
        print("Failed to create CGImageDestination")
        exit(1)
    }

    var properties: [CFString: Any] = [
        kCGImagePropertyDPIWidth: dpi.0,
        kCGImagePropertyDPIHeight: dpi.1
    ]
    if fileExtension == "jpg" || fileExtension == "jpeg" {
        properties[kCGImageDestinationLossyCompressionQuality] = 0.95
    }

    CGImageDestinationAddImage(dest, newCgImage, properties as CFDictionary)
    if CGImageDestinationFinalize(dest) {
        print("Successfully saved redacted and watermarked image to: \(outputPath)")
    } else {
        print("Failed to encode and save image data")
        exit(1)
    }
}
