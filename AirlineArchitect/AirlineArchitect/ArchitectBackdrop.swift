//
//  ArchitectBackdrop.swift
//  Airline Architect — the cold-launch background artwork.
//
//  A faint aviation pencil-sketch (airliner, control tower, pilot's cap) sitting
//  full-bleed behind the splash / naming / load-menu screens. Designer art from
//  Figma (Airline-Architect-Production, "home - light" 1:2 / "home - dark" 1:456).
//
//  The source (LaunchBackdrop.png) is a grayscale pencil drawing on a WHITE
//  ground, so it adapts to each theme with a BLEND MODE rather than a tint —
//  which PRESERVES the pencil shading (a flat template-tint would fill the shapes
//  solid and lose the drawing):
//    • Light: .multiply drops the white ground, leaving a faint gray sketch.
//    • Dark:  .colorInvert() (→ light lines on black) + .screen drops the black,
//             leaving a faint light sketch on the navy.
//
//  This REPLACED the old "architect's drafting tools" template motif (white
//  line-art, tinted + rotated). AA has diverged from that shared-series motif —
//  the launch art here is aviation-specific now, and full-bleed rather than a
//  rotated centred emblem, so the old rotation/scale/tint geometry is gone.
//

import SwiftUI
import UIKit

// MARK: - The art

/// Loads the bundled backdrop once. Files under `Resources/` are FLATTENED into
/// the bundle root by the file-system-synchronized group, so this resolves by
/// bare filename — same as the fonts, Basemap.json and `AircraftArt`.
enum ArchitectArt {
    private static func load(_ name: String) -> Image? {
        guard let path = Bundle.main.path(forResource: name, ofType: "png"),
              let ui = UIImage(contentsOfFile: path) else { return nil }
        return Image(uiImage: ui)
    }
    /// Phone art — a TALL composition framed for a phone's narrow aspect.
    static let backdropImage: Image? = load("LaunchBackdrop")
    /// iPad art — the designer's separate 4:3 render (1086×1448, matching the
    /// iPad's 0.75 portrait aspect) with the airliner's full wingspan in frame.
    /// The phone art cropped its wings on a wide canvas, which is why this
    /// exists rather than scaling the phone asset.
    static let backdropImagePad: Image? = load("LaunchBackdropPad")
}

// MARK: - The backdrop

/// The faint aviation sketch, full-bleed behind a cold-launch screen. Drop it in
/// as the first layer of a `ZStack`, over the screen's background colour. It
/// never takes touches and is hidden from VoiceOver — it's texture, not content.
///
/// The per-theme treatment lives HERE (blend mode by colour scheme). The splash
/// is always navy regardless of the system theme, so it passes `forcedScheme:
/// .dark`; the theme-aware naming / load-menu screens leave it nil.
struct ArchitectBackdrop: View {
    /// Dark-theme opacity (splash + dark naming/load-menu). Device-tuned against
    /// the Figma so the sketch stays behind the UI, not competing.
    static let darkOpacity: Double = 0.25
    /// Light-theme opacity (multiply on white). Same 0.25 as dark — the designer
    /// picked this as the sweet spot for both themes.
    static let lightOpacity: Double = 0.25

    /// Final opacity applied to the blended art. Callers pass the per-theme value
    /// (or one of the constants above); nil-gated on/off at the call site.
    var opacity: Double = 0.55
    /// Force a colour scheme (the splash is always navy → `.dark`). nil = use the
    /// environment scheme (theme-aware naming / load-menu).
    var forcedScheme: ColorScheme? = nil

    /// Scale for the contained iPad art. Device-tuned (0.85 → 0.98, +15% at the
    /// designer's call). Note the pad art is 4:3 like the iPad's PORTRAIT canvas,
    /// so at ~1.0 portrait is effectively full-bleed while LANDSCAPE stays
    /// comfortably contained — one constant serves both orientations.
    static let regularScale: CGFloat = 0.98

    @Environment(\.colorScheme) private var envScheme
    @Environment(\.horizontalSizeClass) private var hSize
    private var isDark: Bool { (forcedScheme ?? envScheme) == .dark }

    var body: some View {
        GeometryReader { geo in
            // Each idiom gets art composed for its own aspect.
            // Phone: .fill (full-bleed crop) — the art is framed for that shape.
            // iPad: .fit + a slight inset. The pad art is 4:3, so in PORTRAIT fit
            // and fill are identical (the canvas is also ~4:3) — but in LANDSCAPE
            // a .fill would scale the drawing up to cover the width, blowing up
            // the airliner and cropping the tower/cap off. Containing it keeps the
            // whole sketch centered and smaller on every orientation.
            let regular = hSize == .regular
            if let art = regular ? ArchitectArt.backdropImagePad : ArchitectArt.backdropImage {
                art
                    .resizable()
                    .aspectRatio(contentMode: regular ? .fit : .fill)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .scaleEffect(regular ? Self.regularScale : 1)
                    .frame(width: geo.size.width, height: geo.size.height)   // re-constrain
                    .clipped()
                    .modifier(BackdropBlend(isDark: isDark))
                    .opacity(opacity)
            }
        }
        .allowsHitTesting(false)         // pure texture; never eats a tap
        .accessibilityHidden(true)
        .ignoresSafeArea()
    }
}

/// Adapt the dark-on-white pencil sketch to the theme. Light = multiply (the
/// white ground drops out, the gray sketch remains). Dark = invert then screen
/// (the inverted black ground drops out, the light sketch remains on the navy).
private struct BackdropBlend: ViewModifier {
    let isDark: Bool
    func body(content: Content) -> some View {
        if isDark {
            content.colorInvert().blendMode(.screen)
        } else {
            content.blendMode(.multiply)
        }
    }
}
