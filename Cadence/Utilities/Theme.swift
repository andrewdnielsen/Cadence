//
//  Theme.swift
//  Cadence
//
//  Created by Andrew Nielsen on 11/26/25.
//

import SwiftUI

/// Design system theme with colors, spacing, and constants for consistent UI
struct Theme {

    // MARK: - Colors

    struct Colors {
        /// Blue accent color (#315BD8)
        static let primary = Color("CadencePrimary")

        /// Dark gray background (#212121)
        static let background = Color("BackgroundColor")

        /// Lighter card/surface background
        static let surface = Color("SurfaceColor")

        /// White for all text
        static let textPrimary = Color("TextPrimaryColor")

        /// Slightly dimmed white for secondary text
        static let textSecondary = Color("TextSecondaryColor")
    }

    // MARK: - Spacing

    struct Spacing {
        /// Extra small spacing (4pt)
        static let xs: CGFloat = 4

        /// Small spacing (8pt)
        static let sm: CGFloat = 8

        /// Medium spacing (16pt)
        static let md: CGFloat = 16

        /// Large spacing (24pt)
        static let lg: CGFloat = 24

        /// Extra large spacing (32pt)
        static let xl: CGFloat = 32

        /// Extra extra large spacing (48pt)
        static let xxl: CGFloat = 48
    }

    // MARK: - Typography

    struct Typography {
        /// Huge display text for BPM (72pt)
        static let displayHuge: CGFloat = 72

        /// Large display text (48pt)
        static let displayLarge: CGFloat = 48

        /// Medium display text (36pt)
        static let displayMedium: CGFloat = 36

        /// Title text (24pt)
        static let title: CGFloat = 24

        /// Subtitle text (20pt)
        static let subtitle: CGFloat = 20

        /// Body text (16pt)
        static let body: CGFloat = 16

        /// Caption text (14pt)
        static let caption: CGFloat = 14

        /// Small text (12pt)
        static let small: CGFloat = 12
    }

    // MARK: - Corner Radius

    struct CornerRadius {
        /// Small corner radius (8pt)
        static let sm: CGFloat = 8

        /// Medium corner radius (12pt)
        static let md: CGFloat = 12

        /// Large corner radius (16pt)
        static let lg: CGFloat = 16

        /// Extra large corner radius (24pt)
        static let xl: CGFloat = 24

        /// Circular (999pt)
        static let circle: CGFloat = 999
    }

    // MARK: - Animation

    struct Animation {
        /// Quick animation duration (0.2s)
        static let quick: Double = 0.2

        /// Standard animation duration (0.3s)
        static let standard: Double = 0.3

        /// Slow animation duration (0.5s)
        static let slow: Double = 0.5

        /// Spring animation with bounce
        static let spring = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0)

        /// Smooth spring animation
        static let smoothSpring = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.8, blendDuration: 0)

        /// Bouncy spring animation (Duolingo-style)
        static let bouncySpring = SwiftUI.Animation.spring(response: 0.5, dampingFraction: 0.6, blendDuration: 0)
    }

    // MARK: - Shadows

    struct Shadow {
        /// Small shadow for subtle elevation
        static let small = (radius: CGFloat(4), x: CGFloat(0), y: CGFloat(2))

        /// Medium shadow for cards
        static let medium = (radius: CGFloat(8), x: CGFloat(0), y: CGFloat(4))

        /// Large shadow for prominent elements
        static let large = (radius: CGFloat(16), x: CGFloat(0), y: CGFloat(8))
    }

    // MARK: - Sizes

    struct Sizes {
        /// Standard button height (56pt)
        static let buttonHeight: CGFloat = 56

        /// Large button height (64pt)
        static let buttonHeightLarge: CGFloat = 64

        /// Small button height (44pt)
        static let buttonHeightSmall: CGFloat = 44

        /// Icon size small (20pt)
        static let iconSmall: CGFloat = 20

        /// Icon size medium (24pt)
        static let iconMedium: CGFloat = 24

        /// Icon size large (32pt)
        static let iconLarge: CGFloat = 32

        /// Pulsing ring stroke width (8pt)
        static let ringStrokeWidth: CGFloat = 8
    }
}
