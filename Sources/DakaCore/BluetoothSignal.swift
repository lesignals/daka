import Foundation

public struct BluetoothSignalSampleWindow {
    private struct Sample {
        let rssi: Int
        let observedAt: Date
    }

    private let maximumSampleCount: Int
    private let sampleLifetime: TimeInterval
    private var samples: [Sample] = []

    public init(
        maximumSampleCount: Int = 5,
        sampleLifetime: TimeInterval = 30
    ) {
        self.maximumSampleCount = max(1, maximumSampleCount)
        self.sampleLifetime = max(0, sampleLifetime)
    }

    public mutating func record(_ rssi: Int, at date: Date) {
        samples = validSamples(at: date)
        samples.append(Sample(rssi: rssi, observedAt: date))
        samples = Array(samples.suffix(maximumSampleCount))
    }

    public func smoothedRSSI(at date: Date) -> Int? {
        let values = validSamples(at: date).map(\.rssi).sorted()
        guard !values.isEmpty else {
            return nil
        }
        return values[values.count / 2]
    }

    private func validSamples(at date: Date) -> [Sample] {
        samples.filter { sample in
            let age = date.timeIntervalSince(sample.observedAt)
            return age >= 0 && age <= sampleLifetime
        }
    }
}

public enum BluetoothRecoveryAction: Equatable {
    case openBluetoothSettings
    case openBluetoothPrivacySettings
}

public enum BluetoothAvailability: Error, Equatable {
    case ready
    case initializing
    case resetting
    case poweredOff
    case unauthorized
    case unsupported

    public var message: String? {
        switch self {
        case .ready:
            return nil
        case .initializing:
            return "蓝牙正在初始化，请稍后重试。"
        case .resetting:
            return "蓝牙服务正在重置，请稍后重试。"
        case .poweredOff:
            return "蓝牙已关闭，请先在系统设置中打开蓝牙。"
        case .unauthorized:
            return "Daka 没有蓝牙权限，请在隐私设置中允许访问。"
        case .unsupported:
            return "这台 Mac 不支持蓝牙扫描。"
        }
    }

    public var recoveryAction: BluetoothRecoveryAction? {
        switch self {
        case .poweredOff:
            return .openBluetoothSettings
        case .unauthorized:
            return .openBluetoothPrivacySettings
        case .ready, .initializing, .resetting, .unsupported:
            return nil
        }
    }
}
