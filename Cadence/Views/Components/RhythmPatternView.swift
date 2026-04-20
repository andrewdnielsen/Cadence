//
//  RhythmPatternView.swift
//  Cadence
//
//  Draws a subdivision type as a beamed rhythmic group — no assets or fonts required.
//  Each pattern is rendered via SwiftUI Canvas: filled noteheads, stems, beams, and
//  tuplet brackets composed to match standard music notation groupings.
//

import SwiftUI

// MARK: - Public view

/// Renders a subdivision type as a beamed rhythmic notation group.
/// Constrain the height at the call site; width is determined by aspect ratio.
///
///     RhythmPatternView(subdivision: .sixteenth)
///         .frame(height: 32)
struct RhythmPatternView: View {
    let subdivision: Subdivision
    var color: Color = Theme.Colors.textPrimary

    var body: some View {
        let spec = PatternSpec.from(subdivision)
        Canvas { context, size in
            Renderer(spec: spec, color: color).draw(&context, size: size)
        }
        .aspectRatio(spec.aspectRatio, contentMode: .fit)
    }
}

// MARK: - Pattern specification

/// Describes what to draw for a given subdivision — decoupled from the model.
private struct PatternSpec {
    /// Number of noteheads in the group.
    let noteCount: Int
    /// Connecting beams per stem: 0 = unbeamed quarter, 1 = eighth, 2 = sixteenth, 3 = 32nd.
    let beamCount: Int
    /// True for half-note open (hollow) noteheads.
    let hollow: Bool
    /// Tuplet bracket label (3, 5, 6, 7) or nil for simple subdivisions.
    let tuplet: Int?

    /// Width-to-height ratio for the canvas. Each additional notehead widens the canvas.
    var aspectRatio: CGFloat {
        let headFrac: CGFloat  = 0.258   // headW ≈ 0.258 × H
        let spacing: CGFloat   = headFrac * 1.12
        let totalW             = CGFloat(noteCount - 1) * spacing + headFrac * 2.15
        return max(0.56, totalW)
    }

    static func from(_ sub: Subdivision) -> PatternSpec {
        switch sub {
        // Simple subdivisions — beamed groups matching how they appear in sheet music
        case .quarter:          return .init(noteCount: 1, beamCount: 0, hollow: false, tuplet: nil)
        case .eighth:           return .init(noteCount: 2, beamCount: 1, hollow: false, tuplet: nil)
        case .sixteenth:        return .init(noteCount: 4, beamCount: 2, hollow: false, tuplet: nil)
        case .thirtySecond:     return .init(noteCount: 2, beamCount: 3, hollow: false, tuplet: nil)

        // Triplets
        case .eighthTriplet:    return .init(noteCount: 3, beamCount: 1, hollow: false, tuplet: 3)
        case .sixteenthTriplet: return .init(noteCount: 3, beamCount: 2, hollow: false, tuplet: 3)
        case .quarterTriplet:   return .init(noteCount: 3, beamCount: 0, hollow: false, tuplet: 3)
        case .halfTriplet:      return .init(noteCount: 3, beamCount: 0, hollow: true,  tuplet: 3)

        // Higher tuplets — show representative 3-note group with bracket number
        case .quintuplet:       return .init(noteCount: 5, beamCount: 1, hollow: false, tuplet: 5)
        case .sextuplet:        return .init(noteCount: 3, beamCount: 1, hollow: false, tuplet: 6)
        case .septuplet:        return .init(noteCount: 3, beamCount: 1, hollow: false, tuplet: 7)
        }
    }
}

// MARK: - Canvas renderer

private struct Renderer {
    let spec: PatternSpec
    let color: Color

    func draw(_ ctx: inout GraphicsContext, size: CGSize) {
        let W = size.width
        let H = size.height
        let n = spec.noteCount
        let hasTuplet = spec.tuplet != nil

        // ── Vertical zones ───────────────────────────────────────────────────
        // Tuplet bracket sits above stems; reserve extra headroom when needed.
        let tupletZone: CGFloat  = hasTuplet ? H * 0.25 : H * 0.04
        let headH: CGFloat       = H * 0.16
        let headW: CGFloat       = headH * 1.58
        let headCY: CGFloat      = H - headH * 0.85      // notehead centre (near bottom)
        let stemTopY: CGFloat    = tupletZone             // stem top (touches beam)
        let stemBotY: CGFloat    = headCY - headH * 0.28 // stem bottom (meets notehead)
        let stemW: CGFloat       = H * 0.038

        // ── Beam geometry ────────────────────────────────────────────────────
        let beamH: CGFloat       = H * 0.074
        let beamGap: CGFloat     = beamH + H * 0.040

        // ── Horizontal positions ─────────────────────────────────────────────
        let hPad: CGFloat  = headW * 0.52
        let noteXs         = positions(n: n, W: W, hPad: hPad)
        let stemDX: CGFloat = headW * 0.37   // stem attaches right of notehead centre

        // ── 1. Stems ────────────────────────────────────────────────────��────
        for x in noteXs {
            ctx.fill(
                Path(CGRect(x: x + stemDX - stemW * 0.5,
                            y: stemTopY,
                            width: stemW,
                            height: stemBotY - stemTopY)),
                with: .color(color)
            )
        }

        // ── 2. Beams ─────────────────────────────────────────────────────────
        if spec.beamCount > 0 && n > 1 {
            let bLeft  = noteXs.first! + stemDX
            let bRight = noteXs.last!  + stemDX
            for b in 0..<spec.beamCount {
                ctx.fill(
                    Path(CGRect(x: bLeft,
                                y: stemTopY + CGFloat(b) * beamGap,
                                width: bRight - bLeft,
                                height: beamH)),
                    with: .color(color)
                )
            }
        }

        // ── 3. Noteheads ─────────────────────────────────────────────────────
        // Tilted ~12° to match the angle of real music noteheads.
        for x in noteXs {
            let path = tiltedEllipse(cx: x, cy: headCY, w: headW, h: headH, angle: -0.22)
            if spec.hollow {
                ctx.stroke(path, with: .color(color), lineWidth: stemW * 0.88)
            } else {
                ctx.fill(path, with: .color(color))
            }
        }

        // ── 4. Tuplet bracket + number ───────────────────────────────────────
        if let num = spec.tuplet {
            let lx     = noteXs.first! + stemDX
            let rx     = noteXs.last!  + stemDX
            let midX   = (lx + rx) * 0.5
            let bY     = stemTopY - H * 0.04    // bracket horizontal rail
            let tickH  = H * 0.072
            let inset  = (rx - lx) * 0.26       // how far rail extends before gap
            let lw     = stemW * 0.70

            // Left arm: rail at top, tick hangs down
            var lPath = Path()
            lPath.move(to:    .init(x: lx,          y: bY))
            lPath.addLine(to: .init(x: lx,          y: bY - tickH))
            lPath.addLine(to: .init(x: lx + inset,  y: bY - tickH))
            ctx.stroke(lPath, with: .color(color), lineWidth: lw)

            // Right arm: rail at top, tick hangs down
            var rPath = Path()
            rPath.move(to:    .init(x: rx,          y: bY))
            rPath.addLine(to: .init(x: rx,          y: bY - tickH))
            rPath.addLine(to: .init(x: rx - inset,  y: bY - tickH))
            ctx.stroke(rPath, with: .color(color), lineWidth: lw)

            // Number centred in the gap at rail level
            let numText = Text("\(num)")
                .font(.system(size: H * 0.22, weight: .medium, design: .rounded))
                .foregroundColor(color)
            let resolved = ctx.resolve(numText)
            ctx.draw(resolved, at: .init(x: midX, y: bY - tickH), anchor: .center)
        }
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    private func positions(n: Int, W: CGFloat, hPad: CGFloat) -> [CGFloat] {
        guard n > 1 else { return [W * 0.42] }
        return (0..<n).map { i in
            hPad + (W - hPad * 2) * CGFloat(i) / CGFloat(n - 1)
        }
    }

    private func tiltedEllipse(cx: CGFloat, cy: CGFloat, w: CGFloat, h: CGFloat, angle: CGFloat) -> Path {
        let rect = CGRect(x: cx - w * 0.5, y: cy - h * 0.5, width: w, height: h)
        let tf   = CGAffineTransform(translationX: cx, y: cy)
            .rotated(by: angle)
            .translatedBy(x: -cx, y: -cy)
        return Path(ellipseIn: rect).applying(tf)
    }
}

// MARK: - Preview

#Preview("All subdivisions — dark") {
    ScrollView {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            ForEach(Subdivision.allCases) { sub in
                HStack(spacing: Theme.Spacing.md) {
                    RhythmPatternView(subdivision: sub)
                        .frame(height: 32)
                    Text(sub.fullName)
                        .font(Theme.Typography.sansRegular(Theme.Typography.body))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Spacer()
                }
                .padding(.vertical, Theme.Spacing.xs)
            }
        }
        .padding()
    }
    .background(Theme.Colors.background)
    .preferredColorScheme(.dark)
}

#Preview("All subdivisions — light") {
    ScrollView {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            ForEach(Subdivision.allCases) { sub in
                HStack(spacing: Theme.Spacing.md) {
                    RhythmPatternView(subdivision: sub)
                        .frame(height: 32)
                    Text(sub.fullName)
                        .font(Theme.Typography.sansRegular(Theme.Typography.body))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Spacer()
                }
                .padding(.vertical, Theme.Spacing.xs)
            }
        }
        .padding()
    }
    .background(Theme.Colors.background)
    .preferredColorScheme(.light)
}
