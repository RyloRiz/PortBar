//
//  HistoryStore.swift
//  PortBar
//

import Combine
import Foundation

enum HistoryRetention: Int, CaseIterable, Identifiable {
    case sevenDays = 7
    case thirtyDays = 30
    case ninetyDays = 90
    case forever = 0

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .sevenDays: "7 days"
        case .thirtyDays: "30 days"
        case .ninetyDays: "90 days"
        case .forever: "Keep forever"
        }
    }
}

struct HistoryEvent: Identifiable, Codable, Hashable {
    enum Kind: String, Codable {
        case started
        case stopped

        var label: String {
            switch self {
            case .started: "Started"
            case .stopped: "Stopped"
            }
        }

        var symbol: String {
            switch self {
            case .started: "play.fill"
            case .stopped: "stop.fill"
            }
        }
    }

    let id: UUID
    let kind: Kind
    let occurredAt: Date
    let serviceLabels: [String]
    let port: Int
    let processName: String
    let launchCommand: String
    let pid: Int32
    let address: String
    let workingDirectory: String

    init(event: PortEvent, serviceLabels: [String]) {
        id = UUID()
        kind = event.kind == .started ? .started : .stopped
        occurredAt = Date()
        self.serviceLabels = serviceLabels
        port = event.port.port
        processName = event.port.processName
        launchCommand = event.port.launchCommand
        pid = event.port.pid
        address = event.port.address
        workingDirectory = event.port.workingDirectory
    }
}

@MainActor
final class HistoryStore: ObservableObject {
    @Published private(set) var events: [HistoryEvent] = []
    @Published var retention: HistoryRetention {
        didSet {
            defaults.set(retention.rawValue, forKey: Keys.retention)
            pruneAndSave()
        }
    }

    let storageDirectory: URL
    let storageFile: URL

    private let defaults = UserDefaults.standard
    private let fileManager = FileManager.default
    private let maximumEvents = 2_000

    init() {
        storageDirectory = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
            .appendingPathComponent(".portbar", isDirectory: true)
        storageFile = storageDirectory.appendingPathComponent("history.json")
        retention = HistoryRetention(rawValue: defaults.integer(forKey: Keys.retention)) ?? .thirtyDays
        events = Self.load(from: storageFile)
        pruneAndSave()
    }

    func record(_ event: PortEvent, filters: [QuickFilter]) {
        let matches = filters
            .filter { $0.isEnabled && $0.matches(event.port) }
            .map(\.label)
        guard !matches.isEmpty else { return }

        events.insert(HistoryEvent(event: event, serviceLabels: matches), at: 0)
        pruneAndSave()
    }

    func clear() {
        events = []
        do {
            if fileManager.fileExists(atPath: storageFile.path) {
                try fileManager.removeItem(at: storageFile)
            }
        } catch {
            // A future scan will replace stale data; keeping the in-memory history clear is preferable.
        }
    }

    private func pruneAndSave() {
        if retention != .forever {
            let cutoff = Calendar.current.date(byAdding: .day, value: -retention.rawValue, to: Date()) ?? .distantPast
            events.removeAll { $0.occurredAt < cutoff }
        }
        if events.count > maximumEvents {
            events = Array(events.prefix(maximumEvents))
        }
        save()
    }

    private func save() {
        do {
            try fileManager.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(events)
            try data.write(to: storageFile, options: .atomic)
        } catch {
            // History is an enhancement; scanning should remain unaffected if disk access fails.
        }
    }

    private static func load(from url: URL) -> [HistoryEvent] {
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([HistoryEvent].self, from: data) else { return [] }
        return decoded.sorted { $0.occurredAt > $1.occurredAt }
    }

    private enum Keys {
        static let retention = "historyRetention"
    }
}
