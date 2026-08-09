//
//  ArchitectBackdrop.swift
//  Airline Architect — the cold-launch background artwork.
//
//  A faint aerial runway scene (a queue of airliners taxiing to line up for
//  takeoff) sitting full-bleed behind the splash / naming / load-menu screens.
//  Designer art from Figma (Airline-Architect-Production, node 122:488x).
//
//  FOUR pre-rendered assets — one per (idiom × theme):
//    • iPhone dark  — atmospheric charcoal photo   (LaunchBackdropDark)
//    • iPhone light — graphite sketch on off-white (LaunchBackdropLight)
//    • iPad dark  / iPad light — the same scene recomposed for the iPad's 4:3.
//
//  This SUPERSEDES the old single grayscale-on-white source + per-theme BLEND
//  MODE (.multiply light / .colorInvert+.screen dark). The designer now supplies
//  a genuine dark render and a light render, so we display the RIGHT asset
//  directly at 0.25 opacity — no blend adaptation, no tint. Same full-bleed
//  geometry as before (phone .fill, iPad .fit + slight inset for landscape).
//

import SwiftUI
import UIKit

// MARK: - The art

/// Loads the bundled backdrops once. Files under `Resources/` are FLATTENED into
/// the bundle root by the file-system-synchronized group, so this resolves by
/// bare filename — same as the fonts, Basemap.json and `AircraftArt`.
enum ArchitectArt {
    private static func load(_ name: String) -> Image? {
        guard let path = Bundle.main.path(forResource: name, ofType: "png"),
              let ui = UIImage(contentsOfFile: path) else { return nil }
        return Image(uiImage: ui)
    }
    // Phone art — TALL compositions framed for a phone's narrow aspect.
    static let phoneDark:  Image? = load("LaunchBackdropDark")
    static let phoneLight: Image? = load("LaunchBackdropLight")
    // iPad art — the designer's separate 4:3 renders (1086×1448, matching the
    // iPad's 0.75 portrait aspect) with the full scene in frame.
    static let padDark:  Image? = load("LaunchBackdropPadDark")
    static let padLight: Image? = load("LaunchBackdropPadLight")

    /// The right asset for the idiom + theme (nil if that file is missing).
    static func art(regular: Bool, dark: Bool) -> Image? {
        switch (regular, dark) {
        case (true,  true):  return padDark
        case (true,  false): return padLight
        case (false, true):  return phoneDark
        case (false, false): return phoneLight
        }
    }
}

// MARK: - The backdrop

/// The faint aerial runway art, full-bleed behind a cold-launch screen. Drop it
/// in as the first layer of a `ZStack`, over the screen's background colour. It
/// never takes touches and is hidden from VoiceOver — it's texture, not content.
///
/// The theme picks the ASSET now (dark render vs light render), not a blend mode.
/// The splash is always navy regardless of the system theme, so it passes
/// `forcedScheme: .dark`; the theme-aware naming / load-menu screens leave it nil.
struct ArchitectBackdrop: View {
    /// Dark-theme opacity (splash + dark naming/load-menu). Device-tuned so the
    /// art stays behind the UI, not competing.
    static let darkOpacity: Double = 0.25
    /// Light-theme opacity. HIGHER than dark on purpose: the light art is a
    /// graphite sketch on off-white, which reads fainter at a given opacity than
    /// the dark photo-on-navy does — so it needs more to land with equal presence.
    static let lightOpacity: Double = 0.42

    /// Final opacity applied to the art. Callers pass the per-theme value (or one
    /// of the constants above); nil-gated on/off at the call site.
    var opacity: Double = 0.25
    /// Force a colour scheme (the splash is always navy → `.dark`). nil = use the
    /// environment scheme (theme-aware naming / load-menu).
    var forcedScheme: ColorScheme? = nil

    @Environment(\.colorScheme) private var envScheme
    @Environment(\.horizontalSizeClass) private var hSize
    private var isDark: Bool { (forcedScheme ?? envScheme) == .dark }

    var body: some View {
        GeometryReader { geo in
            // ALWAYS full-bleed (.fill). These are opaque full-frame photos, so
            // any margin (an inset, or a .fit letterbox in landscape) exposes the
            // image's rectangular EDGE against the page background — a visible
            // seam the designer flagged. .fill guarantees the art covers every
            // pixel, so there is no edge to see. iPad PORTRAIT (4:3 art on 4:3
            // canvas) is an exact fit with no crop; iPad LANDSCAPE center-crops
            // the diagonal runway scene, which keeps the focal runway + queue.
            // Each idiom still uses art composed for its own aspect.
            let regular = hSize == .regular
            if let art = ArchitectArt.art(regular: regular, dark: isDark) {
                art
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .opacity(opacity)
            }
        }
        .allowsHitTesting(false)         // pure texture; never eats a tap
        .accessibilityHidden(true)
        .ignoresSafeArea()
    }
}
