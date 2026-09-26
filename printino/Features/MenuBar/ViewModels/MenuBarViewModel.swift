//
//  MenuBarViewModel.swift
//  printino
//
//

import AppKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers

@Observable
@MainActor
class MenuBarViewModel {
    var labelText = ""
    var qrCodeText = ""
    var barcodeText = ""
    var fontSize: Double = 30
    var labelHeight: Double = 240
    var density: PrintDensity = .thick
    var contentOffset: CGSize = .zero
    var selectedImage: NSImage?
    var selectedImageName: String?

    let printerManager: PrinterManager

    let quickEmojis = ["😀", "✨", "🔥", "💡", "📦", "✅"]

    init(printerManager: PrinterManager) {
        self.printerManager = printerManager
    }

    var isConnected: Bool {
        printerManager.isConnected
    }

    var isScanning: Bool {
        printerManager.isScanning
    }

    var statusMessage: String {
        printerManager.statusMessage
    }

    var batteryLevel: Int? {
        printerManager.batteryLevel
    }

    var printerModel: String {
        printerManager.printerModel ?? "Stampante non identificata"
    }

    var labelSizeDescription: String {
        "Misura standard: 96 × \(Int(labelHeight)) px"
    }

    var previewImage: NSImage? {
        LabelRenderer.renderPreviewImage(for: currentComposition)
    }

    var canPrint: Bool {
        isConnected && hasRenderableContent
    }

    var hasRenderableContent: Bool {
        !labelText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !qrCodeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !barcodeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || selectedImage != nil
    }

    var currentComposition: LabelComposition {
        LabelComposition(
            text: labelText,
            fontSize: CGFloat(fontSize),
            labelHeight: Int(labelHeight),
            image: selectedImage,
            qrCodeText: qrCodeText,
            barcodeText: barcodeText,
            contentOffset: contentOffset
        )
    }

    func scan() {
        printerManager.startScan()
    }

    func disconnect() {
        printerManager.disconnect()
    }

    func resetContentOffset() {
        contentOffset = .zero
    }

    func insertEmoji(_ emoji: String) {
        labelText += emoji
    }

    func pickImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        guard panel.runModal() == .OK, let url = panel.url, let image = NSImage(contentsOf: url) else {
            return
        }

        selectedImage = image
        selectedImageName = url.lastPathComponent
    }

    func removeImage() {
        selectedImage = nil
        selectedImageName = nil
    }

    func printCurrentLabel() {
        guard let bitmap = LabelRenderer.renderBitmap(for: currentComposition) else {
            printerManager.statusMessage = "Impossibile generare l'anteprima di stampa"
            return
        }
        let rows = bitmap.count / BitmapConverter.bytesPerRow
        printerManager.printPipeline(bitmap: bitmap, rows: rows, density: density)
    }
}
