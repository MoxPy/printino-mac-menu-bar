//
//  LabelRendering.swift
//  printino
//
//

import AppKit
import CoreGraphics
import CoreImage
import CoreText

struct LabelRenderer {
    static let printheadPx: Int = 96
    static let bytesPerRow: Int = 12

    private static let ciContext = CIContext()

    private struct RenderResult {
        let bitmap: Data
        let previewImage: NSImage
    }

    private struct Block {
        let width: CGFloat
        let height: CGFloat
        let draw: (CGContext, CGRect) -> Void
    }

    static func renderBitmap(for composition: LabelComposition) -> Data? {
        render(composition: composition)?.bitmap
    }

    static func renderPreviewImage(for composition: LabelComposition) -> NSImage? {
        render(composition: composition)?.previewImage
    }

    private static func render(composition: LabelComposition) -> RenderResult? {
        let margin = CGFloat(6)
        let spacing = CGFloat(8)
        let canvasHeight = printheadPx
        let contentOffset = composition.contentOffset

        let blocks = layoutBlocks(for: composition, maxHeight: CGFloat(canvasHeight) - margin * 2)
        let contentWidth = blocks.reduce(CGFloat(0)) { $0 + $1.width } + CGFloat(max(0, blocks.count - 1)) * spacing
        let canvasWidth = max(Int(ceil(CGFloat(composition.labelHeight))), Int(ceil(contentWidth + margin * 2)))

        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let context = CGContext(
            data: nil,
            width: canvasWidth,
            height: canvasHeight,
            bitsPerComponent: 8,
            bytesPerRow: canvasWidth,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return nil
        }

        context.setFillColor(gray: 1.0, alpha: 1.0)
        context.fill(CGRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight))

        let startX = max(margin, (CGFloat(canvasWidth) - contentWidth) / 2)
        var cursorX = startX + contentOffset.width

        for (index, block) in blocks.enumerated() {
            let rect = CGRect(
                x: cursorX,
                y: (CGFloat(canvasHeight) - block.height) / 2 - contentOffset.height,
                width: block.width,
                height: block.height
            )
            block.draw(context, rect)
            cursorX += block.width
            if index < blocks.count - 1 {
                cursorX += spacing
            }
        }

        guard let rawPixelData = context.data else { return nil }
        let pixelBuffer = rawPixelData.assumingMemoryBound(to: UInt8.self)

        let rotatedWidth = canvasHeight
        let rotatedHeight = canvasWidth
        var rotatedGray = Data(count: rotatedWidth * rotatedHeight)

        for srcY in 0..<canvasHeight {
            for srcX in 0..<canvasWidth {
                let pixelVal = pixelBuffer[srcY * canvasWidth + srcX]
                let dstX = srcY
                let dstY = canvasWidth - 1 - srcX
                rotatedGray[dstY * rotatedWidth + dstX] = pixelVal
            }
        }

        let bitmap = rotatedGray.withUnsafeBytes { buffer -> Data in
            guard let base = buffer.bindMemory(to: UInt8.self).baseAddress else {
                return Data()
            }
            return BitmapConverter.convert8BitGrayscaleTo1Bit(pixelBuffer: base, width: rotatedWidth, height: rotatedHeight)
        }

        guard let cgImage = context.makeImage() else { return nil }
        let preview = NSImage(cgImage: cgImage, size: NSSize(width: canvasWidth, height: canvasHeight))
        return RenderResult(bitmap: bitmap, previewImage: preview)
    }

    private static func layoutBlocks(for composition: LabelComposition, maxHeight: CGFloat) -> [Block] {
        var blocks: [Block] = []

        let text = composition.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            let font = NSFont.systemFont(ofSize: composition.fontSize, weight: .bold)
            let textSize = measuredTextSize(text, font: font, maxHeight: maxHeight)
            blocks.append(Block(width: textSize.width, height: textSize.height) { context, rect in
                drawText(text, font: font, in: rect, context: context)
            })
        }

        if let image = composition.image, image.size.width > 0, image.size.height > 0 {
            let imageSize = fittedSize(for: image.size, maxWidth: 56, maxHeight: maxHeight)
            blocks.append(Block(width: imageSize.width, height: imageSize.height) { context, rect in
                drawImage(image, in: rect, targetSize: imageSize, context: context)
            })
        }

        let qrText = composition.qrCodeText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !qrText.isEmpty {
            let qrSize = min(58, maxHeight)
            blocks.append(Block(width: qrSize, height: qrSize) { context, rect in
                drawQRCode(qrText, in: rect, side: qrSize, context: context)
            })
        }

        let barcodeText = composition.barcodeText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !barcodeText.isEmpty {
            let barcodeSize = barcodeIntrinsicSize(for: barcodeText, maxHeight: maxHeight)
            blocks.append(Block(width: barcodeSize.width, height: barcodeSize.height) { context, rect in
                drawBarcode(barcodeText, in: rect, context: context)
            })
        }

        return blocks
    }

    private static func measuredTextSize(_ text: String, font: NSFont, maxHeight: CGFloat) -> CGSize {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineBreakMode = .byClipping

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black,
            .paragraphStyle: paragraphStyle
        ]

        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let bounds = attributedString.boundingRect(
            with: CGSize(width: .greatestFiniteMagnitude, height: maxHeight),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )

        return CGSize(width: ceil(bounds.width) + 2, height: min(ceil(bounds.height) + 2, maxHeight))
    }

    private static func drawText(_ text: String, font: NSFont, in rect: CGRect, context: CGContext) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineBreakMode = .byClipping

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black,
            .paragraphStyle: paragraphStyle
        ]

        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
        let path = CGPath(rect: rect, transform: nil)
        let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: attributedString.length), path, nil)

        context.saveGState()
        context.setFillColor(gray: 0.0, alpha: 1.0)
        CTFrameDraw(frame, context)
        context.restoreGState()
    }

    private static func fittedSize(for size: CGSize, maxWidth: CGFloat, maxHeight: CGFloat) -> CGSize {
        guard size.width > 0, size.height > 0 else { return CGSize(width: maxWidth, height: maxHeight) }
        let ratio = min(maxWidth / size.width, maxHeight / size.height, 1)
        return CGSize(width: ceil(size.width * ratio), height: ceil(size.height * ratio))
    }

    private static func drawImage(_ image: NSImage, in rect: CGRect, targetSize: CGSize, context: CGContext) {
        var proposedRect = CGRect(origin: .zero, size: image.size)
        guard let cgImage = image.cgImage(forProposedRect: &proposedRect, context: nil, hints: nil) else { return }

        let origin = CGPoint(
            x: rect.midX - targetSize.width / 2,
            y: rect.midY - targetSize.height / 2
        )
        let targetRect = CGRect(origin: origin, size: targetSize)

        context.saveGState()
        context.interpolationQuality = .none
        context.draw(cgImage, in: targetRect)
        context.restoreGState()
    }

    private static func drawQRCode(_ text: String, in rect: CGRect, side: CGFloat, context: CGContext) {
        guard let data = text.data(using: .utf8),
              let filter = CIFilter(name: "CIQRCodeGenerator") else {
            return
        }

        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")

        guard let outputImage = filter.outputImage,
              let cgImage = ciContext.createCGImage(outputImage, from: outputImage.extent) else {
            return
        }

        let targetRect = CGRect(
            x: rect.midX - side / 2,
            y: rect.midY - side / 2,
            width: side,
            height: side
        )

        context.saveGState()
        context.interpolationQuality = .none
        context.draw(cgImage, in: targetRect)
        context.restoreGState()
    }

    private static func barcodeIntrinsicSize(for text: String, maxHeight: CGFloat) -> CGSize {
        guard let data = text.data(using: .ascii),
              let filter = CIFilter(name: "CICode128BarcodeGenerator") else {
            return CGSize(width: 90, height: min(28, maxHeight))
        }

        filter.setValue(data, forKey: "inputMessage")
        filter.setValue(0.0, forKey: "inputQuietSpace")

        guard let outputImage = filter.outputImage else {
            return CGSize(width: 90, height: min(28, maxHeight))
        }

        let height = min(28, maxHeight)
        let aspect = CGFloat(outputImage.extent.width / outputImage.extent.height)
        let width = max(90, ceil(height * aspect))
        return CGSize(width: width, height: height)
    }

    private static func drawBarcode(_ text: String, in rect: CGRect, context: CGContext) {
        guard let data = text.data(using: .ascii),
              let filter = CIFilter(name: "CICode128BarcodeGenerator") else {
            return
        }

        filter.setValue(data, forKey: "inputMessage")
        filter.setValue(0.0, forKey: "inputQuietSpace")

        guard let outputImage = filter.outputImage,
              let cgImage = ciContext.createCGImage(outputImage, from: outputImage.extent) else {
            return
        }

        context.saveGState()
        context.interpolationQuality = .none
        context.draw(cgImage, in: rect)
        context.restoreGState()
    }
}
