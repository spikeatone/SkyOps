//
//  SkyTabIcons.swift
//  Airline Architect — custom bottom-nav tab icons, extracted from the Figma tab bar
//  (SkyOps-Production 2:2001). Stroked line-art (viewBox 24, stroke 1.5, round
//  caps), rendered via SVGPath into a Canvas so they tint per selection state
//  (active = Light Yellow, inactive = Light Blue). Same native-SVG approach as
//  AppLogo / AircraftIcon — no bundled raster, scales crisply.
//

import SwiftUI

enum SkyTabIcon {

    static let network: [String] = [
        "M7.12782 16.8722L10.3759 13.6241M13.6241 10.3759L16.8722 7.12782M7.12782 19.5789C7.12782 21.0739 5.91596 22.2857 4.42105 22.2857C2.92615 22.2857 1.71429 21.0739 1.71429 19.5789C1.71429 18.084 2.92615 16.8722 4.42105 16.8722C5.91596 16.8722 7.12782 18.084 7.12782 19.5789ZM22.2857 4.42105C22.2857 5.91596 21.0739 7.12782 19.5789 7.12782C18.084 7.12782 16.8722 5.91596 16.8722 4.42105C16.8722 2.92615 18.084 1.71429 19.5789 1.71429C21.0739 1.71429 22.2857 2.92615 22.2857 4.42105ZM13.6241 12C13.6241 12.8969 12.8969 13.6241 12 13.6241C11.1031 13.6241 10.3759 12.8969 10.3759 12C10.3759 11.1031 11.1031 10.3759 12 10.3759C12.8969 10.3759 13.6241 11.1031 13.6241 12Z",
    ]
    static let plane: [String] = [
        "M16.2955 11.0034L18.2749 20.0206C18.3849 20.5704 18.1649 21.0103 17.7251 21.3402L17.1753 21.5601C16.6254 21.7801 16.0756 21.6701 15.7457 21.2302L11.8969 15.4021L8.59794 17.6014V20.9003L7.49828 22L5.29897 18.701L2 16.5017L3.09966 15.4021H6.39863L8.59794 12.1031L2.76976 8.2543C2.3299 7.9244 2.21993 7.37457 2.43986 6.82474L2.76976 6.27491C2.98969 5.83505 3.42955 5.61512 3.97938 5.72509L12.9966 7.70447L16.8454 3.85567C18.4948 2.20619 20.6942 1.65636 21.7938 2.20619C22.3436 3.30584 21.7938 5.50515 20.1443 7.15464L16.2955 11.0034Z",
    ]
    static let crew: [String] = [
        "M1.71429 22.2857V19.8655C1.71429 18.5818 2.19592 17.3507 3.05323 16.4429C3.91054 15.5352 5.0733 15.0252 6.28571 15.0252H10.8571C12.0696 15.0252 13.2323 15.5352 14.0896 16.4429C14.9469 17.3507 15.4286 18.5818 15.4286 19.8655V22.2857M22.2857 22.2857V20.4706C22.2857 19.5078 21.9245 18.5844 21.2815 17.9036C20.6385 17.2228 19.7665 16.8403 18.8571 16.8403H17.7143M12 5.34454C12 7.34947 10.465 8.97479 8.57143 8.97479C6.67788 8.97479 5.14286 7.34947 5.14286 5.34454C5.14286 3.33961 6.67788 1.71429 8.57143 1.71429C10.465 1.71429 12 3.33961 12 5.34454ZM20.5714 7.76471C20.5714 9.43548 19.2922 10.7899 17.7143 10.7899C16.1363 10.7899 14.8571 9.43548 14.8571 7.76471C14.8571 6.09393 16.1363 4.7395 17.7143 4.7395C19.2922 4.7395 20.5714 6.09393 20.5714 7.76471Z",
    ]
    static let ops: [String] = [
        "M7.93461 12.5414H16.7509M7.93461 16.8722H13.8122M7.93461 8.21053H16.7509M4.99583 3.8797H19.6897C21.3128 3.8797 22.6285 4.84919 22.6285 6.04511V20.1203C22.6285 21.3162 21.3128 22.2857 19.6897 22.2857H4.99583C3.37279 22.2857 2.05706 21.3162 2.05706 20.1203V6.04511C2.05706 4.84919 3.37279 3.8797 4.99583 3.8797ZM7.93461 1.71429H16.7509V4.96241C16.7509 5.24956 16.5961 5.52495 16.3206 5.728C16.045 5.93104 15.6713 6.04511 15.2815 6.04511H9.404C9.01429 6.04511 8.64055 5.93104 8.36498 5.728C8.08942 5.52495 7.93461 5.24956 7.93461 4.96241V1.71429Z",
    ]
    static let finance: [String] = [
        "M4.97147 12H2.68576C2.05457 12 1.5429 12.5117 1.5429 13.1429V21.1429C1.5429 21.774 2.05457 22.2857 2.68576 22.2857H4.97147C5.60265 22.2857 6.11433 21.774 6.11433 21.1429V13.1429C6.11433 12.5117 5.60265 12 4.97147 12Z",
        "M12.9715 6.28571H10.6858C10.0546 6.28571 9.5429 6.79739 9.5429 7.42857V21.1429C9.5429 21.774 10.0546 22.2857 10.6858 22.2857H12.9715C13.6027 22.2857 14.1143 21.774 14.1143 21.1429V7.42857C14.1143 6.79739 13.6027 6.28571 12.9715 6.28571Z",
        "M20.9715 1.71429H18.6858C18.0546 1.71429 17.5429 2.22596 17.5429 2.85714V21.1429C17.5429 21.774 18.0546 22.2857 18.6858 22.2857H20.9715C21.6027 22.2857 22.1143 21.774 22.1143 21.1429V2.85714C22.1143 2.22596 21.6027 1.71429 20.9715 1.71429Z",
    ]
}

/// Renders a stroked 24×24 tab icon, tinted by the given colour.
struct SkyTabIconView: View {
    let paths: [String]
    let color: Color
    var body: some View {
        Canvas { ctx, size in
            let scale = size.width / 24
            let t = CGAffineTransform(scaleX: scale, y: scale)
            for d in paths {
                let p = SVGPath.parse(d).applying(t)
                ctx.stroke(p, with: .color(color),
                           style: StrokeStyle(lineWidth: 1.5 * scale, lineCap: .round, lineJoin: .round))
            }
        }
    }
}

/// The custom bottom nav, matching the Figma tab bar (2:2001 dark / 2:1602
/// light). Active tint is theme-dependent — Light Yellow on dark, Bright Blue
/// on light; inactive is Light Blue on dark, slate on light. Karla SemiBold 12
/// labels, #1F232D / white background with a soft top shadow.
struct SkyTabBar: View {
    @Binding var selection: Int
    /// Count of new Ops activity — shows an orange badge on the Ops tab so
    /// players notice things happening there. 0 = no badge.
    var opsBadge: Int = 0
    @Environment(\.colorScheme) private var scheme
    private var isDark: Bool { scheme == .dark }
    /// Figma "Orange" (#FF8C00).
    private let badgeColor = Color(skyHex: 0xFF8C00)

    private static let items: [(title: String, paths: [String])] = [
        ("Network", SkyTabIcon.network), ("Fleet", SkyTabIcon.plane),
        ("Crews", SkyTabIcon.crew), ("Ops", SkyTabIcon.ops), ("Finance", SkyTabIcon.finance),
    ]
    private var bg: Color { isDark ? Sky.navBarDark : .white }
    private var active: Color { isDark ? Sky.lightYellow : Sky.brightBlue }
    private var inactive: Color { isDark ? Sky.lightBlue : Color(skyHex: 0x64748B) }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(Self.items.enumerated()), id: \.offset) { i, item in
                let c = (i == selection) ? active : inactive
                Button { selection = i } label: {
                    VStack(spacing: 4) {
                        SkyTabIconView(paths: item.paths, color: c).frame(width: 24, height: 24)
                            .overlay(alignment: .topTrailing) {
                                if i == 3, opsBadge > 0 {
                                    Text(opsBadge > 9 ? "9+" : "\(opsBadge)")
                                        .font(.karla(9, .bold)).foregroundStyle(.white)
                                        .padding(.horizontal, opsBadge > 9 ? 3 : 0)
                                        .frame(minWidth: 15, minHeight: 15)
                                        .background(badgeColor)
                                        .clipShape(Capsule())
                                        .overlay(Capsule().stroke(bg, lineWidth: 1.5))
                                        .offset(x: 9, y: -6)
                                }
                            }
                        Text(item.title).font(.karla(12, .semibold)).foregroundStyle(c)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .background(bg.shadow(color: .black.opacity(0.10), radius: 4, y: -2).ignoresSafeArea(edges: .bottom))
    }
}
