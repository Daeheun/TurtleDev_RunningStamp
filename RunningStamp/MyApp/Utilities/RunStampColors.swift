import SwiftUI

enum RunStampColors {
    static let appBackground = Color(hex: "0A0F1E")
    static let surface = Color(hex: "151A2D")
    static let elevatedSurface = Color(hex: "1B2138")
    static let cardStroke = Color(hex: "2A3150")
    static let primaryText = Color(hex: "F5F7FB")
    static let secondaryText = Color(hex: "A5AEC4")
    static let tertiaryText = Color(hex: "6F7890")
    static let divider = Color(hex: "2A3150")

    static let energyOrange = Color(hex: "FF6A2A")
    static let vibrantPurple = Color(hex: "A05CFF")
    static let electricBlue = Color(hex: "5678FF")
    static let aquaTeal = Color(hex: "2CD5C4")
    static let limeGreen = Color(hex: "B7F230")
    static let redlineRed = Color(hex: "FF3B4E")
    static let warmYellow = Color(hex: "FFB84D")

    static func effortColor(_ title: String) -> Color {
        switch title {
        case "RECOVERY FLOW":
            return aquaTeal
        case "CONTROLLED BASE":
            return limeGreen
        case "STEADY BUILDER":
            return electricBlue
        case "TEMPO ENGINE":
            return energyOrange
        case "REDLINE PUSH":
            return redlineRed
        case "PROGRESSIVE BURN":
            return warmYellow
        default:
            return secondaryText
        }
    }

    static func effortSecondaryColor(_ title: String) -> Color {
        switch title {
        case "RECOVERY FLOW", "CONTROLLED BASE":
            return aquaTeal
        case "TEMPO ENGINE":
            return vibrantPurple
        case "REDLINE PUSH", "PROGRESSIVE BURN":
            return energyOrange
        case "STEADY BUILDER":
            return aquaTeal
        default:
            return tertiaryText
        }
    }
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let red: UInt64
        let green: UInt64
        let blue: UInt64
        let alpha: UInt64

        switch cleaned.count {
        case 3:
            red = ((value >> 8) & 0xF) * 17
            green = ((value >> 4) & 0xF) * 17
            blue = (value & 0xF) * 17
            alpha = 255
        case 6:
            red = (value >> 16) & 0xFF
            green = (value >> 8) & 0xFF
            blue = value & 0xFF
            alpha = 255
        case 8:
            red = (value >> 24) & 0xFF
            green = (value >> 16) & 0xFF
            blue = (value >> 8) & 0xFF
            alpha = value & 0xFF
        default:
            red = 255
            green = 255
            blue = 255
            alpha = 255
        }

        self.init(
            .sRGB,
            red: Double(red) / 255,
            green: Double(green) / 255,
            blue: Double(blue) / 255,
            opacity: Double(alpha) / 255
        )
    }
}
