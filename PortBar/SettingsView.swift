//
//  SettingsView.swift
//  PortBar
//

import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var monitor: PortMonitor
    @ObservedObject var preferences: PreferencesStore
    @ObservedObject var notifications: PortNotificationManager
    @State private var selectedFilterID: QuickFilter.ID?
    @State private var selectedPackID: ServicePack.ID?
    @State private var isReordering = false
    @State private var showsTerminateGroupAlert = false
    @State private var showsRestoreDefaultsAlert = false
    @State private var portBeingEdited: ListeningPort?
    @State private var isAdvancedMatchingExpanded = false

    private let packColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 2)

    private var selectedFilter: Binding<QuickFilter>? {
        guard let id = selectedFilterID,
              preferences.quickFilters.contains(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { preferences.quickFilters.first(where: { $0.id == id })! },
            set: { preferences.update($0) }
        )
    }

    private var selectedFilterValue: QuickFilter? {
        selectedFilter?.wrappedValue
    }

    private var selectedPack: ServicePack? {
        guard let selectedPackID else { return nil }
        return ServiceCatalog.packs.first { $0.id == selectedPackID }
    }

    private var matchingPorts: [ListeningPort] {
        guard let filter = selectedFilterValue else { return [] }
        return monitor.ports.filter(filter.matches)
    }

    private var enabledCount: Int {
        preferences.quickFilters.filter(\.isEnabled).count
    }

    private var lastScanDescription: String {
        guard let date = monitor.lastScanDate else { return "Waiting for first scan" }
        return "Last scan " + date.formatted(.relative(presentation: .named))
    }

    var body: some View {
        HStack(spacing: 0) {
            library
                .frame(width: 300)
            Divider()
            inspector
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: 980, height: 680)
        .onAppear {
            selectedFilterID = selectedFilterID ?? preferences.quickFilters.first?.id
            monitor.setPollingInterval(preferences.pollingInterval)
        }
        .alert("Stop all matching processes?", isPresented: $showsTerminateGroupAlert) {
            Button("Stop processes", role: .destructive) {
                matchingPorts
                    .map(\.pid)
                    .reduce(into: Set<Int32>()) { $0.insert($1) }
                    .forEach(monitor.terminateProcessTree)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("PortBar will stop the \(matchingPorts.count) currently visible listener\(matchingPorts.count == 1 ? "" : "s") in \(selectedFilterValue?.label ?? "this group") and their child processes.")
        }
        .alert("Restore service defaults?", isPresented: $showsRestoreDefaultsAlert) {
            Button("Restore", role: .destructive) {
                guard let filter = selectedFilterValue else { return }
                preferences.restoreDefaults(for: filter)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This restores the built-in ports, process matching, color, and alert settings for \(selectedFilterValue?.label ?? "this service").")
        }
        .popover(item: $portBeingEdited, arrowEdge: .trailing) { port in
            PortAnnotationEditor(port: port, preferences: preferences)
        }
    }

    private var library: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Quick filters")
                        .font(.system(size: 15, weight: .semibold))
                    Text("\(enabledCount) of \(preferences.quickFilters.count) shown in menu")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    isReordering.toggle()
                } label: {
                    Image(systemName: isReordering ? "checkmark" : "arrow.up.arrow.down")
                }
                .buttonStyle(.plain)
                .help(isReordering ? "Done reordering" : "Reorder quick filters")
            }
            .padding(.horizontal, 16)
            .frame(height: 64)

            Divider()

            ScrollViewReader { scrollProxy in
                VStack(spacing: 0) {
                    developerPacks(using: scrollProxy)

                    Divider()

                    List(selection: $selectedFilterID) {
                        ForEach(ServiceCatalog.sections) { section in
                            let filters = filters(in: section)
                            if !filters.isEmpty {
                                Section(section.label) {
                                    ForEach(filters) { filter in
                                        serviceRow(filter, in: section)
                                    }
                                }
                            }
                        }

                        let customFilters = customServiceFilters
                        if !customFilters.isEmpty {
                            Section("Custom") {
                                ForEach(customFilters) { filter in
                                    serviceRow(filter, in: ServiceSection(id: "custom", label: "Custom", serviceLabels: customFilters.map(\.label)))
                                }
                            }
                        }
                    }
                    .listStyle(.sidebar)
                    .scrollContentBackground(.hidden)
                    .background(Color(nsColor: .windowBackgroundColor))
                    .onChange(of: selectedFilterID) { _, selectedFilterID in
                        if selectedFilterID != nil {
                            selectedPackID = nil
                        }
                    }
                }
            }

            Divider()
            statusAndMenuOptions
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func developerPacks(using scrollProxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("DEVELOPER PACKS")
                        .sectionLabelStyle()
                    Text("Choose a pack to configure its services.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            ScrollView(.vertical, showsIndicators: true) {
                LazyVGrid(columns: packColumns, spacing: 8) {
                    ForEach(ServiceCatalog.packs) { pack in
                        Button {
                            selectedFilterID = nil
                            selectedPackID = pack.id
                            scrollToStart(of: pack, using: scrollProxy)
                        } label: {
                            packTile(for: pack)
                        }
                        .buttonStyle(.plain)
                        .help("Open \(pack.label) pack")
                        .contextMenu {
                            Button("Enable all \(pack.label) services", systemImage: "checkmark.circle") {
                                preferences.enable(pack)
                            }
                            .disabled(enabledServiceCount(in: pack) == pack.serviceLabels.count)
                        }
                    }
                }
            }
            .frame(height: 92)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func packTile(for pack: ServicePack) -> some View {
        let enabled = enabledServiceCount(in: pack)
        let isComplete = enabled == pack.serviceLabels.count
        let isSelected = selectedPackID == pack.id

        return HStack(spacing: 8) {
            Image(systemName: isComplete ? "checkmark.circle.fill" : pack.symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isComplete ? Color.accentColor : .secondary)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(pack.label)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                Text(isComplete ? "All enabled" : "\(enabled) of \(pack.serviceLabels.count) enabled")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
        .padding(.horizontal, 9)
        .background((isSelected ? Color.accentColor.opacity(0.14) : isComplete ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.045)), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSelected || isComplete ? Color.accentColor.opacity(isSelected ? 0.42 : 0.22) : Color.primary.opacity(0.08), lineWidth: isSelected ? 1.5 : 1)
        }
    }

    private func enabledServiceCount(in pack: ServicePack) -> Int {
        let labels = Set(pack.serviceLabels.map { $0.lowercased() })
        return preferences.quickFilters.filter { $0.isEnabled && labels.contains($0.label.lowercased()) }.count
    }

    private func scrollToStart(of pack: ServicePack, using scrollProxy: ScrollViewProxy) {
        guard let section = ServiceCatalog.sections.first(where: { $0.id == pack.sectionID }),
              let firstFilter = filters(in: section).first else { return }
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.2)) {
                scrollProxy.scrollTo(firstFilter.id, anchor: .top)
            }
        }
    }

    private func filters(in section: ServiceSection) -> [QuickFilter] {
        let labels = Set(section.serviceLabels.map { $0.lowercased() })
        return preferences.quickFilters.filter { labels.contains($0.label.lowercased()) }
    }

    private func filters(in pack: ServicePack) -> [QuickFilter] {
        let labels = Set(pack.serviceLabels.map { $0.lowercased() })
        return preferences.quickFilters
            .filter { labels.contains($0.label.lowercased()) }
            .sorted { lhs, rhs in
                let leftIndex = pack.serviceLabels.firstIndex { $0.caseInsensitiveCompare(lhs.label) == .orderedSame } ?? .max
                let rightIndex = pack.serviceLabels.firstIndex { $0.caseInsensitiveCompare(rhs.label) == .orderedSame } ?? .max
                return leftIndex < rightIndex
            }
    }

    private var customServiceFilters: [QuickFilter] {
        let catalogLabels = Set(ServiceCatalog.sections.flatMap(\.serviceLabels).map { $0.lowercased() })
        return preferences.quickFilters.filter { !catalogLabels.contains($0.label.lowercased()) }
    }

    private func serviceRow(_ filter: QuickFilter, in section: ServiceSection) -> some View {
        let sectionFilters = filters(in: section)
        let isFirst = sectionFilters.first?.id == filter.id
        let isLast = sectionFilters.last?.id == filter.id
        let activeProcessCount = Set(monitor.ports.filter(filter.matches).map(\.pid)).count

        return HStack(spacing: 10) {
            Toggle("", isOn: enabledBinding(for: filter.id))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
            Image(systemName: filter.symbol)
                .frame(width: 16)
                .foregroundStyle(FilterTint.color(for: filter.tint))
            VStack(alignment: .leading, spacing: 2) {
                Text(filter.label)
                    .font(.system(size: 13, weight: .medium))
                Text(filter.ports.isEmpty ? (filter.processPattern.isEmpty ? "No matching rule" : "Process match") : filter.ports)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if activeProcessCount > 0 {
                Text("\(activeProcessCount)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .help("\(activeProcessCount) active matching process\(activeProcessCount == 1 ? "" : "es")")
            }
            if isReordering {
                HStack(spacing: 4) {
                    Button { preferences.moveQuickFilter(id: filter.id, within: section.serviceLabels, by: -1) } label: { Image(systemName: "chevron.up") }
                        .buttonStyle(.plain)
                        .disabled(isFirst)
                    Button { preferences.moveQuickFilter(id: filter.id, within: section.serviceLabels, by: 1) } label: { Image(systemName: "chevron.down") }
                        .buttonStyle(.plain)
                        .disabled(isLast)
                }
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
            }
        }
        .tag(filter.id)
        .opacity(filter.isEnabled ? 1 : 0.55)
    }

    private var statusAndMenuOptions: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("MONITORING")
                        .sectionLabelStyle()
                    Text("\(monitor.ports.count) active · \(preferences.pinnedPorts.count) pinned")
                        .font(.system(size: 12, weight: .medium))
                    Text(lastScanDescription)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: monitor.refresh) { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.plain)
                    .help("Scan now")
            }
            Divider()
            Toggle("Launch at login", isOn: Binding(
                get: { preferences.launchAtLogin },
                set: { preferences.setLaunchAtLogin($0) }
            ))
            .toggleStyle(.switch)
        }
        .font(.system(size: 12))
        .padding(16)
    }

    @ViewBuilder
    private var inspector: some View {
        if let pack = selectedPack {
            packInspector(pack)
        } else if let filter = selectedFilter {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    inspectorHeader(filter)
                    Divider()
                    VStack(alignment: .leading, spacing: 20) {
                        matchingSection(filter)
                        Divider()
                        matchingNowSection
                        Divider()
                        recentActivitySection(filter.wrappedValue)
                        Divider()
                        footerActions
                    }
                    .padding(32)
                }
            }
        } else {
            ContentUnavailableView("Select a quick filter", systemImage: "slider.horizontal.3", description: Text("Pick a group on the left or restore a preset."))
        }
    }

    private func packInspector(_ pack: ServicePack) -> some View {
        let services = filters(in: pack)
        let enabled = enabledServiceCount(in: pack)
        let isComplete = enabled == pack.serviceLabels.count

        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 11)
                            .fill(Color.accentColor.opacity(0.13))
                        Image(systemName: pack.symbol)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(Color.accentColor)
                    }
                    .frame(width: 50, height: 50)

                    VStack(alignment: .leading, spacing: 5) {
                        Text("Pack: \(pack.label)")
                            .font(.system(size: 22, weight: .semibold))
                        Text(pack.description)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Text("Best for \(pack.bestFor).")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.accentColor)
                    }
                    Spacer(minLength: 12)
                    VStack(alignment: .trailing, spacing: 8) {
                        Text("\(enabled) of \(pack.serviceLabels.count) enabled")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                        HStack(spacing: 7) {
                            Button("Enable all") { preferences.enable(pack) }
                                .disabled(isComplete)
                            Button("Disable all") { preferences.disable(pack) }
                                .disabled(enabled == 0)
                        }
                        .controlSize(.small)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.top, 30)
                .padding(.bottom, 24)

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("SERVICES").sectionLabelStyle()
                            Text("Enable only the local tools you want PortBar to show.")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }

                    VStack(spacing: 0) {
                        ForEach(services) { service in
                            packServiceRow(service)
                            if service.id != services.last?.id {
                                Divider()
                            }
                        }
                    }
                }
                .padding(32)
            }
        }
    }

    private func packServiceRow(_ service: QuickFilter) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Toggle("", isOn: enabledBinding(for: service.id))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
            Image(systemName: service.symbol)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 20)
                .foregroundStyle(FilterTint.color(for: service.tint))
            VStack(alignment: .leading, spacing: 3) {
                Text(service.label)
                    .font(.system(size: 14, weight: .semibold))
                Text(ServiceCatalog.serviceDescription(for: service.label))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            Text(service.ports.isEmpty ? "Process" : service.ports)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 112, alignment: .trailing)
        }
        .padding(.vertical, 10)
        .opacity(service.isEnabled ? 1 : 0.6)
    }

    private func inspectorHeader(_ filter: Binding<QuickFilter>) -> some View {
        HStack(alignment: .top) {
            ZStack {
                RoundedRectangle(cornerRadius: 11)
                    .fill(FilterTint.color(for: filter.wrappedValue.tint).opacity(0.14))
                Image(systemName: filter.wrappedValue.symbol)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(FilterTint.color(for: filter.wrappedValue.tint))
            }
            .frame(width: 50, height: 50)

            VStack(alignment: .leading, spacing: 4) {
                Text(filter.wrappedValue.label)
                    .font(.system(size: 22, weight: .semibold))
                Text("Built-in service group for matching local listeners.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 9) {
                Toggle("Enabled", isOn: filter.isEnabled)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                if ServiceCatalog.defaults(for: filter.wrappedValue.label) != nil {
                    Button("Restore defaults") {
                        showsRestoreDefaultsAlert = true
                    }
                    .controlSize(.small)
                    .help("Restore this service's built-in matching rules")
                }
            }
        }
        .padding(.horizontal, 32)
        .padding(.top, 30)
        .padding(.bottom, 24)
    }

    private func matchingSection(_ filter: Binding<QuickFilter>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PORTS").sectionLabelStyle()
            PortRuleEditor(ports: filter.ports)
                .id(filter.wrappedValue.id)
            ruleExplanation(for: filter.wrappedValue)
            advancedMatchingSection(filter)
        }
    }

    private func advancedMatchingSection(_ filter: Binding<QuickFilter>) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.16)) {
                    isAdvancedMatchingExpanded.toggle()
                }
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: isAdvancedMatchingExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 12)
                    Text("Advanced matching & alerts")
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel("Advanced matching and alerts")
            .accessibilityValue(isAdvancedMatchingExpanded ? "Expanded" : "Collapsed")

            if isAdvancedMatchingExpanded {
                advancedMatchingContent(filter)
                    .padding(.top, 12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func advancedMatchingContent(_ filter: Binding<QuickFilter>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            TermRuleEditor(
                title: "Process fallback",
                detail: "Used only when this service has no port rules. Matches lsof’s short process name.",
                addLabel: "Add process name",
                prompt: "Process name, e.g. python",
                symbol: "cpu",
                pattern: filter.processPattern
            )
            TermRuleEditor(
                title: "Started as",
                detail: "After the port rules match, the running command must contain one fragment below. PortBar reads the live ps command, not shell history.",
                addLabel: "Add startup-command fragment",
                prompt: "Command fragment, e.g. next-server",
                symbol: "terminal",
                pattern: filter.launchCommandPattern
            )
            TermRuleEditor(
                title: "Exclude process",
                detail: "A veto rule for lsof process names. It is checked first, so excluded processes never match this service.",
                addLabel: "Add excluded process",
                prompt: "Process name, e.g. helper",
                symbol: "xmark.circle",
                pattern: filter.excludedProcessPattern
            )
            Toggle("Notify when this service starts or stops", isOn: filter.notificationsEnabled)
                .toggleStyle(.switch)
                .onChange(of: filter.wrappedValue.notificationsEnabled) { _, enabled in
                    if enabled { notifications.requestPermission() }
                }
        }
        .font(.system(size: 13, weight: .medium))
    }

    private var matchingNowSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("MATCHING NOW").sectionLabelStyle()
                    Text(matchingPorts.isEmpty ? "No active listeners match this group." : "\(matchingPorts.count) active listener\(matchingPorts.count == 1 ? "" : "s")")
                        .font(.system(size: 13, weight: .medium))
                }
                Spacer()
                Menu {
                    Button("Copy port list", action: copyMatchingPorts)
                        .disabled(matchingPorts.isEmpty)
                    Button("Pin matching ports", action: { preferences.pin(matchingPorts.map(\.port)) })
                        .disabled(matchingPorts.isEmpty)
                    Button("Unpin matching ports", action: { preferences.unpin(matchingPorts.map(\.port)) })
                        .disabled(matchingPorts.isEmpty)
                    Divider()
                    Button("Stop matching processes", role: .destructive) { showsTerminateGroupAlert = true }
                        .disabled(matchingPorts.isEmpty)
                } label: {
                    Label("Actions", systemImage: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
            }
            if !matchingPorts.isEmpty {
                ForEach(matchingPorts.prefix(5)) { port in
                    HStack(spacing: 9) {
                        Circle().fill(.green).frame(width: 6, height: 6)
                        Text(":\(port.port)")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .frame(width: 54, alignment: .leading)
                        Text(port.processName)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                        Text("PID \(port.pid)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Spacer()
                        if let annotation = annotationSummary(for: port), !annotation.isEmpty {
                            Text(annotation)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Button { portBeingEdited = port } label: {
                            Image(systemName: "note.text")
                        }
                        .buttonStyle(.plain)
                        .help("Edit port label and note")
                    }
                    .help(port.launchCommand.isEmpty ? "Startup command unavailable" : "Started as: \(port.launchCommand)")
                }
                if matchingPorts.count > 5 {
                    Text("+ \(matchingPorts.count - 5) more matching listeners")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func recentActivitySection(_ filter: QuickFilter) -> some View {
        let history = monitor.recentlyStopped.filter { filter.matches(port: $0.port, processName: $0.processName, launchCommand: $0.launchCommand) }.prefix(5)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("RECENTLY STOPPED").sectionLabelStyle()
                    Text(history.isEmpty ? "No recent stopped listeners for this group." : "Last \(history.count) stopped listener\(history.count == 1 ? "" : "s")")
                        .font(.system(size: 13, weight: .medium))
                }
                Spacer()
                if !monitor.recentlyStopped.isEmpty {
                    Text("In this session")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            ForEach(Array(history)) { port in
                HStack(spacing: 9) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 7))
                        .foregroundStyle(.secondary)
                    Text(":\(port.port)")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .frame(width: 54, alignment: .leading)
                    Text(port.processName)
                        .font(.system(size: 12, weight: .medium))
                    Text("PID \(port.pid) · \(Duration.seconds(port.duration).formatted(.units(allowed: [.minutes, .seconds], width: .abbreviated))) · \(port.stoppedAt.formatted(.relative(presentation: .named)))")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                }
            }
        }
    }

    private var footerActions: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("DIAGNOSTICS").sectionLabelStyle()
                Text("lsof -nP -iTCP -sTCP:LISTEN")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                if let error = monitor.lastScanError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                } else {
                    Text("Scanner healthy · \(lastScanDescription)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button("Duplicate", action: duplicateSelectedFilter)
            Button(role: .destructive, action: removeSelectedFilter) {
                Label("Remove", systemImage: "trash")
            }
        }
    }

    private func enabledBinding(for id: QuickFilter.ID) -> Binding<Bool> {
        Binding(
            get: { preferences.quickFilters.first(where: { $0.id == id })?.isEnabled ?? false },
            set: { isEnabled in
                guard var filter = preferences.quickFilters.first(where: { $0.id == id }) else { return }
                filter.isEnabled = isEnabled
                preferences.update(filter)
            }
        )
    }

    private func annotationSummary(for port: ListeningPort) -> String? {
        let annotation = preferences.annotation(for: port.port)
        return annotation.label.isEmpty ? (annotation.note.isEmpty ? nil : annotation.note) : annotation.label
    }

    private func ruleExplanationItems(for filter: QuickFilter) -> [RuleExplanationItem] {
        var items: [RuleExplanationItem] = []

        if !filter.portNumbers.isEmpty {
            items.append(.init(id: "ports", symbol: "checkmark.circle.fill", tone: .green, text: "A listener is included when it uses \(plainEnglishPorts(filter.ports))."))
        } else if !filter.processTerms.isEmpty {
            items.append(.init(id: "fallback", symbol: "checkmark.circle.fill", tone: .green, text: "A listener is included when its process name contains \(quotedList(filter.processTerms))."))
        } else {
            items.append(.init(id: "missing", symbol: "exclamationmark.circle", tone: .orange, text: "Nothing can match yet—add a listening port or a process fallback."))
        }

        if !filter.portNumbers.isEmpty && !filter.processTerms.isEmpty {
            items.append(.init(id: "fallback-inactive", symbol: "info.circle", tone: .secondary, text: "The process fallback list is inactive because this service has port rules."))
        }

        if !filter.launchCommandTerms.isEmpty {
            items.append(.init(id: "command", symbol: "terminal", tone: .accentColor, text: "Its running command must also contain \(quotedList(filter.launchCommandTerms))."))
        } else {
            items.append(.init(id: "command-none", symbol: "terminal", tone: .secondary, text: "There is no startup-command restriction."))
        }

        if !filter.exclusionTerms.isEmpty {
            items.append(.init(id: "exclusions", symbol: "xmark.circle", tone: .red, text: "A listener is excluded when its process name contains \(quotedList(filter.exclusionTerms))."))
        } else {
            items.append(.init(id: "exclusions-none", symbol: "xmark.circle", tone: .secondary, text: "No process names are excluded."))
        }

        return items
    }

    private func ruleExplanation(for filter: QuickFilter) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("HOW PORTBAR DECIDES")
                .sectionLabelStyle()
            ForEach(ruleExplanationItems(for: filter)) { item in
                RuleExplanationRow(item: item)
            }
        }
        .padding(.vertical, 2)
    }

    private func plainEnglishPorts(_ ports: String) -> String {
        let values = ports
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).replacing("-", with: "–") }
            .filter { !$0.isEmpty }
            .map { value in value.contains("–") ? "ports \(value)" : "port \(value)" }
        return joinedEnglish(values)
    }

    private func quotedList(_ values: [String]) -> String {
        joinedEnglish(values.map { "“\($0)”" })
    }

    private func joinedEnglish(_ values: [String]) -> String {
        switch values.count {
        case 0: return ""
        case 1: return values[0]
        case 2: return "\(values[0]) or \(values[1])"
        default: return values.dropLast().joined(separator: ", ") + ", or \(values.last!)"
        }
    }

    private func copyMatchingPorts() {
        let text = matchingPorts.map { "\($0.port)\t\($0.processName)\tPID \($0.pid)\t\($0.launchCommand)" }.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func toggle(_ pack: ServicePack) {
        let isComplete = enabledServiceCount(in: pack) == pack.serviceLabels.count
        if isComplete {
            preferences.disable(pack)
        } else {
            preferences.enable(pack)
        }
    }

    private func addFilter() {
        let newFilter = QuickFilter(symbol: "circle.grid.2x2", label: "New filter", ports: "", processPattern: "")
        preferences.quickFilters.append(newFilter)
        selectedFilterID = newFilter.id
    }

    private func duplicateSelectedFilter() {
        guard let source = selectedFilter?.wrappedValue else { return }
        var copy = source
        copy.id = UUID()
        copy.label += " copy"
        preferences.quickFilters.append(copy)
        selectedFilterID = copy.id
    }

    private func deleteFilters(at offsets: IndexSet) {
        let deletedIDs = offsets.map { preferences.quickFilters[$0].id }
        preferences.quickFilters.remove(atOffsets: offsets)
        if deletedIDs.contains(selectedFilterID ?? UUID()) {
            selectedFilterID = preferences.quickFilters.first?.id
        }
    }

    private func removeSelectedFilter() {
        guard let selectedFilterID,
              let index = preferences.quickFilters.firstIndex(where: { $0.id == selectedFilterID }) else { return }
        preferences.quickFilters.remove(at: index)
        self.selectedFilterID = preferences.quickFilters.first?.id
    }
}

private struct RuleExplanationItem: Identifiable {
    let id: String
    let symbol: String
    let tone: Color
    let text: String
}

private struct RuleExplanationRow: View {
    let item: RuleExplanationItem

    var body: some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: item.symbol)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(item.tone)
                .frame(width: 14, alignment: .center)
                .padding(.top, 1)
            Text(item.text)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct PortRule: Identifiable, Equatable {
    enum Kind: String, CaseIterable, Identifiable {
        case single = "Port"
        case range = "Range"

        var id: String { rawValue }
    }

    var id = UUID()
    var kind: Kind
    var lower: String
    var upper: String

    static func parse(_ value: String) -> [PortRule] {
        value.split(separator: ",").compactMap { component in
            let parts = component.split(separator: "-", maxSplits: 1)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            guard let lower = parts.first, Int(lower) != nil else { return nil }
            if parts.count == 2, let upper = parts.last, Int(upper) != nil {
                return PortRule(kind: .range, lower: lower, upper: upper)
            }
            return PortRule(kind: .single, lower: lower, upper: "")
        }
    }

    var encoded: String? {
        guard let lowerNumber = Int(lower), (1...65_535).contains(lowerNumber) else { return nil }
        switch kind {
        case .single:
            return "\(lowerNumber)"
        case .range:
            guard let upperNumber = Int(upper),
                  (1...65_535).contains(upperNumber),
                  lowerNumber <= upperNumber else { return nil }
            return "\(lowerNumber)-\(upperNumber)"
        }
    }

    var displayName: String {
        switch kind {
        case .single:
            return lower.isEmpty ? "this port" : "port \(lower)"
        case .range:
            if lower.isEmpty || upper.isEmpty { return "this port range" }
            return "ports \(lower)–\(upper)"
        }
    }
}

private struct PortRuleEditor: View {
    @Binding var ports: String
    @State private var rules: [PortRule]

    init(ports: Binding<String>) {
        _ports = ports
        _rules = State(initialValue: PortRule.parse(ports.wrappedValue))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Listening ports")
                    .font(.system(size: 13, weight: .medium))
                Spacer()
                Menu {
                    Button("Single port") {
                        rules.append(PortRule(kind: .single, lower: "", upper: ""))
                    }
                    Button("Port range") {
                        rules.append(PortRule(kind: .range, lower: "", upper: ""))
                    }
                } label: {
                    Label("Add port rule", systemImage: "plus")
                        .labelStyle(.iconOnly)
                }
                .menuStyle(.borderlessButton)
                .help("Add port or range")
            }

            if rules.isEmpty {
                Button {
                    rules.append(PortRule(kind: .single, lower: "", upper: ""))
                } label: {
                    Label("Add a listening port", systemImage: "plus")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .padding(.vertical, 4)
            } else {
                PortRuleList(rules: $rules)
            }
        }
        .onChange(of: rules) { _, updatedRules in
            ports = updatedRules.compactMap(\.encoded).joined(separator: ", ")
        }
        .onChange(of: ports) { _, storedValue in
            let encoded = rules.compactMap(\.encoded).joined(separator: ", ")
            if storedValue != encoded {
                rules = PortRule.parse(storedValue)
            }
        }
    }
}

private struct PortRuleList: View {
    @Binding var rules: [PortRule]
    @State private var pendingRemoval: PortRule?

    var body: some View {
        VStack(spacing: 0) {
            ForEach($rules) { $rule in
                PortRuleRow(rule: $rule) { id in
                    pendingRemoval = rules.first { $0.id == id }
                }
                .padding(.vertical, 5)
                if rule.id != rules.last?.id {
                    Divider()
                }
            }
        }
        .alert("Remove port rule?", isPresented: removalConfirmationPresented) {
            Button("Remove", role: .destructive) {
                if let pendingRemoval {
                    rules.removeAll { $0.id == pendingRemoval.id }
                }
                pendingRemoval = nil
            }
            Button("Cancel", role: .cancel) {
                pendingRemoval = nil
            }
        } message: {
            Text("Remove \(pendingRemoval?.displayName ?? "this port rule") from this service?")
        }
    }

    private var removalConfirmationPresented: Binding<Bool> {
        Binding(
            get: { pendingRemoval != nil },
            set: { isPresented in
                if !isPresented { pendingRemoval = nil }
            }
        )
    }
}

private struct PortRuleRow: View {
    @Binding var rule: PortRule
    let onRemove: (UUID) -> Void

    var body: some View {
        HStack(spacing: 8) {
            portFields
            Spacer()
            removeButton
        }
    }

    @ViewBuilder
    private var portFields: some View {
        if rule.kind == .single {
            TextField("Port", text: $rule.lower)
                .textFieldStyle(.roundedBorder)
                .frame(width: 112)
        } else {
            TextField("From", text: $rule.lower)
                .textFieldStyle(.roundedBorder)
                .frame(width: 92)
            Text("–")
                .foregroundStyle(.secondary)
            TextField("To", text: $rule.upper)
                .textFieldStyle(.roundedBorder)
                .frame(width: 92)
        }
    }

    private var removeButton: some View {
        Button {
            onRemove(rule.id)
        } label: {
            Image(systemName: "minus.circle")
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .help("Remove this port rule")
    }
}

private struct RuleTerm: Identifiable, Equatable {
    let id: UUID
    var value: String

    init(id: UUID = UUID(), value: String) {
        self.id = id
        self.value = value
    }

    static func parse(_ pattern: String) -> [RuleTerm] {
        pattern
            .split(separator: ",")
            .map { RuleTerm(value: $0.trimmingCharacters(in: .whitespacesAndNewlines)) }
            .filter { !$0.value.isEmpty }
    }
}

private struct TermRuleEditor: View {
    let title: String
    let detail: String
    let addLabel: String
    let prompt: String
    let symbol: String
    @Binding var pattern: String
    @State private var terms: [RuleTerm]

    init(
        title: String,
        detail: String,
        addLabel: String,
        prompt: String,
        symbol: String,
        pattern: Binding<String>
    ) {
        self.title = title
        self.detail = detail
        self.addLabel = addLabel
        self.prompt = prompt
        self.symbol = symbol
        _pattern = pattern
        _terms = State(initialValue: RuleTerm.parse(pattern.wrappedValue))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Spacer()
                Button {
                    terms.append(RuleTerm(value: ""))
                } label: {
                    Label(addLabel, systemImage: "plus")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.plain)
                .help(addLabel)
            }

            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)

            if terms.isEmpty {
                Button {
                    terms.append(RuleTerm(value: ""))
                } label: {
                    Label(addLabel, systemImage: "plus")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .padding(.vertical, 2)
            } else {
                VStack(spacing: 5) {
                    ForEach($terms) { $term in
                        TermRuleRow(term: $term, prompt: prompt, symbol: symbol, removalLabel: addLabel) { id in
                            terms.removeAll { $0.id == id }
                        }
                    }
                }
            }
        }
        .onChange(of: terms) { _, updatedTerms in
            pattern = updatedTerms
                .map(\.value)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: ", ")
        }
        .onChange(of: pattern) { _, storedValue in
            let encoded = terms
                .map(\.value)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: ", ")
            if storedValue != encoded {
                terms = RuleTerm.parse(storedValue)
            }
        }
    }
}

private struct TermRuleRow: View {
    @Binding var term: RuleTerm
    let prompt: String
    let symbol: String
    let removalLabel: String
    let onRemove: (UUID) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            TextField(prompt, text: $term.value)
                .textFieldStyle(.roundedBorder)
            Button {
                onRemove(term.id)
            } label: {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Remove \(removalLabel.replacingOccurrences(of: "Add ", with: "").lowercased())")
        }
    }
}

private struct PortAnnotationEditor: View {
    let port: ListeningPort
    @ObservedObject var preferences: PreferencesStore
    @State private var annotation: PortAnnotation

    init(port: ListeningPort, preferences: PreferencesStore) {
        self.port = port
        self.preferences = preferences
        _annotation = State(initialValue: preferences.annotation(for: port.port))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Port :\(port.port)")
                .font(.headline)
            TextField("Label, e.g. API dev", text: $annotation.label)
            TextEditor(text: $annotation.note)
                .font(.system(size: 12))
                .frame(width: 260, height: 82)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
            HStack {
                Spacer()
                Button("Save") {
                    preferences.setAnnotation(annotation, for: port.port)
                }
            }
        }
        .padding(14)
    }
}

private extension View {
    func sectionLabelStyle() -> some View {
        font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)
    }
}
