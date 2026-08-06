//
//  PaywallView.swift
//  Airline Architect — the custom Pro upgrade sheet
//
//  Custom SwiftUI (not RevenueCatUI) so it matches the app's Karla/Sky design.
//  Presented as an overlay from any in-context cap hit (Open Route / Acquire at
//  the free limit) and from the Finance "Plan" card. Purchase/restore call the
//  Store STUBS today; wiring RevenueCat later doesn't touch this view beyond the
//  two calls it already makes (store.purchase / store.restore).
//

import SwiftUI
#if canImport(RevenueCatUI)
import RevenueCatUI
#endif

/// "Manage subscription" — presents RevenueCat's Customer Center (cancel,
/// refund requests, plan changes) when the package is available; otherwise
/// deep-links to the system subscription-management screen. Shown on the
/// Finance Pro card for active subscribers.
struct ManageSubscriptionButton: View {
    var tint: Color
    @State private var show = false

    var body: some View {
        #if canImport(RevenueCatUI)
        Button { show = true } label: { label }
            .buttonStyle(.plain)
            .presentCustomerCenter(isPresented: $show)
        #else
        Link(destination: URL(string: "https://apps.apple.com/account/subscriptions")!) { label }
        #endif
    }

    private var label: some View {
        Text("Manage subscription").font(.karla(13, .semibold)).foregroundStyle(tint)
    }
}

struct PaywallView: View {
    let store: Store
    /// Optional context line explaining what the player just hit (fleet/route).
    var reason: String? = nil
    var onClose: () -> Void = {}

    @Environment(\.colorScheme) private var scheme
    private var isDark: Bool { scheme == .dark }
    @State private var selected: String = "annual"

    private func hex(_ h: UInt) -> Color {
        Color(red: Double((h >> 16) & 0xFF) / 255, green: Double((h >> 8) & 0xFF) / 255, blue: Double(h & 0xFF) / 255)
    }
    private var cardBG: Color   { isDark ? Sky.navBarDark : .white }
    private var panelBG: Color  { isDark ? Sky.darkBG : hex(0xF1F1F1) }
    private var border: Color   { isDark ? Sky.onDarkStroke.opacity(0.6) : hex(0xE2E8F0) }
    private var primary: Color  { isDark ? .white : hex(0x1E293B) }
    private var secondary: Color { isDark ? Sky.lightBlue.opacity(0.8) : hex(0x64748B) }
    private var badgeGradient: [Color] { isDark ? [hex(0x4E67A1), hex(0x0C1A42)] : [hex(0x40588F), hex(0x101937)] }

    // Sells the SYSTEMS past the cap, not "more of the same". A free player has
    // now built one hub, so the pitch is the next rung: more hubs, the markets,
    // and the endgame they can see coming but can't reach.
    private let features = [
        ("building.2.fill", "Hubs & clubs", "Turn more airports into hubs and open lounges that keep flyers loyal."),
        ("point.3.connected.trianglepath.dotted", "Unlimited routes & fleet", "Grow from a handful of legs to a global network, widebodies and all."),
        ("chart.line.uptrend.xyaxis", "Take it all the way", "Go public, ride the markets, and buy out your rivals."),
    ]

    // Functional legal links required on the subscription screen by App Store
    // Guideline 3.1.2. Terms of Use is Apple's standard EULA (also linked in the
    // App Store description); Privacy Policy is the published support-site page.
    static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    static let privacyURL = URL(string: "https://spikeatone.github.io/airline-architect/privacy.html")!

    var body: some View {
        VStack(spacing: 0) {
            // Header badge + title
            VStack(spacing: 12) {
                ZStack {
                    Circle().fill(LinearGradient(colors: badgeGradient, startPoint: .top, endPoint: .bottom))
                    AppLogo().frame(width: 58, height: 47)
                }
                .frame(width: 84, height: 84)
                Text("Airline Architect Pro")
                    .font(.karla(24, .bold)).foregroundStyle(primary)
                Text(reason ?? "You've built the start of something. Go Pro to grow it into a real airline.")
                    .font(.karla(14)).foregroundStyle(secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)
            }
            .padding(.top, 24)
            .padding(.horizontal, 20)

            // Feature list
            VStack(spacing: 14) {
                ForEach(features, id: \.1) { icon, title, sub in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Sky.coreGreen)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(title).font(.karla(15, .bold)).foregroundStyle(primary)
                            Text(sub).font(.karla(12)).foregroundStyle(secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(20)

            // Plan selector
            VStack(spacing: 10) {
                ForEach(store.plans) { plan in planRow(plan) }
            }
            .padding(.horizontal, 20)

            // CTA + restore + fine print
            VStack(spacing: 12) {
                Button {
                    Task { await store.purchase(planID: selected); if store.isPro { onClose() } }
                } label: {
                    ZStack {
                        Text("Continue").font(.karla(17, .bold)).foregroundStyle(.white)
                            .opacity(store.purchasing ? 0 : 1)
                        if store.purchasing { ProgressView().tint(.white) }
                    }
                    .frame(maxWidth: .infinity).frame(height: 52)
                    .background(Sky.coreGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }.buttonStyle(.plain).disabled(store.purchasing)

                Button {
                    Task { await store.restore(); if store.isPro { onClose() } }
                } label: {
                    Text("Restore Purchases").font(.karla(13, .semibold)).foregroundStyle(secondary)
                }.buttonStyle(.plain).disabled(store.purchasing)

                if let err = store.purchaseError {
                    Text(err).font(.karla(11)).foregroundStyle(isDark ? Color(skyHex: 0xFF9292) : Color(skyHex: 0xD70000))
                        .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                }

                // A restore that found nothing isn't an error — neutral colour.
                if let notice = store.restoreNotice {
                    Text(notice).font(.karla(11)).foregroundStyle(secondary)
                        .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                }

                Text("Subscriptions auto-renew until cancelled. Manage or cancel anytime in Settings. Payment is charged to your Apple Account.")
                    .font(.karla(10)).foregroundStyle(secondary.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                // Terms of Use (EULA) + Privacy Policy — required in the binary
                // for auto-renewable subscriptions (App Store Guideline 3.1.2).
                HStack(spacing: 6) {
                    Link("Terms of Use", destination: Self.termsURL)
                    Text("·").foregroundStyle(secondary.opacity(0.6))
                    Link("Privacy Policy", destination: Self.privacyURL)
                }
                .font(.karla(11, .semibold))
                .foregroundStyle(secondary)
            }
            .padding(20)
        }
        .background(cardBG)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(border, lineWidth: 1))
        .overlay(alignment: .topTrailing) {
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(secondary.opacity(0.7), panelBG)
            }
            .buttonStyle(.plain).padding(12)
        }
    }

    private func planRow(_ plan: Store.Plan) -> some View {
        let on = selected == plan.id
        return Button { selected = plan.id } label: {
            HStack(spacing: 12) {
                Image(systemName: on ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 20)).foregroundStyle(on ? Sky.coreGreen : secondary)
                VStack(alignment: .leading, spacing: 3) {
                    Text(plan.title).font(.karla(16, .bold)).foregroundStyle(primary)
                        .lineLimit(1)
                    // Cadence + discount pill share the second line, so neither
                    // competes with the title for width (no wrap on any device).
                    HStack(spacing: 6) {
                        Text(plan.cadence).font(.karla(12)).foregroundStyle(secondary)
                        if let note = plan.note {
                            Text(note).font(.karla(10, .bold)).foregroundStyle(.white)
                                .lineLimit(1).fixedSize()          // never wrap the pill
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Sky.coreGreen).clipShape(Capsule())
                        }
                    }
                }
                Spacer()
                Text(plan.price).font(.karla(18, .heavy)).foregroundStyle(primary)
            }
            .padding(14)
            .background(panelBG)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4)
                .stroke(on ? Sky.coreGreen : border, lineWidth: on ? 2 : 1))
        }.buttonStyle(.plain)
    }
}
