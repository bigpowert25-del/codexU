import Foundation
import Darwin

public struct BundledAppCommand: Sendable {
    public let executableURL: URL

    public init(
        helperExecutableURL: URL,
        fileManager: FileManager = .default
    ) throws {
        let helper = helperExecutableURL.standardizedFileURL
        let helpersDirectory = helper.deletingLastPathComponent()
        let contentsDirectory = helpersDirectory.deletingLastPathComponent()
        let appDirectory = contentsDirectory.deletingLastPathComponent()
        guard helpersDirectory.lastPathComponent == "Helpers",
              contentsDirectory.lastPathComponent == "Contents",
              appDirectory.pathExtension == "app"
        else {
            throw PublicSnapshotError(code: "snapshot_command_unavailable")
        }
        let macOSDirectory = contentsDirectory.appendingPathComponent(
            "MacOS",
            isDirectory: true
        )
        let candidate = macOSDirectory
            .appendingPathComponent("codexU")
            .standardizedFileURL
        let bundleComponents = [
            appDirectory,
            contentsDirectory,
            helpersDirectory,
            helper,
            macOSDirectory,
            candidate
        ]
        guard bundleComponents.allSatisfy({
            !isSymbolicLink($0, fileManager: fileManager)
        }),
        fileManager.isExecutableFile(atPath: candidate.path)
        else {
            throw PublicSnapshotError(code: "snapshot_command_unavailable")
        }
        let resolvedContents = contentsDirectory.resolvingSymlinksInPath()
        let resolvedCandidate = candidate.resolvingSymlinksInPath()
        guard resolvedCandidate.path.hasPrefix(resolvedContents.path + "/")
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
            Darwin.kill(process.processIdentifier, SIGKILL)
        }
        timer.resume()

        let maximumOutputBytes = 2 * 1_024 * 1_024
        var data = Data()
        var exceededOutputLimit = false
        while true {
            let chunk = output.fileHandleForReading.availableData
            if chunk.isEmpty {
                break
            }
            if data.count + chunk.count > maximumOutputBytes {
                exceededOutputLimit = true
                timer.cancel()
                if process.isRunning {
                    Darwin.kill(process.processIdentifier, SIGKILL)
                }
                break
            }
            data.append(chunk)
        }
        process.waitUntilExit()
        timer.cancel()

        if exceededOutputLimit {
            throw PublicSnapshotError(code: "snapshot_too_large")
        }
        if timeoutState.didTimeOut {
            throw PublicSnapshotError(code: "snapshot_timeout")
        }
        guard process.terminationStatus == 0 else {
            throw PublicSnapshotError(code: "snapshot_command_failed")
        }
        return data
    }
}

private func isSymbolicLink(
    _ url: URL,
    fileManager: FileManager
) -> Bool {
    (try? fileManager.destinationOfSymbolicLink(atPath: url.path)) != nil
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
