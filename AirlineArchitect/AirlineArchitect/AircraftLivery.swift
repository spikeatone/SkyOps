//
//  AircraftLivery.swift
//  Airline Architect — PROTOTYPE (Phase 1 surprise-&-delight): the player's airline
//  name rendered on the fuselage of the side-view illustration, in their two chosen
//  colours. Lives on the `livery-prototype` branch; not shipped yet.
//
//  The illustrations are 1024-wide PNGs, nose-left, white livery. `AircraftLiveryImage`
//  overlays the name at a per-type placement on the fuselage. Two styles to compare:
//  .text (name in primary with a secondary outline — "colours on the text") and
//  .band (name on a filled primary plate with a secondary cheatline — the forgiving
//  treatment that reads as intentional even when placement isn't pixel-perfect).
//

import SwiftUI
import CoreGraphics

struct LiveryColors: Equatable {
    var primary: Color
    var secondary: Color
}

enum LiveryStyle { case text, band }

/// Fractional placement of the name on the fuselage, in the fitted-image rect's
/// coordinate space (0…1). `cx`/`cy` = centre, `w` = width fraction.
struct LiveryPlacement {
    var cx: CGFloat, cy: CGFloat, w: CGFloat
    var rotation: Double = 0   // degrees, for a slight cheatline rake if wanted

    /// Per-type table (prototype covers the A320 family + the Dash-8 turboprop;
    /// everything else gets a heuristic default). The real feature would fill this
    /// in for all ~35 types.
    static func forType(_ id: String) -> LiveryPlacement {
        switch id {
        // A320 family: clean mid-upper fuselage, wing/engines are low.
        case "A319", "A320", "A321", "A319NEO", "A320NEO", "A321NEO":
            return .init(cx: 0.40, cy: 0.52, w: 0.34)
        // Dash-8 turboprop: prop disc sits mid-fuselage → name AFT of it, and higher
        // on the upper fuselage so it clears the wing/nacelle shading.
        case "DH8B":
            return .init(cx: 0.61, cy: 0.49, w: 0.28)
        default:
            return .init(cx: 0.42, cy: 0.52, w: 0.34)   // heuristic
        }
    }
}

struct AircraftLiveryImage: View {
    let typeID: String
    let name: String
    let colors: LiveryColors
    let style: LiveryStyle

    var body: some View {
        let ui = AircraftArt.uiImage(for: typeID)
        let aspect = ui.map { $0.size.width / max(1, $0.size.height) } ?? (1024.0 / 306.0)
        // A box of the image's aspect ratio → the image (scaledToFit) fills it with
        // NO letterbox, so the overlay's geometry maps 1:1 to the illustration.
        Color.clear
            .aspectRatio(aspect, contentMode: .fit)
            .overlay { if let ui { Image(uiImage: ui).resizable().scaledToFit() } }
            .overlay {
                GeometryReader { geo in
                    let place = LiveryPlacement.forType(typeID)
                    let bandW = geo.size.width * place.w
                    let fontSize = geo.size.height * (style == .band ? 0.14 : 0.17)
                    overlay(fontSize: fontSize, bandW: bandW)
                        .rotationEffect(.degrees(place.rotation))
                        .position(x: geo.size.width * place.cx, y: geo.size.height * place.cy)
                }
            }
    }

    @ViewBuilder private func overlay(fontSize: CGFloat, bandW: CGFloat) -> some View {
        let font = Font.karla(fontSize, .heavy)
        switch style {
        case .text:
            OutlinedText(text: name.uppercased(), font: font,
                         fill: colors.primary, outline: colors.secondary,
                         thickness: max(0.5, fontSize * 0.06))
                .frame(width: bandW)
        case .band:
            VStack(spacing: fontSize * 0.12) {
                Text(name.uppercased())
                    .font(font).foregroundStyle(.white)
                    .lineLimit(1).minimumScaleFactor(0.5)
                Rectangle().fill(colors.secondary)
                    .frame(height: max(1, fontSize * 0.18))
            }
            .padding(.horizontal, fontSize * 0.5)
            .padding(.vertical, fontSize * 0.28)
            .frame(maxWidth: bandW)
            .background(RoundedRectangle(cornerRadius: fontSize * 0.35).fill(colors.primary))
        }
    }
}

/// Two-colour text: `fill` glyph with an `outline` keyline (8-way offset layering —
/// cheap, and reads fine at card sizes).
struct OutlinedText: View {
    let text: String, font: Font, fill: Color, outline: Color, thickness: CGFloat
    var body: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { i in
                let a = Double(i) / 8 * 2 * .pi
                Text(text).font(font).lineLimit(1).minimumScaleFactor(0.5)
                    .foregroundStyle(outline)
                    .offset(x: cos(a) * thickness, y: sin(a) * thickness)
            }
            Text(text).font(font).lineLimit(1).minimumScaleFactor(0.5)
                .foregroundStyle(fill)
        }
    }
}

// MARK: - Prototype preview (branch-only; reached via -liveryPreview)

struct LiveryPrototypeView: View {
    let name = "Aster Air"
    // A complementary pair that pops on the white fuselage: deep navy + warm gold.
    let colors = LiveryColors(primary: Color(red: 0.09, green: 0.20, blue: 0.42),
                              secondary: Color(red: 0.89, green: 0.66, blue: 0.24))

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Text("Livery prototype — “\(name)”")
                    .font(.system(size: 17, weight: .bold))
                    .padding(.top, 8)
                ForEach(["A320", "DH8B"], id: \.self) { id in
                    VStack(spacing: 10) {
                        Text(id).font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
                        labeled("Text style (2 colours on the name)") {
                            AircraftLiveryImage(typeID: id, name: name, colors: colors, style: .text)
                        }
                        labeled("Band style (name plate + cheatline)") {
                            AircraftLiveryImage(typeID: id, name: name, colors: colors, style: .band)
                        }
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(white: 0.97)))
                }
            }
            .padding(16)
        }
        .background(Color(white: 0.92))
    }

    private func labeled<V: View>(_ label: String, @ViewBuilder _ content: () -> V) -> some View {
        VStack(spacing: 4) {
            Text(label).font(.system(size: 10)).foregroundStyle(.secondary)
            content().frame(height: 116)
        }
    }
}
