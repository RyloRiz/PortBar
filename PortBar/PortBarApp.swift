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
    @StateObject private var history: HistoryStore

    init() {
        let preferences = PreferencesStore()
        let notifications = PortNotificationManager()
        let history = HistoryStore()
        let monitor = PortMonitor(pollingInterval: preferences.pollingInterval)
        monitor.eventHandler = { event in
            notifications.notify(for: event, filters: preferences.quickFilters)
            history.record(event, filters: preferences.quickFilters)
        }
        _preferences = StateObject(wrappedValue: preferences)
        _monitor = StateObject(wrappedValue: monitor)
        _notifications = StateObject(wrappedValue: notifications)
        _history = StateObject(wrappedValue: history)
    }

    var body: some Scene {
        MenuBarExtra {
            PortBarMenuView(monitor: monitor, preferences: preferences)
                .tint(preferences.accentColor)
                .environment(\.portBarAccent, preferences.accentColor)
        } label: {
            portBarLogo
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(monitor: monitor, preferences: preferences, notifications: notifications, history: history)
                .tint(preferences.accentColor)
                .environment(\.portBarAccent, preferences.accentColor)
        }
    }

    private var portBarLogo: some View {
        Image("PortBarMenuLogo")
            .renderingMode(.template)
            .accessibilityLabel("PortBar")
    }
}
