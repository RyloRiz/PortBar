//
//  PortMonitor.swift
//  PortBar
//

import Combine
import Darwin
import Foundation

struct ListeningPort: Identifiable, Hashable {
    let port: Int
    let processName: String
    let launchCommand: String
    let pid: Int32
    let address: String
    let firstSeen: Date
    let workingDirectory: String
    let parentPID: Int32?
    let elapsedTime: String

    init(
        port: Int,
        processName: String,
        launchCommand: String,
        pid: Int32,
        address: String,
        firstSeen: Date,
        workingDirectory: String = "",
        parentPID: Int32? = nil,
        elapsedTime: String = ""
    ) {
        self.port = port
        self.processName = processName
        self.launchCommand = launchCommand
        self.pid = pid
        self.address = address
        self.firstSeen = firstSeen
        self.workingDirectory = workingDirectory
        self.parentPID = parentPID
        self.elapsedTime = elapsedTime
    }

    var id: String { "\(pid)-\(port)-\(address)" }

    var isBackgroundService: Bool {
        ListenerClassification.isBackgroundService(named: processName)
    }
}

struct RecentPort: Identifiable, Hashable {
    let id = UUID()
    let port: Int
    let processName: String
    let launchCommand: String
    let pid: Int32
    let address: String
    let firstSeen: Date
    let stoppedAt: Date

    var duration: TimeInterval { stoppedAt.timeIntervalSince(firstSeen) }
}

enum PortEventKind {
    case started
    case stopped
}

struct PortEvent: Identifiable {
    let id = UUID()
    let kind: PortEventKind
    let port: ListeningPort
}

@MainActor
final class PortMonitor: NSObject, ObservableObject {
    @Published private(set) var ports: [ListeningPort] = []
    @Published private(set) var recentlyStopped: [RecentPort] = []
    @Published private(set) var lastScanDate: Date?
    @Published private(set) var lastScanError: String?
    @Published private(set) var lastEvent: PortEvent?

    private var timer: Timer?
    private var firstSeen: [String: Date] = [:]
    private var isRefreshing = false
    private var hasCompletedInitialScan = false
    private var pollingInterval: TimeInterval
    var eventHandler: ((PortEvent) -> Void)?

    init(pollingInterval: TimeInterval = 1.5) {
        self.pollingInterval = pollingInterval
        super.init()
        refresh()
        scheduleTimer()
    }

    deinit {
        timer?.invalidate()
    }

    func setPollingInterval(_ interval: TimeInterval) {
        let normalized = max(0.75, min(interval, 10))
        guard pollingInterval != normalized else { return }
        pollingInterval = normalized
        scheduleTimer()
    }

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true

        Task {
            let result = await Task.detached(priority: .utility) { Self.readListeningPorts() }.value
            apply(result)
            isRefreshing = false
        }
    }

    func terminateProcessTree(rootPID: Int32) {
        let descendants = processDescendants(of: rootPID)
        for pid in descendants.reversed() {
            Darwin.kill(pid, SIGTERM)
        }
        Darwin.kill(rootPID, SIGTERM)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            for pid in descendants.reversed() where Darwin.kill(pid, 0) == 0 {
                Darwin.kill(pid, SIGKILL)
            }
            if Darwin.kill(rootPID, 0) == 0 {
                Darwin.kill(rootPID, SIGKILL)
            }
            self.refresh()
        }
    }

    private func scheduleTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(timeInterval: pollingInterval, target: self, selector: #selector(refreshOnTimer), userInfo: nil, repeats: true)
    }

    @objc private func refreshOnTimer() {
        refresh()
    }

    private func apply(_ result: ScanResult) {
        let now = Date()
        lastScanDate = now
        lastScanError = result.error
        guard result.error == nil else { return }

        let snapshot = result.entries
        let previousByID = Dictionary(uniqueKeysWithValues: ports.map { ($0.id, $0) })
        let activeIDs = Set(snapshot.map { "\($0.pid)-\($0.port)-\($0.address)" })

        if hasCompletedInitialScan {
            for oldPort in ports where !activeIDs.contains(oldPort.id) {
                recentlyStopped.insert(
                    RecentPort(port: oldPort.port, processName: oldPort.processName, launchCommand: oldPort.launchCommand, pid: oldPort.pid, address: oldPort.address, firstSeen: oldPort.firstSeen, stoppedAt: now),
                    at: 0
                )
                publish(PortEvent(kind: .stopped, port: oldPort))
            }
        }
        recentlyStopped = Array(recentlyStopped.prefix(40))

        firstSeen = firstSeen.filter { activeIDs.contains($0.key) }
        ports = snapshot.map { item in
            let id = "\(item.pid)-\(item.port)-\(item.address)"
            let seen = firstSeen[id] ?? now
            firstSeen[id] = seen
            return ListeningPort(
                port: item.port,
                processName: item.name,
                launchCommand: item.launchCommand,
                pid: item.pid,
                address: item.address,
                firstSeen: seen,
                workingDirectory: item.workingDirectory,
                parentPID: item.parentPID,
                elapsedTime: item.elapsedTime
            )
        }
        .sorted { $0.firstSeen > $1.firstSeen }

        if hasCompletedInitialScan {
            for newPort in ports where previousByID[newPort.id] == nil {
                publish(PortEvent(kind: .started, port: newPort))
            }
        }
        hasCompletedInitialScan = true
    }

    private func publish(_ event: PortEvent) {
        lastEvent = event
        eventHandler?(event)
    }

    private func processDescendants(of pid: Int32) -> [Int32] {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        task.arguments = ["-P", "\(pid)"]
        let output = Pipe()
        task.standardOutput = output
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return []
        }

        let children = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            .split(whereSeparator: \.isNewline)
            .compactMap { Int32($0) }

        return children.flatMap { processDescendants(of: $0) + [$0] }
    }

    nonisolated private static func readListeningPorts() -> ScanResult {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        task.arguments = ["-nP", "-iTCP", "-sTCP:LISTEN", "-Fpcn"]
        let output = Pipe()
        let error = Pipe()
        task.standardOutput = output
        task.standardError = error

        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return ScanResult(entries: [], error: "Could not run lsof: \(error.localizedDescription)")
        }

        let text = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        let errorText = String(decoding: error.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        var currentPID: Int32?
        var currentName = "Unknown process"
        var entries: [(port: Int, name: String, pid: Int32, address: String)] = []

        for line in text.split(whereSeparator: \.isNewline) {
            guard let marker = line.first else { continue }
            let value = String(line.dropFirst())

            switch marker {
            case "p": currentPID = Int32(value)
            case "c": currentName = value
            case "n":
                guard let pid = currentPID,
                      let range = value.range(of: #":(\d+)$"#, options: .regularExpression),
                      let port = Int(value[range].dropFirst()) else { continue }
                entries.append((port, currentName, pid, value))
            default: break
            }
        }

        var unique = Set<String>()
        let uniqueEntries = entries.filter { unique.insert("\($0.pid)-\($0.port)-\($0.address)").inserted }
        let processMetadata = readProcessMetadata(for: Set(uniqueEntries.map(\.pid)))
        let workingDirectories = readWorkingDirectories(for: Set(uniqueEntries.map(\.pid)))
        let diagnostic = task.terminationStatus == 0 ? nil : (errorText.isEmpty ? "lsof exited with status \(task.terminationStatus)." : errorText)
        return ScanResult(
            entries: uniqueEntries.map {
                (
                    port: $0.port,
                    name: $0.name,
                    launchCommand: processMetadata[$0.pid]?.launchCommand ?? "",
                    pid: $0.pid,
                    address: $0.address,
                    workingDirectory: workingDirectories[$0.pid] ?? "",
                    parentPID: processMetadata[$0.pid]?.parentPID,
                    elapsedTime: processMetadata[$0.pid]?.elapsedTime ?? ""
                )
            },
            error: diagnostic
        )
    }

    /// `lsof` only exposes the short process name. Query each scan's PIDs in
    /// one `ps` invocation so rules can distinguish `node` from `next dev`,
    /// `vite`, `nuxi`, and other command-line launchers.
    nonisolated private static func readProcessMetadata(for pids: Set<Int32>) -> [Int32: ProcessMetadata] {
        guard !pids.isEmpty else { return [:] }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/ps")
        task.arguments = ["-ww", "-p", pids.map(String.init).sorted().joined(separator: ","), "-o", "pid=", "-o", "ppid=", "-o", "etime=", "-o", "command="]
        let output = Pipe()
        task.standardOutput = output
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return [:]
        }

        let text = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        var metadata: [Int32: ProcessMetadata] = [:]
        for line in text.split(whereSeparator: \.isNewline) {
            let parts = line.split(maxSplits: 3, whereSeparator: \.isWhitespace)
            guard parts.count >= 3,
                  let pid = Int32(parts[0]),
                  let parentPID = Int32(parts[1]) else { continue }
            metadata[pid] = ProcessMetadata(
                launchCommand: parts.count == 4 ? String(parts[3]) : "",
                parentPID: parentPID,
                elapsedTime: String(parts[2])
            )
        }
        return metadata
    }

    nonisolated private static func readWorkingDirectories(for pids: Set<Int32>) -> [Int32: String] {
        guard !pids.isEmpty else { return [:] }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        task.arguments = ["-nP", "-a", "-p", pids.map(String.init).sorted().joined(separator: ","), "-d", "cwd", "-Fn"]
        let output = Pipe()
        task.standardOutput = output
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return [:]
        }

        let text = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        var currentPID: Int32?
        var directories: [Int32: String] = [:]
        for line in text.split(whereSeparator: \.isNewline) {
            guard let marker = line.first else { continue }
            let value = String(line.dropFirst())
            switch marker {
            case "p": currentPID = Int32(value)
            case "n":
                if let currentPID, !value.isEmpty {
                    directories[currentPID] = value
                }
            default: break
            }
        }
        return directories
    }
}

private struct ScanResult {
    let entries: [(port: Int, name: String, launchCommand: String, pid: Int32, address: String, workingDirectory: String, parentPID: Int32?, elapsedTime: String)]
    let error: String?
}

private struct ProcessMetadata {
    let launchCommand: String
    let parentPID: Int32
    let elapsedTime: String
}
