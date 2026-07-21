//
//  PopupSettingsView.swift
//  PortBar
//

import SwiftUI
import UniformTypeIdentifiers

struct PopupSettingsView: View {
    @ObservedObject var preferences: PreferencesStore
    @Environment(\.portBarAccent) private var appAccent
    @State private var draggedServiceID: QuickFilter.ID?
    @State private var dropTargetServiceID: QuickFilter.ID?

    private var pinnedServices: [QuickFilter] {
        preferences.pinnedPopupServices
    }

    private var availableServices: [QuickFilter] {
        preferences.quickFilters.filter { $0.isEnabled && !preferences.isServicePinned($0) }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Popup shortcuts")
                    .font(.system(size: 24, weight: .semibold))
                Text("Choose the enabled services shown at the top of the PortBar popup.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                HStack(spacing: 6) {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundStyle(appAccent)
                    Text("\(pinnedServices.count) of \(preferences.popupServiceLimit) pinned")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 32)
            .padding(.top, 30)
            .padding(.bottom, 25)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    sectionHeader("PINNED IN POPUP", detail: "Drag onto a service to place the shortcut before it.")

                    if pinnedServices.isEmpty {
                        ContentUnavailableView(
                            "No popup shortcuts",
                            systemImage: "pin.slash",
                            description: Text("Pin an enabled service below to add it to the popup."))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 30)
                    } else {
                        ForEach(pinnedServices) { service in
                            PopupServiceRow(
                                service: service,
                                order: pinnedOrder(for: service),
                                isDropTarget: dropTargetServiceID == service.id
                            ) {
                                preferences.unpinService(service)
                            }
                            .onDrag {
                                draggedServiceID = service.id
                                return NSItemProvider(object: service.id.uuidString as NSString)
                            }
                            .onDrop(of: [UTType.text], delegate: PinnedServiceDropDelegate(
                                targetID: service.id,
                                draggedServiceID: $draggedServiceID,
                                dropTargetServiceID: $dropTargetServiceID,
                                move: preferences.movePinnedService
                            ))

                            if service.id != pinnedServices.last?.id {
                                Divider().padding(.leading, 42)
                            }
                        }
                    }

                    Divider().padding(.vertical, 24)

                    sectionHeader("ENABLED SERVICES", detail: preferences.canPinMoreServices
                        ? "Pin a service to add it to the popup."
                        : "Unpin a shortcut above before adding another service.")

                    if availableServices.isEmpty {
                        Text("Every enabled service is pinned.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(availableServices) { service in
                            PopupServiceRow(service: service, order: nil, isDropTarget: false) {
                                preferences.pinService(service)
                            }
                            .disabled(!preferences.canPinMoreServices)

                            if service.id != availableServices.last?.id {
                                Divider().padding(.leading, 42)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
        }
    }

    private func pinnedOrder(for service: QuickFilter) -> Int? {
        pinnedServices.firstIndex(of: service).map { $0 + 1 }
    }

    private func sectionHeader(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 12)
    }
}

private struct PopupServiceRow: View {
    @Environment(\.portBarAccent) private var appAccent
    let service: QuickFilter
    let order: Int?
    let isDropTarget: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: service.symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(FilterTint.color(for: service.tint))
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(service.label)
                    .font(.system(size: 14, weight: .medium))
                Text(service.ports.isEmpty ? "Process-based match" : service.ports)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            if let order {
                Text("\(order)")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .frame(width: 16)
                Image(systemName: "line.3.horizontal")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Button(action: action) {
                    Image(systemName: "pin.slash")
                }
                .buttonStyle(.borderless)
                .help("Remove from popup")
            } else {
                Button(action: action) {
                    Label("Pin", systemImage: "pin")
                }
                .buttonStyle(.borderless)
                .help("Add to popup")
            }
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 8)
        .background(isDropTarget ? appAccent.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .contentShape(Rectangle())
    }
}

private struct PinnedServiceDropDelegate: DropDelegate {
    let targetID: QuickFilter.ID
    @Binding var draggedServiceID: QuickFilter.ID?
    @Binding var dropTargetServiceID: QuickFilter.ID?
    let move: (QuickFilter.ID, QuickFilter.ID) -> Void

    func dropEntered(info: DropInfo) {
        guard let draggedServiceID, draggedServiceID != targetID else { return }
        dropTargetServiceID = targetID
    }

    func dropExited(info: DropInfo) {
        guard dropTargetServiceID == targetID else { return }
        dropTargetServiceID = nil
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        if let draggedServiceID, draggedServiceID != targetID {
            move(draggedServiceID, targetID)
        }
        draggedServiceID = nil
        dropTargetServiceID = nil
        return true
    }
}
