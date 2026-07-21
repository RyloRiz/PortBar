//
//  FilterTint.swift
//  PortBar
//

import SwiftUI

private struct PortBarAccentKey: EnvironmentKey {
    static let defaultValue = Color.accentColor
}

extension EnvironmentValues {
    var portBarAccent: Color {
        get { self[PortBarAccentKey.self] }
        set { self[PortBarAccentKey.self] = newValue }
    }
}

enum FilterTint {
    static let options = ["blue", "green", "orange", "purple", "pink", "red", "indigo", "yellow", "gray"]

    static func color(for tint: String) -> Color {
        if tint.hasPrefix("#"), tint.count == 7,
           let value = UInt64(tint.dropFirst(), radix: 16) {
            let red = Double((value >> 16) & 0xFF) / 255
            let green = Double((value >> 8) & 0xFF) / 255
            let blue = Double(value & 0xFF) / 255
            return Color(.sRGB, red: red, green: green, blue: blue, opacity: 1)
        }
        return switch tint {
        case "green": Color.green
        case "orange": Color.orange
        case "purple": Color.purple
        case "pink": Color.pink
        case "red": Color.red
        case "indigo": Color.indigo
        case "yellow": Color.yellow
        case "gray": Color.gray
        default: Color.blue
        }
    }
}
