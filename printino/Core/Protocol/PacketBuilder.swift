//
//  PacketBuilder.swift
//  printino
//
//

import Foundation

struct PacketBuilder {
    static func build(
        bitmap: Data,
        height: Int,
        density: PrintDensity = .medium,
        paperType: PaperType = .gap
    ) -> Data {
        var payload = Data()

        payload.append(FicheroCommand.setDensity(density))
        payload.append(FicheroCommand.setPaperType(paperType))
        payload.append(FicheroCommand.wakeUp)
        payload.append(FicheroCommand.enablePrinterAiYin)

        let header = FicheroCommand.rasterHeader(
            bytesPerRow: UInt16(BitmapConverter.bytesPerRow),
            height: UInt16(height)
        )
        payload.append(header)
        payload.append(bitmap)
        payload.append(FicheroCommand.formFeed)
        payload.append(FicheroCommand.stopPrinterAiYin)

        return payload
    }
}
