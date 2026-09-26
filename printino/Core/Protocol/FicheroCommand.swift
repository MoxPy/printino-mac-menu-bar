//
//  FicheroCommand.swift
//  printino
//
//

import Foundation

enum PrintDensity: UInt8 {
    case light = 0x00
    case medium = 0x01
    case thick = 0x02
}

enum PaperType: UInt8 {
    case gap = 0x00
    case blackMark = 0x01
    case continuous = 0x02
}

struct PrinterStatus: OptionSet, Sendable {
    let rawValue: UInt8

    static let printing    = PrinterStatus(rawValue: 1 << 0)
    static let coverOpen   = PrinterStatus(rawValue: 1 << 1)
    static let outOfPaper  = PrinterStatus(rawValue: 1 << 2)
    static let lowBattery  = PrinterStatus(rawValue: 1 << 3)
    static let overheated1 = PrinterStatus(rawValue: 1 << 4)
    static let charging    = PrinterStatus(rawValue: 1 << 5)
    static let overheated2 = PrinterStatus(rawValue: 1 << 6)
}

enum FicheroCommand {
    nonisolated static let wakeUp = Data(repeating: 0x00, count: 12)
    nonisolated static let enablePrinterAiYin = Data([0x10, 0xFF, 0xFE, 0x01])
    nonisolated static let stopPrinterAiYin = Data([0x10, 0xFF, 0xFE, 0x45])
    nonisolated static let formFeed = Data([0x1D, 0x0C])

    nonisolated static let getModel = Data([0x10, 0xFF, 0x20, 0xF0])
    nonisolated static let getFirmware = Data([0x10, 0xFF, 0x20, 0xF1])
    nonisolated static let getBattery = Data([0x10, 0xFF, 0x50, 0xF1])
    nonisolated static let getStatus = Data([0x10, 0xFF, 0x40])
    nonisolated static let getAllInfo = Data([0x10, 0xFF, 0x70])

    nonisolated static func setDensity(_ density: PrintDensity) -> Data {
        Data([0x10, 0xFF, 0x10, 0x00, density.rawValue])
    }

    nonisolated static func setPaperType(_ type: PaperType) -> Data {
        Data([0x10, 0xFF, 0x84, type.rawValue])
    }

    nonisolated static func feedForward(dots: UInt8) -> Data {
        Data([0x1B, 0x4A, dots])
    }

    nonisolated static func rasterHeader(bytesPerRow: UInt16, height: UInt16) -> Data {
        let xL = UInt8(bytesPerRow & 0xFF)
        let xH = UInt8((bytesPerRow >> 8) & 0xFF)
        let yL = UInt8(height & 0xFF)
        let yH = UInt8((height >> 8) & 0xFF)
        return Data([0x1D, 0x76, 0x30, 0x00, xL, xH, yL, yH])
    }
}
