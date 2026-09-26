//
//  BitmapConverter.swift
//  printino
//
//

import Foundation

struct BitmapConverter {
    nonisolated static let printerWidth = 96
    nonisolated static let bytesPerRow = 12

    nonisolated static func convert8BitGrayscaleTo1Bit(pixelBuffer: UnsafePointer<UInt8>, width: Int, height: Int) -> Data {
        var bitmap = Data(count: bytesPerRow * height)

        for y in 0..<height {
            for x in 0..<width {
                let pixelVal = pixelBuffer[y * width + x]
                if pixelVal < 128 {
                    let byteIndex = y * bytesPerRow + (x / 8)
                    let bitOffset = 7 - (x % 8)
                    bitmap[byteIndex] |= (1 << bitOffset)
                }
            }
        }

        return bitmap
    }
}
