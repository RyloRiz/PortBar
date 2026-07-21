//
//  PortBarMenuView.swift
//  PortBar
//

import SwiftUI
import AppKit

struct PortBarMenuView: View {
    @Environment(\.portBarAccent) private var appAccent
    @Environment(\.openSettings) private var openSettings
    @ObservedObject var monitor: PortMonitor
    @ObservedObject var preferences: PreferencesStore

    @State private var searchText = ""
    @State private var selectedFilterID: QuickFilter.ID?
    @State private var portToTerminate: ListeningPort?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 3)

    private var popupQuickFilters: [QuickFilter] {
        preferences.pinnedPopupServices
    }

    private var quickFilterTrayHeight: CGFloat {
        guard !popupQuickFilters.isEmpty else { return 0 }
        let rows = ceil(Double(popupQuickFilters.count) / Double(columns.count))
        return min(CGFloat(rows) * 34, 128)
    }

    private var selectedFilter: QuickFilter? {
        popupQuickFilters.first { $0.id == selectedFilterID }
    }

    private var visiblePorts: [ListeningPort] {
        monitor.ports
            .filter {
                preferences.showsAllListeners || !$0.isBackgroundService || preferences.pinnedPorts.contains($0.port)
            }
            .sorted { lhs, rhs in
                let leftPriority = displayPriority(for: lhs)
                let rightPriority = displayPriority(for: rhs)
                if leftPriority != rightPriority { return leftPriority > rightPriority }
                return lhs.firstSeen > rhs.firstSeen
            }
    }

    /// Listener rows that pass the active service scope, before the optional
    /// text search is applied. This is also the count the header reports.
    private var serviceMatchedPorts: [ListeningPort] {
        if let selectedFilter {
            return visiblePorts.filter(selectedFilter.matches)
        } else if preferences.showsAllListeners {
            return visiblePorts
        } else {
            return visiblePorts.filter(matchesAnyEnabledService)
        }
    }

    private var filteredPorts: [ListeningPort] {
        serviceMatchedPorts.filter { item in
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let matchesSearch = query.isEmpty || "\(item.port) \(item.processName) \(item.pid)".localizedCaseInsensitiveContains(query)
            return matchesSearch
        }
    }

    private var observedListenerCount: Int {
        monitor.ports.count
    }

    private var pinnedPortStates: [(port: Int, listener: ListeningPort?)] {
        preferences.pinnedPorts.compactMap { number in
            let listener = monitor.ports.first(where: { $0.port == number })
            guard matchesCurrentFilter(port: number, processName: listener?.processName ?? "", launchCommand: listener?.launchCommand ?? "") else { return nil }
            return (number, listener)
        }
    }

    private var unpinnedFilteredPorts: [ListeningPort] {
        filteredPorts.filter { !preferences.pinnedPorts.contains($0.port) }
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                    header
                    Divider()

                VStack(alignment: .leading, spacing: 12) {
                    quickFilters

                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Filter ports or processes", text: $searchText)
                            .textFieldStyle(.plain)
                        if !searchText.isEmpty {
                            HoverIconButton(systemName: "xmark.circle.fill", tint: .secondary, help: "Clear filter") {
                                searchText = ""
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 7))
                }
                .padding(14)

                Divider()

                ScrollView {
                    LazyVStack(spacing: 0) {
                        if !pinnedPortStates.isEmpty {
                            sectionLabel("PINNED")
                            ForEach(pinnedPortStates, id: \.port) { state in
                                if let listener = state.listener {
                                    PortRow(
                                        port: listener,
                                        annotation: preferences.annotation(for: listener.port),
                                        service: matchingService(for: listener),
                                        terminalApplication: preferences.terminalApplication,
                                        isPinned: true,
                                        onTogglePin: { preferences.togglePinnedPort(listener.port) },
                                        onCopyPID: { copy("\(listener.pid)") },
                                        onCopyKill: { copy("kill \(listener.pid)") },
                                        onTerminate: { portToTerminate = listener }
                                    )
                                } else {
                                    OfflinePinnedPortRow(port: state.port, annotation: preferences.annotation(for: state.port)) {
                                        preferences.togglePinnedPort(state.port)
                                    }
                                }
                                Divider().padding(.leading, 44)
                            }
                        }

                        if !unpinnedFilteredPorts.isEmpty && !pinnedPortStates.isEmpty {
                            sectionLabel("ACTIVE PORTS")
                        }

                        if pinnedPortStates.isEmpty && unpinnedFilteredPorts.isEmpty {
                            emptyState
                        } else {
                            ForEach(unpinnedFilteredPorts) { port in
                                PortRow(
                                    port: port,
                                    annotation: preferences.annotation(for: port.port),
                                    service: matchingService(for: port),
                                    terminalApplication: preferences.terminalApplication,
                                    isPinned: false,
                                    onTogglePin: { preferences.togglePinnedPort(port.port) },
                                    onCopyPID: { copy("\(port.pid)") },
                                    onCopyKill: { copy("kill \(port.pid)") },
                                    onTerminate: { portToTerminate = port }
                                )
                                Divider().padding(.leading, 44)
                            }
                        }
                    }
                }
                .frame(minHeight: 180, maxHeight: 360)

                Divider()
                footer
            }
            .frame(width: 390)

            if let port = portToTerminate {
                terminationConfirmation(for: port)
                    .zIndex(1)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func terminationConfirmation(for port: ListeningPort) -> some View {
        ZStack {
            Color.black.opacity(0.28)
                .ignoresSafeArea()

            VStack(spacing: 13) {
                Image(systemName: "stop.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.red)
                Text("Terminate \(port.processName)?")
                    .font(.system(size: 15, weight: .semibold))
                Text(verbatim: "Stops PID \(port.pid) and its child processes. This cannot be undone.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                HStack(spacing: 8) {
                    Button("Cancel") {
                        portToTerminate = nil
                    }
                    .keyboardShortcut(.cancelAction)
                    Spacer()
                    Button("Terminate", role: .destructive) {
                        portToTerminate = nil
                        monitor.terminateProcessTree(rootPID: port.pid)
                    }
                    .keyboardShortcut(.defaultAction)
                }
                .controlSize(.regular)
            }
            .padding(20)
            .frame(width: 300)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .shadow(color: .black.opacity(0.25), radius: 18, y: 8)
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            ZStack {
                Circle().fill(appAccent.opacity(0.16))
                Image("PortBarLogo")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .padding(6)
                    .foregroundStyle(appAccent)
            }
            .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 1) {
                Text("PortBar").font(.system(size: 14, weight: .semibold))
                Text("Listening for new connections...").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 5) {
                Circle().fill(.green).frame(width: 6, height: 6)
                Text(statusTitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var quickFilters: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(popupQuickFilters) { filter in
                    QuickFilterButton(filter: filter, isSelected: selectedFilterID == filter.id) {
                        selectedFilterID = selectedFilterID == filter.id ? nil : filter.id
                    }
                }
            }
        }
        .frame(height: quickFilterTrayHeight)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: emptyStateIcon)
                .font(.title2)
                .foregroundStyle(observedListenerCount == 0 ? .green : .secondary)
            Text(emptyStateTitle)
                .font(.system(size: 13, weight: .medium))
            Text(emptyStateMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 38)
    }

    private var statusTitle: String {
        if preferences.showsAllListeners {
            return "\(serviceMatchedPorts.count) listening"
        }
        return "\(serviceMatchedPorts.count) matched"
    }

    private var emptyStateIcon: String {
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "magnifyingglass"
        }
        return observedListenerCount == 0 ? "checkmark.circle" : "line.3.horizontal.decrease.circle"
    }

    private var emptyStateTitle: String {
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "No search results"
        }
        if observedListenerCount == 0 {
            return "No listening ports"
        }
        if let selectedFilter {
            return "No \(selectedFilter.label) matches"
        }
        return preferences.showsAllListeners ? "No visible listeners" : "No service matches"
    }

    private var emptyStateMessage: String {
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "No visible listener matches your search."
        }
        if observedListenerCount == 0 {
            return "PortBar is watching for local services."
        }
        if selectedFilter != nil {
            return "None of the \(observedListenerCount) observed listeners satisfy this group’s rules."
        }
        if preferences.showsAllListeners {
            return "No visible listeners are available."
        }
        return "\(observedListenerCount) listeners are active, but none match an enabled service rule."
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.top, 13)
            .padding(.bottom, 5)
    }

    private func matchesCurrentFilter(port: Int, processName: String, launchCommand: String) -> Bool {
        let quickMatch: Bool
        if let selectedFilter {
            let temporary = ListeningPort(port: port, processName: processName, launchCommand: launchCommand, pid: 0, address: "", firstSeen: .now)
            quickMatch = selectedFilter.matches(temporary)
        } else {
            quickMatch = true
        }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return quickMatch && (query.isEmpty || "\(port) \(processName)".localizedCaseInsensitiveContains(query))
    }

    private func matchesAnyEnabledService(_ port: ListeningPort) -> Bool {
        preferences.quickFilters.contains { $0.isEnabled && $0.matches(port) }
    }

    private func matchingService(for port: ListeningPort) -> QuickFilter? {
        if let selectedFilter, selectedFilter.matches(port) {
            return selectedFilter
        }
        return preferences.quickFilters.first { $0.isEnabled && $0.matches(port) }
    }

    private func displayPriority(for port: ListeningPort) -> Int {
        if preferences.pinnedPorts.contains(port.port) { return 2 }
        return preferences.quickFilters.contains(where: { $0.isEnabled && $0.matches(port) }) ? 1 : 0
    }

    private var footer: some View {
        HStack {
            Text("Updated every \(preferences.pollingInterval.formatted(.number.precision(.fractionLength(0...2)))) seconds")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Spacer()
            HoverIconButton(systemName: "gearshape", tint: .secondary, help: "Settings", action: openAndFocusSettings)
            HoverIconButton(systemName: "power", tint: .secondary, help: "Quit PortBar") {
                NSApplication.shared.terminate(nil)
            }
        }
        .font(.system(size: 12))
        .padding(.horizontal, 14)
        .frame(height: 38)
    }

    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func openAndFocusSettings() {
        NSApp.activate(ignoringOtherApps: true)
        openSettings()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            NSApp.activate(ignoringOtherApps: true)
            let settingsWindow = NSApp.windows.last { window in
                window.isVisible && window.styleMask.contains(.titled)
            }
            settingsWindow?.orderFrontRegardless()
            settingsWindow?.makeKeyAndOrderFront(nil)
        }
    }
}

private struct PortRow: View {
    @Environment(\.portBarAccent) private var appAccent
    let port: ListeningPort
    let annotation: PortAnnotation
    let service: QuickFilter?
    let terminalApplication: TerminalApplication
    let isPinned: Bool
    let onTogglePin: () -> Void
    let onCopyPID: () -> Void
    let onCopyKill: () -> Void
    let onTerminate: () -> Void

    private var title: String {
        if !annotation.label.isEmpty { return annotation.label }
        return service?.label ?? port.processName
    }

    private var statusColor: Color {
        service.map { FilterTint.color(for: $0.tint) } ?? .green
    }

    @State private var isHovered = false
    @State private var showsInspector = false
    @State private var inspectionTask: Task<Void, Never>?
    @State private var inspectionDismissTask: Task<Void, Never>?

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .shadow(color: statusColor.opacity(0.38), radius: 4)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text(verbatim: "Port \(port.port)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)

            HStack(spacing: 1) {
                HoverIconButton(
                    systemName: isPinned ? "pin.fill" : "pin",
                    tint: isPinned ? appAccent : .secondary,
                    help: isPinned ? "Unpin port" : "Pin port",
                    action: onTogglePin
                )

                Menu {
                    Button("Copy PID", action: onCopyPID)
                    Button("Copy kill command", action: onCopyKill)
                } label: {
                    HoverIconLabel(systemName: "doc.on.doc", tint: .secondary)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .foregroundStyle(.secondary)
                .help("Copy")

                HoverIconButton(
                    systemName: "stop.fill",
                    tint: .red,
                    help: "Terminate process tree",
                    action: onTerminate
                )
            }
            .padding(2)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(isHovered ? Color.primary.opacity(0.055) : .clear)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
            updateInspector(forRowHover: hovering)
        }
        .popover(isPresented: $showsInspector, attachmentAnchor: .rect(.bounds), arrowEdge: .trailing) {
            ProcessDetailPanel(
                port: port,
                annotation: annotation,
                service: service,
                terminalApplication: terminalApplication,
                onCopyProcessTitle: { copy(port.launchCommand) },
                onHoverChange: updateInspector(forPanelHover:)
            )
            .frame(width: 272)
        }
    }

    private func updateInspector(forRowHover isHovering: Bool) {
        inspectionDismissTask?.cancel()
        inspectionTask?.cancel()

        guard isHovering else {
            scheduleInspectorDismissal()
            return
        }

        inspectionTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(800))
            guard !Task.isCancelled else { return }
            showsInspector = true
        }
    }

    private func updateInspector(forPanelHover isHovering: Bool) {
        if isHovering {
            inspectionDismissTask?.cancel()
        } else {
            scheduleInspectorDismissal()
        }
    }

    private func scheduleInspectorDismissal() {
        inspectionDismissTask?.cancel()
        inspectionDismissTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(220))
            guard !Task.isCancelled else { return }
            showsInspector = false
        }
    }

    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

private struct QuickFilterButton: View {
    @Environment(\.portBarAccent) private var appAccent
    let filter: QuickFilter
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: filter.symbol)
                    .frame(width: 14)
                    .foregroundStyle(isSelected ? Color.white : FilterTint.color(for: filter.tint))
                Text(filter.label).lineLimit(1)
                Spacer(minLength: 0)
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .padding(.horizontal, 8)
            .frame(height: 28)
            .background(
                isSelected ? appAccent : Color.primary.opacity(isHovered ? 0.12 : 0.06),
                in: RoundedRectangle(cornerRadius: 6, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered && !isSelected ? 1.015 : 1)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }
}

private struct HoverIconButton: View {
    let systemName: String
    let tint: Color
    let help: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
                .background(isHovered ? Color.primary.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(tint)
        .help(help)
        .scaleEffect(isHovered ? 1.04 : 1)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }
}

private struct HoverIconLabel: View {
    let systemName: String
    let tint: Color

    @State private var isHovered = false

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 11, weight: .semibold))
            .frame(width: 26, height: 26)
            .contentShape(Rectangle())
            .background(isHovered ? Color.primary.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            .foregroundStyle(tint)
            .scaleEffect(isHovered ? 1.04 : 1)
            .onHover { isHovered = $0 }
            .animation(.easeOut(duration: 0.12), value: isHovered)
    }
}

private struct CopyFieldButton: View {
    @Environment(\.portBarAccent) private var appAccent
    let value: String
    let label: String

    @State private var isHovered = false

    var body: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(value, forType: .string)
        } label: {
            Image(systemName: "doc.on.doc")
                .font(.system(size: 9, weight: .semibold))
                .frame(width: 18, height: 18)
                .background(isHovered ? Color.primary.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(isHovered ? appAccent : .secondary)
        .help("Copy \(label)")
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }
}

private struct DirectoryActionButton: View {
    let systemName: String
    let title: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemName)
                .font(.system(size: 10, weight: .medium))
                .padding(.horizontal, 7)
                .frame(height: 24)
                .background(isHovered ? Color.primary.opacity(0.12) : Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(isHovered ? Color.primary : .secondary)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }
}

private struct ProcessDetailPanel: View {
    let port: ListeningPort
    let annotation: PortAnnotation
    let service: QuickFilter?
    let terminalApplication: TerminalApplication
    let onCopyProcessTitle: () -> Void
    let onHoverChange: (Bool) -> Void

    private var title: String {
        annotation.label.isEmpty ? (service?.label ?? port.processName) : annotation.label
    }

    private var serviceColor: Color {
        service.map { FilterTint.color(for: $0.tint) } ?? .green
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                ZStack {
                    Circle().fill(serviceColor.opacity(0.16))
                    Image(systemName: service?.symbol ?? "terminal.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(serviceColor)
                }
                .frame(width: 30, height: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                    Text("Listening now")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Circle().fill(.green).frame(width: 7, height: 7)
            }
            .padding(14)

            Divider()

            VStack(alignment: .leading, spacing: 11) {
                copyableDetailRow("Port", value: String(port.port))
                copyableDetailRow("Process", value: port.processName)
                copyableDetailRow("PID", value: String(port.pid))
                copyableDetailRow("Address", value: port.address)
            }
            .padding(14)

            if port.parentPID != nil || !port.elapsedTime.isEmpty {
                Divider()

                VStack(alignment: .leading, spacing: 11) {
                    Text("RUNTIME")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                    if let parentPID = port.parentPID {
                        copyableDetailRow("Parent PID", value: String(parentPID))
                    }
                    if !port.elapsedTime.isEmpty {
                        copyableDetailRow("Running for", value: port.elapsedTime)
                    }
                }
                .padding(14)
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("SPAWNED FROM")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                if port.workingDirectory.isEmpty {
                    Text("Working directory unavailable for this process.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(port.workingDirectory)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .textSelection(.enabled)
                    HStack(spacing: 5) {
                        DirectoryActionButton(systemName: "folder", title: "Finder", action: openInFinder)
                        DirectoryActionButton(systemName: "terminal", title: "Terminal", action: openInTerminal)
                        DirectoryActionButton(systemName: "doc.on.doc", title: "Copy", action: copyWorkingDirectory)
                    }
                }
            }
            .padding(14)

            if !port.launchCommand.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 7) {
                    Text("PROCESS TITLE")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(port.launchCommand)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                        .textSelection(.enabled)
                    DirectoryActionButton(systemName: "doc.on.doc", title: "Copy", action: onCopyProcessTitle)
                }
                .padding(14)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .contentShape(Rectangle())
        .onHover(perform: onHoverChange)
    }

    private func openInFinder() {
        guard !port.workingDirectory.isEmpty else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: port.workingDirectory, isDirectory: true))
    }

    private func openInTerminal() {
        guard !port.workingDirectory.isEmpty else { return }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-a", terminalApplication.rawValue, port.workingDirectory]
        try? task.run()
    }

    private func copyWorkingDirectory() {
        guard !port.workingDirectory.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(port.workingDirectory, forType: .string)
    }

    private func copyableDetailRow(_ label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
            CopyFieldButton(value: value, label: label)
        }
    }
}

private struct OfflinePinnedPortRow: View {
    @Environment(\.portBarAccent) private var appAccent
    let port: Int
    let annotation: PortAnnotation
    let onUnpin: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Circle().fill(.secondary.opacity(0.45)).frame(width: 7, height: 7)
            Text(verbatim: ":\(port)")
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .frame(width: 60, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(annotation.label.isEmpty ? "Not running" : annotation.label)
                    .font(.system(size: 13, weight: .medium))
                Text(annotation.note.isEmpty ? "Pinned port" : annotation.note)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: onUnpin) {
                Image(systemName: "pin.fill")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .foregroundStyle(appAccent)
            .help("Unpin port")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .opacity(0.72)
    }
}
