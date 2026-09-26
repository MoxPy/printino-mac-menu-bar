//
//  LabelComposition.swift
//  printino
//
//

import AppKit
import Foundation

struct LabelComposition {
    var text: String = ""
    var fontSize: CGFloat = 30
    var labelHeight: Int = 240
    var image: NSImage? = nil
    var qrCodeText: String = ""
    var barcodeText: String = ""
    var contentOffset: CGSize = .zero
}
