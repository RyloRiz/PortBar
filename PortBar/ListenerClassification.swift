//
//  ListenerClassification.swift
//  PortBar
//

import Foundation

enum ListenerClassification {
    /// Background listeners that are useful to macOS but almost never relevant
    /// when a developer is looking for a local service or port conflict.
    private static let backgroundProcessNames: Set<String> = [
        "rapportd", "controlcenter", "cfprefsd", "corespotlightd", "sharingd",
        "apsd", "locationd", "wifianalyticsd", "bluetoothd", "neagent",
        "identityservicesd", "devicecheckind", "triald", "cloudphotod", "cloudd",
        "sysmond", "nsurlsessiond", "mdnsresponder", "distnoted", "launchd"
    ]

    static func isBackgroundService(named processName: String) -> Bool {
        backgroundProcessNames.contains(processName.lowercased())
    }
}
