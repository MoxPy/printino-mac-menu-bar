//
//  BLEConstants.swift
//  printino
//
//

import Foundation
@preconcurrency import CoreBluetooth

enum BLEConstants {
    nonisolated static let devicePrefixes = ["FICHERO", "D11s_"]

    nonisolated static let serviceUUID18f0 = CBUUID(string: "000018f0-0000-1000-8000-00805f9b34fb")
    nonisolated static let writeChar2af1   = CBUUID(string: "00002af1-0000-1000-8000-00805f9b34fb")
    nonisolated static let notifyChar2af0  = CBUUID(string: "00002af0-0000-1000-8000-00805f9b34fb")

    nonisolated static let serviceUUIDff00 = CBUUID(string: "0000ff00-0000-1000-8000-00805f9b34fb")
    nonisolated static let writeCharff02   = CBUUID(string: "ff02")
    nonisolated static let notifyCharff01  = CBUUID(string: "ff01")

    nonisolated static let allServices = [serviceUUID18f0, serviceUUIDff00]

    nonisolated static let chunkSizeBLE = 200
    nonisolated static let delayChunkGap: UInt64 = 20_000_000
    nonisolated static let delayCommandGap: UInt64 = 50_000_000
    nonisolated static let delayAfterDensity: UInt64 = 100_000_000
    nonisolated static let delayRasterSettle: UInt64 = 500_000_000
    nonisolated static let delayAfterFeed: UInt64 = 300_000_000
}
