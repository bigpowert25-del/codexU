import Foundation

public struct BundledAppCommand: Sendable {
    public let executableURL: URL

    public init(
        helperExecutableURL: URL,
        fileManager: FileManager = .default
    ) throws {
        let helper = helperExecutableURL.standardizedFileURL
        let helpersDirectory = helper.deletingLastPathComponent()
        let contentsDirectory = helpersDirectory.deletingLastPathComponent()
        guard helpersDirectory.lastPathComponent == "Helpers",
              contentsDirectory.lastPathComponent == "Contents"
        else {
            throw PublicSnapshotError(code: "snapshot_command_unavailable")
        }
        let candidate = contentsDirectory
            .appendingPathComponent("MacOS", isDirectory: true)
            .appendingPathComponent("codexU")
            .standardizedFileURL
        guard fileManager.isExecutableFile(atPath: candidate.path),
              (try? fileManager.destinationOfSymbolicLink(
                atPath: candidate.path
              )) == nil
        else {
            throw PublicSnapshotError(code: "snapshot_command_unavailable")
        }
        executableURL = candidate
    }

    public func load(timeout: TimeInterval = 3) throws -> Data {
        let process = Process()
        let output = Pipe()
        let timeoutState = TimeoutState()
        process.executableURL = executableURL
        process.arguments = ["--dump-project-index"]
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            throw PublicSnapshotError(code: "snapshot_command_unavailable")
        }

        let timer = DispatchSource.makeTimerSource(
            queue: DispatchQueue.global(qos: .userInitiated)
        )
        timer.schedule(deadline: .now() + max(timeout, 0.01))
        timer.setEventHandler {
            guard process.isRunning else { return }
            timeoutState.markTimedOut()
            process.terminate()
        }
        timer.resume()

        let data = (try? output.fileHandleForReading.readToEnd()) ?? Data()
        process.waitUntilExit()
        timer.cancel()

        if timeoutState.didTimeOut {
            throw PublicSnapshotError(code: "snapshot_timeout")
        }
        guard process.terminationStatus == 0 else {
            throw PublicSnapshotError(code: "snapshot_command_failed")
        }
        guard data.count <= 2 * 1_024 * 1_024 else {
            throw PublicSnapshotError(code: "snapshot_too_large")
        }
        return data
    }
}

private final class TimeoutState: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false

    var didTimeOut: Bool {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func markTimedOut() {
        lock.lock()
        value = true
        lock.unlock()
    }
}
