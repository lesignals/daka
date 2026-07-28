import AppKit
import Darwin
import Foundation

private enum SingleInstanceLockError: Error {
    case alreadyRunning
    case systemError(path: String, code: Int32)
}

private final class SingleInstanceLock {
    private let fileDescriptor: Int32

    init(path: String = "/tmp/daka-\(getuid()).lock") throws {
        fileDescriptor = open(path, O_CREAT | O_RDWR | O_CLOEXEC, S_IRUSR | S_IWUSR)
        guard fileDescriptor >= 0 else {
            throw SingleInstanceLockError.systemError(path: path, code: errno)
        }

        guard flock(fileDescriptor, LOCK_EX | LOCK_NB) == 0 else {
            let lockError = errno
            close(fileDescriptor)
            if lockError == EWOULDBLOCK {
                throw SingleInstanceLockError.alreadyRunning
            }
            throw SingleInstanceLockError.systemError(path: path, code: lockError)
        }
    }

    deinit {
        flock(fileDescriptor, LOCK_UN)
        close(fileDescriptor)
    }
}

private let singleInstanceLock: SingleInstanceLock
do {
    singleInstanceLock = try SingleInstanceLock()
} catch SingleInstanceLockError.alreadyRunning {
    NSLog("Daka is already running; exiting duplicate instance.")
    exit(0)
} catch SingleInstanceLockError.systemError(let path, let code) {
    NSLog("Daka failed to acquire instance lock at \(path): \(String(cString: strerror(code)))")
    exit(1)
} catch {
    NSLog("Daka failed to acquire instance lock: \(error)")
    exit(1)
}

withExtendedLifetime(singleInstanceLock) {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
