//
//  PreferencesStore.swift
//  PortBar
//

import Combine
import AppKit
import Foundation
import ServiceManagement
import SwiftUI

enum AppAccent: String, CaseIterable, Identifiable {
    case blue, indigo, purple, pink, red, orange, green, graphite

    var id: String { rawValue }

    var label: String {
        switch self {
        case .blue: "Blue"
        case .indigo: "Indigo"
        case .purple: "Purple"
        case .pink: "Pink"
        case .red: "Red"
        case .orange: "Orange"
        case .green: "Green"
        case .graphite: "Graphite"
        }
    }

    var color: Color {
        switch self {
        case .graphite: .gray
        default: FilterTint.color(for: rawValue)
        }
    }

    static func color(for storedValue: String) -> Color {
        Self(rawValue: storedValue)?.color ?? FilterTint.color(for: storedValue)
    }

    static func storedValue(for color: Color) -> String {
        guard let resolved = NSColor(color).usingColorSpace(.sRGB) else { return "blue" }
        return String(
            format: "#%02X%02X%02X",
            Int((resolved.redComponent * 255).rounded()),
            Int((resolved.greenComponent * 255).rounded()),
            Int((resolved.blueComponent * 255).rounded())
        )
    }
}

enum TerminalApplication: String, CaseIterable, Identifiable {
    case terminal = "Terminal"
    case iTerm = "iTerm"
    case warp = "Warp"
    case ghostty = "Ghostty"
    case wezTerm = "WezTerm"
    case kitty = "kitty"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .iTerm: "iTerm"
        case .wezTerm: "WezTerm"
        case .kitty: "kitty"
        default: rawValue
        }
    }
}

struct QuickFilter: Identifiable, Codable, Equatable {
    var id = UUID()
    var symbol: String
    var label: String
    var ports: String
    var processPattern: String
    var launchCommandPattern: String
    var excludedProcessPattern: String
    var tint: String
    var isEnabled: Bool
    var notificationsEnabled: Bool

    init(
        id: UUID = UUID(),
        symbol: String,
        label: String,
        ports: String,
        processPattern: String,
        launchCommandPattern: String = "",
        excludedProcessPattern: String = "",
        tint: String = "blue",
        isEnabled: Bool = true,
        notificationsEnabled: Bool = false
    ) {
        self.id = id
        self.symbol = symbol
        self.label = label
        self.ports = ports
        self.processPattern = processPattern
        self.launchCommandPattern = launchCommandPattern
        self.excludedProcessPattern = excludedProcessPattern
        self.tint = tint
        self.isEnabled = isEnabled
        self.notificationsEnabled = notificationsEnabled
    }

    var portNumbers: Set<Int> {
        Set(ports
            .split(separator: ",")
            .flatMap { component -> [Int] in
                let token = component.trimmingCharacters(in: .whitespacesAndNewlines)
                let bounds = token.split(separator: "-", maxSplits: 1).compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
                if bounds.count == 2 {
                    let lower = max(1, bounds[0])
                    let upper = min(65_535, bounds[1])
                    return lower <= upper ? Array(lower...upper) : []
                }
                return Int(token).map { [$0] } ?? []
            })
    }

    var processTerms: [String] {
        Self.terms(in: processPattern)
    }

    var exclusionTerms: [String] {
        Self.terms(in: excludedProcessPattern)
    }

    /// Terms are alternatives within this rule. The rule itself is an AND
    /// condition when port or process rules have already matched.
    var launchCommandTerms: [String] {
        Self.terms(in: launchCommandPattern)
    }

    func matches(_ item: ListeningPort) -> Bool {
        matches(port: item.port, processName: item.processName, launchCommand: item.launchCommand)
    }

    func matches(port: Int, processName: String, launchCommand: String = "") -> Bool {
        guard !exclusionTerms.contains(where: { processName.localizedCaseInsensitiveContains($0) }) else { return false }
        let matchesLaunchCommand = launchCommandTerms.isEmpty || launchCommandTerms.contains {
            launchCommand.localizedCaseInsensitiveContains($0)
        }

        // A configured port rule is the authoritative definition of a service.
        // Process matching is only useful for intentionally portless custom groups.
        if !portNumbers.isEmpty {
            return portNumbers.contains(port) && matchesLaunchCommand
        }
        return processTerms.contains { processName.localizedCaseInsensitiveContains($0) } && matchesLaunchCommand
    }

    private static func terms(in value: String) -> [String] {
        value
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private enum CodingKeys: String, CodingKey {
        case id, symbol, label, ports, processPattern, launchCommandPattern, excludedProcessPattern, tint, isEnabled, notificationsEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        symbol = try container.decode(String.self, forKey: .symbol)
        label = try container.decode(String.self, forKey: .label)
        ports = try container.decode(String.self, forKey: .ports)
        processPattern = try container.decode(String.self, forKey: .processPattern)
        launchCommandPattern = try container.decodeIfPresent(String.self, forKey: .launchCommandPattern) ?? ""
        excludedProcessPattern = try container.decodeIfPresent(String.self, forKey: .excludedProcessPattern) ?? ""
        tint = try container.decodeIfPresent(String.self, forKey: .tint) ?? "blue"
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        notificationsEnabled = try container.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? false
    }
}

struct PortAnnotation: Codable, Equatable {
    var label: String = ""
    var note: String = ""

    var isEmpty: Bool {
        label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct ServicePack: Identifiable {
    let id: String
    let label: String
    let description: String
    let bestFor: String
    let symbol: String
    let sectionID: String
    let serviceLabels: [String]
}

struct ServiceSection: Identifiable {
    let id: String
    let label: String
    let serviceLabels: [String]
}

@MainActor
final class PreferencesStore: ObservableObject {
    @Published var quickFilters: [QuickFilter] {
        didSet {
            saveQuickFilters()
            prunePinnedServices()
        }
    }
    @Published var pinnedPorts: [Int] {
        didSet { defaults.set(pinnedPorts, forKey: Keys.pinnedPorts) }
    }
    @Published var pollingInterval: Double {
        didSet { defaults.set(pollingInterval, forKey: Keys.pollingInterval) }
    }
    @Published var showsAllListeners: Bool {
        didSet { defaults.set(showsAllListeners, forKey: Keys.showsAllListeners) }
    }
    @Published private(set) var pinnedServiceIDs: [QuickFilter.ID] {
        didSet {
            let validIDs = validPinnedServiceIDs(from: pinnedServiceIDs)
            if validIDs != pinnedServiceIDs {
                pinnedServiceIDs = validIDs
                return
            }
            defaults.set(pinnedServiceIDs.map(\.uuidString), forKey: Keys.pinnedServiceIDs)
        }
    }
    @Published private(set) var popupServiceLimit: Int {
        didSet {
            let normalized = Self.normalizedPopupServiceLimit(popupServiceLimit)
            if normalized != popupServiceLimit {
                popupServiceLimit = normalized
                return
            }
            defaults.set(popupServiceLimit, forKey: Keys.popupServiceLimit)
            if pinnedServiceIDs.count > popupServiceLimit {
                pinnedServiceIDs = Array(pinnedServiceIDs.prefix(popupServiceLimit))
            }
        }
    }
    @Published var accent: String {
        didSet { defaults.set(accent, forKey: Keys.accent) }
    }
    var accentColor: Color { AppAccent.color(for: accent) }
    @Published var terminalApplication: TerminalApplication {
        didSet { defaults.set(terminalApplication.rawValue, forKey: Keys.terminalApplication) }
    }
    @Published private(set) var launchAtLogin: Bool
    @Published private(set) var portAnnotations: [String: PortAnnotation]

    private let defaults = UserDefaults.standard

    static let popupServiceLimitOptions = Array(stride(from: 3, through: 30, by: 3))

    init() {
        pinnedPorts = defaults.array(forKey: Keys.pinnedPorts) as? [Int] ?? []
        pollingInterval = defaults.object(forKey: Keys.pollingInterval) as? Double ?? 5
        showsAllListeners = defaults.object(forKey: Keys.showsAllListeners) as? Bool ?? false
        pinnedServiceIDs = []
        popupServiceLimit = Self.normalizedPopupServiceLimit(
            defaults.object(forKey: Keys.popupServiceLimit) as? Int ?? 9
        )
        accent = defaults.string(forKey: Keys.accent) ?? AppAccent.blue.rawValue
        terminalApplication = TerminalApplication(rawValue: defaults.string(forKey: Keys.terminalApplication) ?? "") ?? .terminal
        launchAtLogin = SMAppService.mainApp.status == .enabled
        portAnnotations = Self.loadAnnotations(from: defaults)

        if let data = defaults.data(forKey: Keys.quickFilters),
           let saved = try? JSONDecoder().decode([QuickFilter].self, from: data) {
            let needsCatalogUpgrade = defaults.integer(forKey: Keys.serviceCatalogVersion) < ServiceCatalog.version
            let repaired = ServiceCatalog.repaired(saved, includeMissingServices: needsCatalogUpgrade, refreshServiceAppearance: needsCatalogUpgrade)
            // Older releases enabled the entire catalog. If that untouched
            // default is still present, move it to the focused starter pack;
            // any deliberate enable/disable choice is preserved.
            quickFilters = needsCatalogUpgrade && saved.allSatisfy(\.isEnabled)
                ? ServiceCatalog.applyingStarterPack(to: repaired)
                : repaired
            if needsCatalogUpgrade {
                defaults.set(ServiceCatalog.version, forKey: Keys.serviceCatalogVersion)
            }
        } else {
            quickFilters = ServiceCatalog.filters
            defaults.set(ServiceCatalog.version, forKey: Keys.serviceCatalogVersion)
        }

        if let storedIDs = defaults.stringArray(forKey: Keys.pinnedServiceIDs) {
            pinnedServiceIDs = validPinnedServiceIDs(from: storedIDs.compactMap(UUID.init(uuidString:)))
        } else {
            pinnedServiceIDs = quickFilters
                .filter(\.isEnabled)
                .prefix(popupServiceLimit)
                .map(\.id)
            defaults.set(pinnedServiceIDs.map(\.uuidString), forKey: Keys.pinnedServiceIDs)
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // The setting remains unchanged when macOS rejects the request.
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func update(_ filter: QuickFilter) {
        guard let index = quickFilters.firstIndex(where: { $0.id == filter.id }) else { return }
        quickFilters[index] = filter
    }

    func restoreDefaults(for filter: QuickFilter) {
        guard let index = quickFilters.firstIndex(where: { $0.id == filter.id }),
              var restored = ServiceCatalog.defaults(for: filter.label) else { return }

        // Enabling a group is an intentional menu preference, not part of its rule definition.
        restored.id = filter.id
        restored.isEnabled = filter.isEnabled
        quickFilters[index] = restored
    }

    func moveQuickFilters(from offsets: IndexSet, to destination: Int) {
        let moving = offsets.map { quickFilters[$0] }
        for index in offsets.sorted(by: >) {
            quickFilters.remove(at: index)
        }
        let adjustedDestination = destination - offsets.filter { $0 < destination }.count
        quickFilters.insert(contentsOf: moving, at: adjustedDestination)
    }

    func moveQuickFilter(id: QuickFilter.ID, by offset: Int) {
        guard let index = quickFilters.firstIndex(where: { $0.id == id }) else { return }
        let destination = index + offset
        guard quickFilters.indices.contains(destination) else { return }
        quickFilters.swapAt(index, destination)
    }

    func moveQuickFilter(id: QuickFilter.ID, within serviceLabels: [String], by offset: Int) {
        let labels = Set(serviceLabels.map { $0.lowercased() })
        let sectionIndices = quickFilters.indices.filter { labels.contains(quickFilters[$0].label.lowercased()) }
        guard let currentPosition = sectionIndices.firstIndex(where: { quickFilters[$0].id == id }) else { return }
        let destinationPosition = currentPosition + offset
        guard sectionIndices.indices.contains(destinationPosition) else { return }
        quickFilters.swapAt(sectionIndices[currentPosition], sectionIndices[destinationPosition])
    }

    func togglePinnedPort(_ port: Int) {
        if let index = pinnedPorts.firstIndex(of: port) {
            pinnedPorts.remove(at: index)
        } else {
            pinnedPorts.append(port)
            pinnedPorts.sort()
        }
    }

    func pin(_ ports: [Int]) {
        pinnedPorts = Array(Set(pinnedPorts).union(ports)).sorted()
    }

    func unpin(_ ports: [Int]) {
        let values = Set(ports)
        pinnedPorts.removeAll { values.contains($0) }
    }

    var pinnedPopupServices: [QuickFilter] {
        let servicesByID = Dictionary(uniqueKeysWithValues: quickFilters.map { ($0.id, $0) })
        return pinnedServiceIDs.compactMap { servicesByID[$0] }
    }

    var canPinMoreServices: Bool {
        pinnedServiceIDs.count < popupServiceLimit
    }

    func isServicePinned(_ service: QuickFilter) -> Bool {
        pinnedServiceIDs.contains(service.id)
    }

    func pinService(_ service: QuickFilter) {
        guard service.isEnabled,
              !pinnedServiceIDs.contains(service.id),
              pinnedServiceIDs.count < popupServiceLimit else { return }
        pinnedServiceIDs.append(service.id)
    }

    func unpinService(_ service: QuickFilter) {
        pinnedServiceIDs.removeAll { $0 == service.id }
    }

    func movePinnedService(_ serviceID: QuickFilter.ID, before targetID: QuickFilter.ID) {
        guard serviceID != targetID,
              let sourceIndex = pinnedServiceIDs.firstIndex(of: serviceID) else { return }

        pinnedServiceIDs.remove(at: sourceIndex)
        guard let targetIndex = pinnedServiceIDs.firstIndex(of: targetID) else {
            pinnedServiceIDs.insert(serviceID, at: min(sourceIndex, pinnedServiceIDs.endIndex))
            return
        }
        pinnedServiceIDs.insert(serviceID, at: targetIndex)
    }

    func setPopupServiceLimit(_ limit: Int) {
        popupServiceLimit = limit
    }

    func annotation(for port: Int) -> PortAnnotation {
        portAnnotations["\(port)"] ?? PortAnnotation()
    }

    func setAnnotation(_ annotation: PortAnnotation, for port: Int) {
        let key = "\(port)"
        if annotation.isEmpty {
            portAnnotations.removeValue(forKey: key)
        } else {
            portAnnotations[key] = annotation
        }
        if let data = try? JSONEncoder().encode(portAnnotations) {
            defaults.set(data, forKey: Keys.portAnnotations)
        }
    }

    @discardableResult
    func enable(_ pack: ServicePack) -> Int {
        let wantedLabels = Set(pack.serviceLabels.map { $0.lowercased() })
        var enabledCount = 0

        for index in quickFilters.indices where wantedLabels.contains(quickFilters[index].label.lowercased()) {
            if !quickFilters[index].isEnabled {
                quickFilters[index].isEnabled = true
                enabledCount += 1
            }
        }

        let existingLabels = Set(quickFilters.map { $0.label.lowercased() })
        for label in pack.serviceLabels where !existingLabels.contains(label.lowercased()) {
            guard var filter = ServiceCatalog.defaults(for: label) else { continue }
            filter.isEnabled = true
            quickFilters.append(filter)
            enabledCount += 1
        }

        return enabledCount
    }

    @discardableResult
    func disable(_ pack: ServicePack) -> Int {
        let wantedLabels = Set(pack.serviceLabels.map { $0.lowercased() })
        var disabledCount = 0

        for index in quickFilters.indices where wantedLabels.contains(quickFilters[index].label.lowercased()) {
            if quickFilters[index].isEnabled {
                quickFilters[index].isEnabled = false
                disabledCount += 1
            }
        }

        return disabledCount
    }

    private func saveQuickFilters() {
        if let data = try? JSONEncoder().encode(quickFilters) {
            defaults.set(data, forKey: Keys.quickFilters)
        }
    }

    private func prunePinnedServices() {
        let validIDs = validPinnedServiceIDs(from: pinnedServiceIDs)
        guard validIDs != pinnedServiceIDs else { return }
        pinnedServiceIDs = validIDs
    }

    private func validPinnedServiceIDs(from ids: [QuickFilter.ID]) -> [QuickFilter.ID] {
        let enabledIDs = Set(quickFilters.filter(\.isEnabled).map(\.id))
        var seen = Set<QuickFilter.ID>()
        return ids.filter { enabledIDs.contains($0) && seen.insert($0).inserted }.prefix(popupServiceLimit).map { $0 }
    }

    private static func normalizedPopupServiceLimit(_ value: Int) -> Int {
        popupServiceLimitOptions.min(by: { abs($0 - value) < abs($1 - value) }) ?? 9
    }

    private static func loadAnnotations(from defaults: UserDefaults) -> [String: PortAnnotation] {
        guard let data = defaults.data(forKey: Keys.portAnnotations),
              let annotations = try? JSONDecoder().decode([String: PortAnnotation].self, from: data) else { return [:] }
        return annotations
    }

    private enum Keys {
        static let quickFilters = "quickFilters"
        static let pinnedPorts = "pinnedPorts"
        static let pollingInterval = "pollingInterval"
        static let showsAllListeners = "showsAllListeners"
        static let pinnedServiceIDs = "pinnedServiceIDs"
        static let popupServiceLimit = "popupServiceLimit"
        static let accent = "accent"
        static let terminalApplication = "terminalApplication"
        static let portAnnotations = "portAnnotations"
        static let serviceCatalogVersion = "serviceCatalogVersion"
    }
}
