//
//  SkySidebar.swift
//  Airline Architect — the iPad navigation rail.
//
//  The regular-width (iPad) counterpart to SkyTabBar: a persistent left rail
//  instead of a bottom tab bar, using the SAME 5 SkyTabIcon glyphs, the same
//  theme-aware active/inactive tints, and the same Ops badge. Uses the extra
//  iPad width and frees the bottom edge for content. iPhone keeps SkyTabBar.
//

import SwiftUI

struct SkySidebarRail: View {
    @Binding var selection: Int
    /// Count of new Ops activity — orange badge on the Ops row (same as the tab bar).
    var opsBadge: Int = 0
    /// The player's airline name, shown under the logo (nil before naming).
    var airlineName: String?
    @Environment(\.colorScheme) private var scheme
    private var isDark: Bool { scheme == .dark }

    static let width: CGFloat = 232

    private static let items: [(title: String, paths: [String])] = [
        ("Network", SkyTabIcon.network), ("Fleet", SkyTabIcon.plane),
        ("Crews", SkyTabIcon.crew), ("Ops", SkyTabIcon.ops), ("Finance", SkyTabIcon.finance),
    ]

    private var bg: Color { isDark ? Sky.navBarDark : .white }
    private var active: Color { isDark ? Sky.lightYellow : Sky.brightBlue }
    private var inactive: Color { isDark ? Sky.lightBlue : Color(skyHex: 0x64748B) }
    private var activeFill: Color { (isDark ? Sky.lightYellow : Sky.brightBlue).opacity(isDark ? 0.14 : 0.10) }
    private var divider: Color { isDark ? Sky.onDarkStroke.opacity(0.5) : Color(skyHex: 0xE6E6E6) }
    private let badgeColor = Color(skyHex: 0xFF8C00)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().overlay(divider).padding(.horizontal, 16)
            VStack(spacing: 4) {
                ForEach(Array(Self.items.enumerated()), id: \.offset) { i, item in
                    row(i, item)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            Spacer(minLength: 0)
        }
        .frame(width: Self.width)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(
            bg.shadow(color: .black.opacity(0.10), radius: 5, x: 2, y: 0)
                .ignoresSafeArea()
        )
        .overlay(alignment: .trailing) {
            Rectangle().fill(divider).frame(width: 1).ignoresSafeArea()
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            AppLogo().frame(width: 78, height: 62)
            VStack(spacing: 1) {
                Text("Airline").font(.karla(17, .semibold))
                Text("Architect").font(.karla(17, .semibold))
            }
            .foregroundStyle(isDark ? .white : Color(skyHex: 0x1F232D))
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 20)
        .padding(.bottom, 18)
    }

    private func row(_ i: Int, _ item: (title: String, paths: [String])) -> some View {
        let selected = i == selection
        let c = selected ? active : inactive
        return Button { selection = i } label: {
            HStack(spacing: 12) {
                SkyTabIconView(paths: item.paths, color: c).frame(width: 22, height: 22)
                    .overlay(alignment: .topTrailing) {
                        if i == 3, opsBadge > 0 {
                            Text(opsBadge > 9 ? "9+" : "\(opsBadge)")
                                .font(.karla(9, .bold)).foregroundStyle(.white)
                                .padding(.horizontal, opsBadge > 9 ? 3 : 0)
                                .frame(minWidth: 15, minHeight: 15)
                                .background(badgeColor)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(bg, lineWidth: 1.5))
                                .offset(x: 8, y: -6)
                        }
                    }
                Text(item.title).font(.karla(15, selected ? .bold : .medium)).foregroundStyle(c)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selected ? activeFill : .clear)
            )
        }
        .buttonStyle(.plain)
    }
}
