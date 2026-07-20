//
//  PortNotificationManager.swift
//  PortBar
//

import Combine
import Foundation
import UserNotifications

@MainActor
final class PortNotificationManager: NSObject, ObservableObject {
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func notify(for event: PortEvent, filters: [QuickFilter]) {
        let matchedGroups = filters.filter { $0.isEnabled && $0.notificationsEnabled && $0.matches(event.port) }
        guard !matchedGroups.isEmpty else { return }

        let content = UNMutableNotificationContent()
        let groupNames = matchedGroups.map(\.label).joined(separator: ", ")
        content.title = event.kind == .started ? "\(groupNames) started" : "\(groupNames) stopped"
        content.body = ":\(event.port.port) · \(event.port.processName) · PID \(event.port.pid)"
        content.sound = .default

        let request = UNNotificationRequest(identifier: event.id.uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
