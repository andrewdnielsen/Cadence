//
//  Theme.swift
//  Cadence
//
//  Created by Andrew Nielsen on 11/26/25.
//

import SwiftUI
import UIKit

// MARK: - Color helpers

fileprivate extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

extension Color {
    /// Creates a color that adapts between light and dark mode using hex strings.
    init(lightHex: String, darkHex: String) {
        self = Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(Color(hex: darkHex))
                : UIColor(Color(hex: lightHex))
        })
    }
}

// MARK: - Theme

/// Design system for Cadence. All UI constants live here.
struct Theme {

    // MARK: - Colors

    struct Colors {

        // Backgrounds
        /// App background
        static let background    = Color(lightHex: "F5F0E8", darkHex: "111009")
        /// Cards, panels
        static let surface       = Color(lightHex: "EDE8E0", darkHex: "1C1A17")
        /// Elevated elements, modals
        static let surfaceRaised = Color(lightHex: "E5DFD6", darkHex: "262320")

        // Text
        /// Primary labels, BPM display
        static let textPrimary   = Color(lightHex: "1A1612", darkHex: "F2EDE4")
        /// Sub-labels, captions
        static let textSecondary = Color(lightHex: "6B6560", darkHex: "8C8680")
        /// Inactive / disabled text
        static let textTertiary  = Color(lightHex: "9A9590", darkHex: "5C5752")

        // Accent — Blued Steel
        /// Idle controls, inactive beat indicators, borders
        static let accentResting   = Color(lightHex: "4A6070", darkHex: "475E6E")
        /// Playing state — active controls, beat pulse, BPM highlight
        static let accentActive    = Color(lightHex: "3D6E87", darkHex: "6B8FA8")
        /// Pressed states, focus rings
        static let accentHighlight = Color(lightHex: "2E5A72", darkHex: "82AABF")

        // Beat accents
        /// Downbeat (beat 1) — warm cream on dark, deep amber on light
        static let downbeat = Color(lightHex: "9E6A1A", darkHex: "E8D9BE")

        // Semantic
        static let success = Color(lightHex: "3D7A57", darkHex: "5A9A72")
        static let warning = Color(lightHex: "B87020", darkHex: "C4882A")
        static let error   = Color(lightHex: "9E3F30", darkHex: "B85548")

        // Tuner string visualizer arc (dark mode hero moment)
        static let stringSilent     = Color(hex: "5C5248") // dim warm gray — silent / far off pitch
        static let stringApproaching = Color(hex: "C4882A") // amber builds as pitch approaches
        static let stringNear       = Color(hex: "E8A830") // bright amber-gold — near pitch
        static let stringInTune     = Color(hex: "F5E4B0") // near-white warm glow — in tune
    }

    // MARK: - Typography

    struct Typography {
        // IBM Plex Mono — all numeric displays
        static func monoDisplay(_ size: CGFloat) -> Font {
            Font.custom("IBMPlexMono-Bold", size: size)
        }
        static func monoLabel(_ size: CGFloat) -> Font {
            Font.custom("IBMPlexMono-Regular", size: size)
        }

        // IBM Plex Sans — all UI labels and controls
        static func sansMedium(_ size: CGFloat) -> Font {
            Font.custom("IBMPlexSans-Medium", size: size)
        }
        static func sansRegular(_ size: CGFloat) -> Font {
            Font.custom("IBMPlexSans-Regular", size: size)
        }

        // Size scale
        static let displayHuge: CGFloat   = 72  // BPM number
        static let displayLarge: CGFloat  = 48
        static let displayMedium: CGFloat = 36
        static let title: CGFloat         = 24
        static let subtitle: CGFloat      = 20
        static let body: CGFloat          = 16
        static let caption: CGFloat       = 14
        static let small: CGFloat         = 12
    }

    // MARK: - Spacing

    struct Spacing {
        static let xs: CGFloat  = 4
        static let sm: CGFloat  = 8
        static let md: CGFloat  = 16
        static let lg: CGFloat  = 24
        static let xl: CGFloat  = 32
        static let xxl: CGFloat = 48
    }

    // MARK: - Corner Radius

    struct CornerRadius {
        static let sm: CGFloat     = 8
        static let md: CGFloat     = 12
        static let lg: CGFloat     = 16
        static let xl: CGFloat     = 24
        static let circle: CGFloat = 999
    }

    // MARK: - Animation

    struct Animation {
        static let quick: Double    = 0.2
        static let standard: Double = 0.3
        static let slow: Double     = 0.5

        static let spring       = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0)
        static let smoothSpring = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.8, blendDuration: 0)
        static let bouncySpring = SwiftUI.Animation.spring(response: 0.5, dampingFraction: 0.6, blendDuration: 0)
    }

    // MARK: - Shadows

    struct Shadow {
        static let small  = (radius: CGFloat(4),  x: CGFloat(0), y: CGFloat(2))
        static let medium = (radius: CGFloat(8),  x: CGFloat(0), y: CGFloat(4))
        static let large  = (radius: CGFloat(16), x: CGFloat(0), y: CGFloat(8))
    }

    // MARK: - Sizes

    struct Sizes {
        static let buttonHeight: CGFloat      = 56
        static let buttonHeightLarge: CGFloat = 64
        static let buttonHeightSmall: CGFloat = 44
        static let iconSmall: CGFloat         = 20
        static let iconMedium: CGFloat        = 24
        static let iconLarge: CGFloat         = 32
        static let ringStrokeWidth: CGFloat   = 8
    }
}
