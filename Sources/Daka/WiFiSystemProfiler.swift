import Darwin
import DakaCore
import Foundation

struct WiFiSystemProfiler {
    typealias Snapshot = WiFiProfilerSnapshot

    private static let cacheLock = NSLock()
    private static let executionLock = NSLock()
    private static var cachedSnapshot: Snapshot?
    private static var cachedAt: Date?

    static func snapshot(maxAge: TimeInterval = 30, timeout: TimeInterval = 5) -> Snapshot {
        if let cached = cachedSnapshotIfFresh(maxAge: maxAge) {
            return cached
        }

        executionLock.lock()
        defer { executionLock.unlock() }

        if let cached = cachedSnapshotIfFresh(maxAge: maxAge) {
            return cached
        }

        guard let output = runSystemProfiler(timeout: timeout) else {
            return Snapshot(currentSSID: nil, visibleSSIDs: [])
        }

        let snapshot = WiFiProfilerParser.parse(output)
        cacheLock.lock()
        cachedSnapshot = snapshot
        cachedAt = Date()
        cacheLock.unlock()
        return snapshot
    }

    private static func cachedSnapshotIfFresh(maxAge: TimeInterval) -> Snapshot? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        guard let cachedSnapshot, let cachedAt, Date().timeIntervalSince(cachedAt) <= maxAge else {
            return nil
        }
        return cachedSnapshot
    }

    private static func runSystemProfiler(timeout: TimeInterval) -> String? {
        let process = Process()
        let temporaryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("Daka-WiFi-\(UUID().uuidString).txt")
        guard FileManager.default.createFile(atPath: temporaryURL.path, contents: nil),
              let outputHandle = try? FileHandle(forWritingTo: temporaryURL) else {
            return nil
        }
        defer {
            try? outputHandle.close()
            try? FileManager.default.removeItem(at: temporaryURL)
        }

        let termination = DispatchSemaphore(value: 0)
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        process.arguments = ["SPAirPortDataType", "-detailLevel", "mini"]
        process.standardOutput = outputHandle
        process.standardError = Pipe()
        process.terminationHandler = { _ in termination.signal() }

        do {
            try process.run()
        } catch {
            return nil
        }

        if termination.wait(timeout: .now() + timeout) == .timedOut {
            process.terminate()
            if termination.wait(timeout: .now() + 1) == .timedOut {
                kill(process.processIdentifier, SIGKILL)
                _ = termination.wait(timeout: .now() + 1)
            }
            return nil
        }

        guard process.terminationStatus == 0 else {
            return nil
        }

        try? outputHandle.synchronize()
        let data = try? Data(contentsOf: temporaryURL)
        guard let data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}
