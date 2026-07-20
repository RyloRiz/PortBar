//
//  PortBarApp.swift
//  PortBar
//
//  Created by Rizwaan Bana on 7/19/26.
//

import SwiftUI

@main
struct PortBarApp: App {
    @StateObject private var monitor: PortMonitor
    @StateObject private var preferences: PreferencesStore
    @StateObject private var notifications: PortNotificationManager

    init() {
        let preferences = PreferencesStore()
        let notifications = PortNotificationManager()
        let monitor = PortMonitor(pollingInterval: preferences.pollingInterval)
        monitor.eventHandler = { event in
            notifications.notify(for: event, filters: preferences.quickFilters)
        }
        _preferences = StateObject(wrappedValue: preferences)
        _monitor = StateObject(wrappedValue: monitor)
        _notifications = StateObject(wrappedValue: notifications)
    }

    var body: some Scene {
        MenuBarExtra {
            PortBarMenuView(monitor: monitor, preferences: preferences)
        } label: {
            if preferences.showsPortCount {
                Label("\(visiblePortCount)", systemImage: "point.3.connected.trianglepath.dotted")
            } else {
                Image(systemName: "point.3.connected.trianglepath.dotted")
            }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(monitor: monitor, preferences: preferences, notifications: notifications)
        }
    }

    private var visiblePortCount: Int {
        monitor.ports.filter { port in
            let isPinned = preferences.pinnedPorts.contains(port.port)
            let isVisible = preferences.showsAllListeners || !port.isBackgroundService || isPinned
            let matchesService = preferences.quickFilters
                .filter(\.isEnabled)
                .contains { filter in filter.matches(port) }
            return isVisible && (preferences.showsAllListeners || isPinned || matchesService)
        }.count
    }
}
