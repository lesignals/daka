import CoreBluetooth
import Foundation

struct BluetoothDeviceOption: Identifiable, Equatable {
    let identifier: String
    let name: String
    let rssi: Int
    let lastSeenAt: Date

    var id: String { identifier }

    var displayTitle: String {
        "\(name) (\(rssi) dBm)"
    }
}

final class BluetoothDeviceScanner: NSObject, CBCentralManagerDelegate {
    static let shared = BluetoothDeviceScanner()

    private struct DeviceRecord {
        var identifier: String
        var name: String
        var samples: [Int]
        var lastSeenAt: Date

        var smoothedRSSI: Int {
            let sorted = samples.sorted()
            return sorted[sorted.count / 2]
        }
    }

    private let bluetoothQueue = DispatchQueue(
        label: "local.daka.menu.bluetooth",
        qos: .utility
    )
    private let stateLock = NSLock()
    private var records: [String: DeviceRecord] = [:]
    private var monitoringEnabled = false
    private var discoveryGeneration = 0
    private var scanRequested = false
    private var centralManager: CBCentralManager?

    private override init() {
        super.init()
    }

    func setMonitoringEnabled(_ enabled: Bool) {
        bluetoothQueue.async { [weak self] in
            guard let self else {
                return
            }
            self.monitoringEnabled = enabled
            if enabled {
                self.startScanningIfPossible()
            } else if self.discoveryGeneration == 0 {
                self.stopScanning()
            }
        }
    }

    func discover(
        for duration: TimeInterval = 4,
        completion: @escaping ([BluetoothDeviceOption]) -> Void
    ) {
        bluetoothQueue.async { [weak self] in
            guard let self else {
                DispatchQueue.main.async {
                    completion([])
                }
                return
            }

            self.discoveryGeneration += 1
            let generation = self.discoveryGeneration
            self.startScanningIfPossible()

            self.bluetoothQueue.asyncAfter(deadline: .now() + duration) {
                let options = self.availableDevices(maxAge: max(15, duration + 2))
                if generation == self.discoveryGeneration {
                    self.discoveryGeneration = 0
                    if !self.monitoringEnabled {
                        self.stopScanning()
                    }
                }
                DispatchQueue.main.async {
                    completion(options)
                }
            }
        }
    }

    func signal(
        for identifier: String,
        maxAge: TimeInterval = 30,
        waitUpTo: TimeInterval = 2
    ) -> Int? {
        startScanning()

        let deadline = Date().addingTimeInterval(waitUpTo)
        repeat {
            if let signal = recentSignal(for: identifier, maxAge: maxAge) {
                return signal
            }
            Thread.sleep(forTimeInterval: 0.1)
        } while Date() < deadline

        return recentSignal(for: identifier, maxAge: maxAge)
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn, scanRequested || monitoringEnabled || discoveryGeneration > 0 {
            startScanningIfPossible()
        } else if central.state != .poweredOn {
            stopScanning()
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let rssi = RSSI.intValue
        guard rssi != 127, (-127 ... 20).contains(rssi) else {
            return
        }

        let identifier = peripheral.identifier.uuidString
        let advertisedName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let name = nonempty(advertisedName)
            ?? nonempty(peripheral.name)
            ?? "未命名设备"
        let now = Date()

        stateLock.lock()
        var record = records[identifier] ?? DeviceRecord(
            identifier: identifier,
            name: name,
            samples: [],
            lastSeenAt: now
        )
        record.name = name
        record.samples.append(rssi)
        record.samples = Array(record.samples.suffix(5))
        record.lastSeenAt = now
        records[identifier] = record
        stateLock.unlock()
    }

    private func startScanning() {
        bluetoothQueue.async { [weak self] in
            self?.startScanningIfPossible()
        }
    }

    private func startScanningIfPossible() {
        scanRequested = true
        let manager = bluetoothManager()
        guard manager.state == .poweredOn, !manager.isScanning else {
            return
        }
        manager.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
    }

    private func stopScanning() {
        scanRequested = false
        if let centralManager, centralManager.isScanning {
            centralManager.stopScan()
        }
    }

    private func bluetoothManager() -> CBCentralManager {
        if let centralManager {
            return centralManager
        }
        let manager = CBCentralManager(
            delegate: self,
            queue: bluetoothQueue,
            options: [CBCentralManagerOptionShowPowerAlertKey: false]
        )
        centralManager = manager
        return manager
    }

    private func recentSignal(
        for identifier: String,
        maxAge: TimeInterval
    ) -> Int? {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard
            let record = records[identifier],
            Date().timeIntervalSince(record.lastSeenAt) <= maxAge
        else {
            return nil
        }
        return record.smoothedRSSI
    }

    private func availableDevices(maxAge: TimeInterval) -> [BluetoothDeviceOption] {
        let cutoff = Date().addingTimeInterval(-maxAge)
        stateLock.lock()
        let options = records.values.compactMap { record -> BluetoothDeviceOption? in
            guard record.lastSeenAt >= cutoff else {
                return nil
            }
            return BluetoothDeviceOption(
                identifier: record.identifier,
                name: record.name,
                rssi: record.smoothedRSSI,
                lastSeenAt: record.lastSeenAt
            )
        }
        stateLock.unlock()

        return options.sorted {
            if $0.rssi != $1.rssi {
                return $0.rssi > $1.rssi
            }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    private func nonempty(_ value: String?) -> String? {
        guard
            let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
            !value.isEmpty
        else {
            return nil
        }
        return value
    }
}
