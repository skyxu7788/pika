//
//  Colors.swift
//  Pika
//
//  Created by S J on 5/29/26.
//

import Foundation
import SwiftUI

extension Color {
    init(hex: String, opacity: Double = 1.0) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)

        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let red: Double
        let green: Double
        let blue: Double
        let alpha: Double

        switch hex.count {
        case 8:
            red = Double((int >> 24) & 0xFF) / 255.0
            green = Double((int >> 16) & 0xFF) / 255.0
            blue = Double((int >> 8) & 0xFF) / 255.0
            alpha = Double(int & 0xFF) / 255.0
        default:
            red = Double((int >> 16) & 0xFF) / 255.0
            green = Double((int >> 8) & 0xFF) / 255.0
            blue = Double(int & 0xFF) / 255.0
            alpha = 1.0
        }

        self.init(red: red, green: green, blue: blue, opacity: alpha * opacity)
    }
}

enum PikaColors {
  static let contentDarkTertiary = Color(hex: "#737373")
  static let surfacelight = Color(hex: "#FCFAF7", opacity: 0.9)
  static let unrecordedPrompt = Color(hex: "#C2B3F5")

  static let profileCardBackground = [
      Color(hex: "#F0E8FF"),
      PikaColors.surfacelight,
      Color(hex: "#FFF5E0")
  ]
  static let textfieldTextColor = Color(hex: "#8D8D8F")
  static let textfieldColor = Color(hex: "#D9D9D9")
  static let surfaceDark = Color(hex: "#0D0D0D0D")
  static let accentDark = Color(hex: "#806ECA")
  static let accentPrimary = Color(hex: "#CFC3FF")
  static let accentQuatenry = Color(hex: "#CFC3FF33")
}
