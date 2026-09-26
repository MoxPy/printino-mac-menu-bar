//
//  BLEManager.swift
//  printino
//
//

import Foundation
@preconcurrency import CoreBluetooth

@Observable
@MainActor
class PrinterManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    var isConnected = false
    var isScanning = false
    var statusMessage = "Disconnesso"
    var batteryLevel: Int? = nil
    var printerModel: String? = nil

    private var centralManager: CBCentralManager!
    private var printerPeripheral: CBPeripheral?
    private var writeCharacteristic: CBCharacteristic?
    private var notifyCharacteristic: CBCharacteristic?

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func startScan() {
        guard centralManager.state == .poweredOn else {
            print("[BLE] Bluetooth non attivo (stato: \(centralManager.state.rawValue))")
            statusMessage = "Bluetooth non attivo"
            return
        }

        isScanning = true
        statusMessage = "Scansione in corso..."
        print("=== AVVIO SCANSIONE DISPOSITIVI BLE ===")

        centralManager.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
    }

    func disconnect() {
        if let peripheral = printerPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
    }

    private func connectTo(peripheral: CBPeripheral, displayName: String) {
        printerPeripheral = peripheral
        printerModel = displayName
        centralManager.stopScan()
        isScanning = false
        statusMessage = "Connessione a \(displayName)..."
        print("[BLE] Tentativo di connessione a: \(displayName)")
        centralManager.connect(peripheral, options: nil)
    }

    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            switch central.state {
            case .poweredOn:
                print("[BLE] Modulo Bluetooth: ATTIVO (poweredOn)")
                self.statusMessage = "Bluetooth pronto"
            case .unauthorized:
                print("[BLE] Modulo Bluetooth: NON AUTORIZZATO (permesso negato)")
                self.statusMessage = "Permesso Bluetooth negato"
            case .poweredOff:
                print("[BLE] Modulo Bluetooth: SPENTO")
                self.statusMessage = "Bluetooth spento"
                self.isConnected = false
            case .resetting:
                print("[BLE] Modulo Bluetooth: RESETTING")
            case .unsupported:
                print("[BLE] Modulo Bluetooth: NON SUPPORTATO")
            default:
                print("[BLE] Modulo Bluetooth stato: \(central.state.rawValue)")
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let advertisedName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let peripheralName = peripheral.name
        let displayName = peripheralName ?? advertisedName ?? "Nome non presente"
        let uuid = peripheral.identifier.uuidString

        print("[BLE DISPOSITIVO] Nome: \"\(displayName)\" | RSSI: \(RSSI) dBm | UUID: \(uuid)")

        let nameToCheck = displayName.uppercased()
        let matchesPrefix = BLEConstants.devicePrefixes.contains { nameToCheck.hasPrefix($0.uppercased()) }

        if matchesPrefix {
            print(">>> TROVATA STAMPANTE TARGET: \(displayName) [\(uuid)] <<<")
            Task { @MainActor in
                self.connectTo(peripheral: peripheral, displayName: displayName)
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            print("[BLE] Connesso con successo a \(peripheral.name ?? "dispositivo")")
            self.printerPeripheral = peripheral
            peripheral.delegate = self
            self.statusMessage = "Ricerca servizi..."
            peripheral.discoverServices(nil)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            print("[BLE] Disconnesso da periferica")
            self.isConnected = false
            self.writeCharacteristic = nil
            self.notifyCharacteristic = nil
            self.printerModel = nil
            self.statusMessage = "Disconnesso"
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            print("[BLE SERVIZIO] \(service.uuid)")
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for char in characteristics {
            print("[BLE CARATTERISTICA] \(char.uuid) per servizio \(service.uuid)")
            if char.uuid == BLEConstants.notifyChar2af0 || char.uuid == BLEConstants.notifyCharff01 {
                peripheral.setNotifyValue(true, for: char)
                Task { @MainActor in
                    self.notifyCharacteristic = char
                }
            }

            if char.uuid == BLEConstants.writeChar2af1 || char.uuid == BLEConstants.writeCharff02 {
                Task { @MainActor in
                    self.writeCharacteristic = char
                    self.isConnected = true
                    self.statusMessage = "Pronta per stampare"
                    print("[BLE] Canale di scrittura pronto: \(char.uuid)")
                    self.queryModel()
                    self.queryBattery()
                }
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else { return }
        Task { @MainActor in
            if let decodedModel = Self.decodePrintableString(from: data) {
                self.printerModel = decodedModel
            }
            if data.count >= 2 {
                self.batteryLevel = Int(data[data.count - 1])
            }
        }
    }

    func queryModel() {
        sendRaw(FicheroCommand.getModel)
    }

    func queryBattery() {
        sendRaw(FicheroCommand.getBattery)
    }

    func sendRaw(_ data: Data) {
        guard let peripheral = printerPeripheral, let char = writeCharacteristic else { return }
        peripheral.writeValue(data, for: char, type: .withoutResponse)
    }

    func printPipeline(bitmap: Data, rows: Int, density: PrintDensity) {
        guard let peripheral = printerPeripheral, let char = writeCharacteristic else {
            statusMessage = "Nessuna stampante connessa"
            return
        }

        statusMessage = "Stampa in corso..."

        Task.detached(priority: .userInitiated) {
            func writeCmd(_ data: Data) {
                peripheral.writeValue(data, for: char, type: .withoutResponse)
            }

            writeCmd(FicheroCommand.setDensity(density))
            try? await Task.sleep(nanoseconds: BLEConstants.delayAfterDensity)

            writeCmd(FicheroCommand.setPaperType(.gap))
            try? await Task.sleep(nanoseconds: BLEConstants.delayCommandGap)

            writeCmd(FicheroCommand.wakeUp)
            try? await Task.sleep(nanoseconds: BLEConstants.delayCommandGap)

            writeCmd(FicheroCommand.enablePrinterAiYin)
            try? await Task.sleep(nanoseconds: BLEConstants.delayCommandGap)

            let header = FicheroCommand.rasterHeader(
                bytesPerRow: UInt16(BitmapConverter.bytesPerRow),
                height: UInt16(rows)
            )

            var rasterPacket = Data()
            rasterPacket.append(header)
            rasterPacket.append(bitmap)

            var offset = 0
            while offset < rasterPacket.count {
                let end = min(offset + BLEConstants.chunkSizeBLE, rasterPacket.count)
                let chunk = rasterPacket.subdata(in: offset..<end)
                peripheral.writeValue(chunk, for: char, type: .withoutResponse)
                try? await Task.sleep(nanoseconds: BLEConstants.delayChunkGap)
                offset += BLEConstants.chunkSizeBLE
            }

            try? await Task.sleep(nanoseconds: BLEConstants.delayRasterSettle)

            writeCmd(FicheroCommand.formFeed)
            try? await Task.sleep(nanoseconds: BLEConstants.delayAfterFeed)

            writeCmd(FicheroCommand.stopPrinterAiYin)

            await MainActor.run {
                self.statusMessage = "Stampa completata"
            }
        }
    }

    private static func decodePrintableString(from data: Data) -> String? {
        let printableScalars = data.compactMap { byte -> Character? in
            guard (32...126).contains(byte) else { return nil }
            return Character(UnicodeScalar(byte))
        }

        let text = String(printableScalars).trimmingCharacters(in: .whitespacesAndNewlines)
        return text.count >= 3 ? text : nil
    }
}
