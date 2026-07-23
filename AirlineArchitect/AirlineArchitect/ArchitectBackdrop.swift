//
//  ArchitectBackdrop.swift
//  Airline Architect — the shared "architect's tools" brand motif.
//
//  A very faint drafting-tools still life (T-square, mechanical pencil,
//  compass) sitting behind a dark screen. This is intended as a COMMON VISUAL
//  THEME ACROSS THE ARCHITECT SERIES (Airline Architect, Golf Course Architect,
//  …), so it's deliberately self-contained: one PNG + this file, no dependency
//  on any app-specific token or model. To reuse it elsewhere, copy
//  `Resources/Brand/ArchitectTools.png` + this file and nothing else.
//
//  Built to the designer's Figma (Airline-Architect-Production, node 90:4819
//  "home - dark"). The geometry there is a 603.274 × 811.579 image rotated 30°
//  at 10% opacity, whose rotated bounding box (928.24 × 1004.485 — verified:
//  w·cos30 + h·sin30 = 928.23, w·sin30 + h·cos30 = 1004.47) sits at (-302, 32)
//  in a 440-wide frame. That puts the artwork's CENTRE at (162.1, 534.2).
//
//  Those numbers are expressed here as FRACTIONS of the container rather than
//  fixed points, so the composition holds on any device (the Figma frame is
//  440 wide; an iPhone 17 Pro is 402, an iPad far wider) instead of drifting
//  off-screen. Scale is keyed to WIDTH so the tools keep their proportion to
//  the screen furniture.
//
//  The art is white line-art on transparency, so it's tinted + faded at draw
//  time rather than baked — which is what lets a sibling app re-use the same
//  PNG over a different brand colour.
//

import SwiftUI
import UIKit

// MARK: - The art

/// Loads the bundled motif once. Files under `Resources/` are FLATTENED into
/// the bundle root by the file-system-synchronized group, so this resolves by
/// bare filename — the same mechanism as the fonts, Basemap.json and
/// `AircraftArt`.
enum ArchitectArt {
    static let toolsImage: Image? = {
        guard let path = Bundle.main.path(forResource: "ArchitectTools", ofType: "png"),
              let ui = UIImage(contentsOfFile: path) else { return nil }
        return Image(uiImage: ui)
    }()
}

// MARK: - The backdrop

/// The faint drafting-tools motif, sized and placed per the Figma composition.
///
/// Drop it in as the first layer of a `ZStack`, over the screen's background
/// colour. It never takes touches and is hidden from VoiceOver — it's texture,
/// not content.
///
/// Every cold-launch surface (splash / naming / load menu) draws its OWN
/// instance at these same defaults rather than sharing one layer. Because the
/// geometry is purely a function of the container size, all three land
/// pixel-identically — so the tools never shift as one screen hands off to the
/// next, and no screen has to give up its own opaque background.
struct ArchitectBackdrop: View {
    /// The opacity the designer specified in Figma 90:4819 (the DARK frame).
    /// Single source of truth for the shipping surfaces — tune here, not at
    /// each call site.
    static let figmaOpacity: Double = 0.10

    /// Light-theme opacity. Deliberately LOWER than the dark value: the same
    /// alpha does not read the same on the two backgrounds — dark ink on white
    /// carries further than white line-art on #2B303D, so matching 0.10 makes
    /// the light treatment shout while the dark one whispers.
    ///
    /// Tuned by eye on device over the real naming screen (the only honest way
    /// to set it): 0.06 vanished, 0.12 started competing with the form fields,
    /// 0.08 sits behind the content the way the dark 0.10 does.
    static let lightOpacity: Double = 0.08

    /// How present the motif is. The Figma calls for 0.10; kept as a parameter
    /// because this is the one value most likely to be tuned per app/screen.
    var opacity: Double = 0.10
    /// Rotation in degrees (Figma: 30).
    var angle: Double = 30
    /// Artwork width as a multiple of the container's width.
    /// Figma: 603.274 / 440 ≈ 1.371 — i.e. the art is wider than the screen,
    /// which is what makes it read as a crop of a larger drawing.
    var widthScale: CGFloat = 603.274 / 440
    /// Centre of the artwork, as a fraction of the container.
    /// Figma: (162.1 / 440, 534.2 / 924).
    var centre: UnitPoint = UnitPoint(x: 162.1 / 440, y: 534.2 / 924)
    /// Tint for the line art. White matches the Figma; a sibling app can pass
    /// its own brand colour without re-exporting the PNG.
    var tint: Color = .white

    /// Source aspect ratio (892 × 1200 original, and the Figma box 603.274 ×
    /// 811.579 — both 0.7433, so the art is never distorted).
    private static let aspect: CGFloat = 603.274 / 811.579

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width * widthScale
            let h = w / Self.aspect
            if let art = ArchitectArt.toolsImage {
                art
                    .resizable()
                    .renderingMode(.template)          // tint the line art
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(tint)
                    .frame(width: w, height: h)
                    .rotationEffect(.degrees(angle))
                    .position(x: geo.size.width * centre.x,
                              y: geo.size.height * centre.y)
                    .opacity(opacity)
            }
        }
        .clipped()                       // the Figma "Mask group" — crop to frame
        .allowsHitTesting(false)         // pure texture; never eats a tap
        .accessibilityHidden(true)
        .ignoresSafeArea()
    }
}

/// Convenience: the motif over a solid background, the pairing every screen
/// that uses it wants. `ArchitectBackdrop` alone is transparent.
struct ArchitectBackdropLayer: View {
    var background: Color = Sky.darkBG   // Figma "Dark Mode BG" #2B303D
    var opacity: Double = 0.10
    var tint: Color = .white

    var body: some View {
        ZStack {
            background.ignoresSafeArea()
            ArchitectBackdrop(opacity: opacity, tint: tint)
        }
    }
}
