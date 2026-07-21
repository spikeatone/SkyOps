//
//  HubsPanel.swift
//  Airline Architect — the NETWORK "Hubs" control-bar panel.
//
//  Appears once the player establishes their first hub (the control bar shows a
//  5th "Hubs" button only when `sim.hubs` is non-empty). Lists each hub with the
//  flights (routes) originating there. A SINGLE hub renders expanded; MULTIPLE
//  hubs are collapsible drawers grouped by hub, so a big network doesn't become
//  one long scroll. Styling mirrors RoutesPanel.
//

import SwiftUI

struct HubsPanel: View {
    let sim: Simulation
    /// Which multi-hub drawers are open (a single hub is always shown expanded).
    @State private var expanded: Set<String> = []
    /// Measured content height so the panel hugs its content, scrolling only past a cap.
    @State private var contentHeight: CGFloat = 0

    @Environment(\.colorScheme) private var scheme
    private var isDark: Bool { scheme == .dark }
    private var cardBG: Color      { isDark ? Sky.navBarDark.opacity(0.92) : Color.white.opacity(0.96) }
    private var innerCardBG: Color { isDark ? Sky.navBarDark : .white }
    private var cardBorder: Color  { isDark ? Sky.onDarkStroke : Color(skyHex: 0xC9C9C9) }
    private var labelColor: Color  { isDark ? Sky.lightBlue : Color(skyHex: 0x64748B) }
    private var primaryC: Color    { isDark ? .white : .black }
    private var green: Color       { isDark ? Color(skyHex: 0x87ED7A) : Color(skyHex: 0x10B981) }
    private let amber = Color(skyHex: 0xFFAB44)
    private let gold  = Color(skyHex: 0xE9B949)

    var body: some View {
        let _ = sim.displayTick   // throttled heartbeat — keeps route counts/status live
        let hubs = sim.hubCodes
        Group {
            if hubs.isEmpty {
                Text("No hubs yet. Establish a hub at an airport with 5+ routes.")
                    .font(.karla(14)).foregroundStyle(labelColor)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24).padding(.horizontal, 8)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(hubs, id: \.self) { hubDrawer($0, single: hubs.count == 1) }
                    }
                    .padding(8)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
                }
                .frame(height: min(max(contentHeight, 1), 376))
            }
        }
        .frame(maxWidth: .infinity)
        .background(cardBG)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(cardBorder, lineWidth: 1))
        .shadow(color: isDark ? .clear : .black.opacity(0.12), radius: 3, y: 1)
    }

    private func isOpen(_ code: String, single: Bool) -> Bool { single || expanded.contains(code) }

    @ViewBuilder private func hubDrawer(_ code: String, single: Bool) -> some View {
        let open = isOpen(code, single: single)
        let routes = sim.hubRoutes(code)
        let operating = sim.hubOperating(code)
        let city = sim.airport(code)?.info?.city ?? code
        VStack(alignment: .leading, spacing: 8) {
            // Hub header — tap to expand/collapse (a lone hub isn't collapsible).
            Button {
                guard !single else { return }
                if expanded.contains(code) { expanded.remove(code) } else { expanded.insert(code) }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "building.2.fill").font(.system(size: 13)).foregroundStyle(gold)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(code).font(.karla(17, .heavy)).foregroundStyle(primaryC)
                        Text(city).font(.karla(11)).foregroundStyle(labelColor).lineLimit(1)
                    }
                    Spacer(minLength: 6)
                    Text(operating ? "OPERATING" : "UNDERSTAFFED")
                        .font(.karla(10, .bold)).foregroundStyle(operating ? green : amber)
                    Text("· \(routes.count) flt\(routes.count == 1 ? "" : "s")")
                        .font(.karla(11)).foregroundStyle(labelColor)
                    if !single {
                        Image(systemName: open ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11, weight: .semibold)).foregroundStyle(labelColor)
                    }
                }
                .contentShape(Rectangle())
            }.buttonStyle(.plain)

            if open {
                if routes.isEmpty {
                    Text("No flights yet.").font(.karla(12)).foregroundStyle(labelColor).padding(.leading, 4)
                } else {
                    VStack(spacing: 6) {
                        ForEach(routes) { flightRow($0, hub: code) }
                    }
                }
                paybackSubsection(code)
                opportunitiesSubsection(code)
            }
        }
        .padding(10)
        .background(innerCardBG)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(cardBorder, lineWidth: 1))
    }

    /// Hub payback chart — cumulative net of the routes this hub concentrates,
    /// measured against what the hub + club cost to build and run. Break-even at
    /// $0; a mint marker flags the month it recouped. This is the hub-as-a-whole
    /// bet (spoke routes minus facility costs), NOT the hub's isolated marginal
    /// uplift (an unmeasurable counterfactual) — labelled so it can't be misread.
    @ViewBuilder private func paybackSubsection(_ code: String) -> some View {
        Rectangle().fill(cardBorder).frame(height: 1).padding(.vertical, 4)
        Text("HUB P&L").font(.karla(10, .bold)).foregroundStyle(labelColor).tracking(0.5)
        Text("routes through \(code) − hub & club costs")
            .font(.karla(9)).foregroundStyle(labelColor.opacity(0.8))
        HubProfitChart(sim: sim, code: code, tick: sim.displayTick, isDark: isDark)
            .padding(.top, 2)
    }

    /// Route Opportunities radiating from this hub — mirrors OPS ▸ Route Opps
    /// (same demand model, hub-boosted). Tapping previews it on the map and drops
    /// into the SAME open-route flow (via sim.suggestRoute, which NetworkView adopts).
    @ViewBuilder private func opportunitiesSubsection(_ code: String) -> some View {
        let opps = sim.hubRouteOpportunities(from: code, limit: 4)
        if !opps.isEmpty {
            Rectangle().fill(cardBorder).frame(height: 1).padding(.vertical, 4)
            Text("ROUTE OPPORTUNITIES").font(.karla(10, .bold)).foregroundStyle(labelColor).tracking(0.5)
            VStack(spacing: 4) {
                ForEach(opps) { opp in
                    Button { sim.suggestRoute(from: opp.originCode, to: opp.destCode) } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(labelColor)
                            Text(opp.destCode).font(.karla(14, .bold)).foregroundStyle(primaryC)
                            Text(opp.destCity).font(.karla(10)).foregroundStyle(labelColor).lineLimit(1)
                            Spacer(minLength: 6)
                            Text("~\(opp.demandPerDay)/day").font(.karla(11, .bold)).foregroundStyle(green)
                            Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(labelColor.opacity(0.7))
                        }
                        .contentShape(Rectangle()).padding(.vertical, 2).padding(.horizontal, 4)
                    }.buttonStyle(.plain)
                }
            }
        }
    }

    private func flightRow(_ r: Route, hub: String) -> some View {
        let spoke = r.originCode == hub ? r.destCode : r.originCode
        let tail = sim.aircraft.first { $0.assignedRouteId == r.id }?.tail
        return HStack(spacing: 8) {
            Image(systemName: "arrow.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(labelColor)
            Text(spoke).font(.karla(14, .bold)).foregroundStyle(primaryC)
            if let tail { Text(tail).font(.karla(11)).foregroundStyle(labelColor) }
            Spacer(minLength: 6)
            Text(r.isProfitable ? "profitable" : "building")
                .font(.karla(10, .semibold)).foregroundStyle(r.isProfitable ? green : amber)
        }
        .padding(.vertical, 3).padding(.horizontal, 4)
    }
}

/// Per-hub payback line: cumulative spoke-route net measured against the hub's
/// facility cost (establish + club build + labor + rent). Break-even at $0, red
/// below / mint above, split at each crossing, with a marker + caption at recoup.
/// Modelled on `RouteProfitChart`; theme-aware to sit in the Hubs panel.
private struct HubProfitChart: View {
    let sim: Simulation
    let code: String
    /// Throttled tick — a CHANGING VALUE input so SwiftUI re-invokes the body and
    /// the Canvas redraws (without it the chart freezes; the documented pattern).
    let tick: Int
    let isDark: Bool

    private var mint: Color { isDark ? Color(red: 0x37/255, green: 1, blue: 0xB0/255) : Color(skyHex: 0x10B981) }
    private var red:  Color { isDark ? Color(red: 0xFF/255, green: 0x5C/255, blue: 0x5C/255) : Color(skyHex: 0xD70000) }
    private var ink:  Color { isDark ? .white : .black }

    /// (tick, payback) per stored month + a live trailing point for "now".
    private var points: [(tick: Int, value: Double)] {
        var pts = (sim.hubLedgers[code]?.monthly ?? []).map { (tick: $0.tick, value: Double($0.payback)) }
        pts.append((tick: sim.tick, value: Double(sim.hubPaybackNow(code))))
        return pts
    }
    /// First index (≥1) that reached break-even from below.
    private var recoupIndex: Int? {
        let p = points
        return p.indices.first { $0 >= 1 && p[$0].value >= 0 && p[$0 - 1].value < 0 }
    }

    var body: some View {
        let p = points
        VStack(alignment: .leading, spacing: 3) {
            if p.count < 2 {
                Text("Building payback history…")
                    .font(.karla(10)).foregroundStyle(ink.opacity(0.55))
                    .padding(.vertical, 20)
            } else {
                Canvas { ctx, size in draw(ctx, size, p) }
                    .frame(height: 108)
                caption(p)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private func caption(_ p: [(tick: Int, value: Double)]) -> some View {
        let now = p.last!.value
        if now >= 0 {
            // Recouped. Prefer the crossing month for the date; fall back to "now".
            let crossTick = recoupIndex.map { p[$0].tick } ?? sim.tick
            let est = sim.hubs[code]?.establishedTick ?? crossTick
            let mo = max(1, (crossTick - est) / Simulation.ticksPerMonth)
            Text("Recouped in ~\(mo) mo · \(Simulation.simDate(fromTick: crossTick))")
                .font(.karla(9)).foregroundStyle(mint)
        } else {
            Text("Not yet recouped · \(money(Int(-now))) to break-even")
                .font(.karla(9)).foregroundStyle(red)
        }
    }

    private func draw(_ ctx: GraphicsContext, _ size: CGSize, _ p: [(tick: Int, value: Double)]) {
        let s = p.map(\.value)
        let leftPad: CGFloat = 46, rightPad: CGFloat = 6, topPad: CGFloat = 6, bottomPad: CGFloat = 6
        let plotW = size.width - leftPad - rightPad
        let plotH = size.height - topPad - bottomPad
        let n = s.count
        let maxY = max(s.max() ?? 0, 0)
        let minY = min(s.min() ?? 0, 0)
        let range = max(1, maxY - minY)
        func sx(_ i: Int) -> CGFloat { leftPad + (n <= 1 ? 0 : plotW * CGFloat(i) / CGFloat(n - 1)) }
        func sy(_ v: Double) -> CGFloat { topPad + plotH * CGFloat(1 - (v - minY) / range) }

        let frame = isDark ? Color.white.opacity(0.10) : Color.black.opacity(0.10)
        let zeroC = isDark ? Color.white.opacity(0.35) : Color.black.opacity(0.28)
        ctx.stroke(Path(CGRect(x: leftPad, y: topPad, width: plotW, height: plotH)), with: .color(frame), lineWidth: 1)

        // Break-even (zero) line — dashed.
        let zy = sy(0)
        var z = Path(); z.move(to: CGPoint(x: leftPad, y: zy)); z.addLine(to: CGPoint(x: leftPad + plotW, y: zy))
        ctx.stroke(z, with: .color(zeroC), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))

        // Y labels: max (top), $0 (break-even), min (bottom).
        yLabel(ctx, money(Int(maxY)), CGPoint(x: leftPad - 5, y: sy(maxY)))
        yLabel(ctx, "$0", CGPoint(x: leftPad - 5, y: zy))
        yLabel(ctx, money(Int(minY)), CGPoint(x: leftPad - 5, y: sy(minY)))

        // Payback line, split at each zero crossing and coloured by sign.
        for i in 0..<(n - 1) {
            let x0 = sx(i), x1 = sx(i + 1), v0 = s[i], v1 = s[i + 1]
            if (v0 < 0) != (v1 < 0), v1 != v0 {
                let xc = x0 + (x1 - x0) * CGFloat(-v0 / (v1 - v0))
                seg(ctx, CGPoint(x: x0, y: sy(v0)), CGPoint(x: xc, y: zy), green: v0 >= 0)
                seg(ctx, CGPoint(x: xc, y: zy), CGPoint(x: x1, y: sy(v1)), green: v1 >= 0)
            } else {
                seg(ctx, CGPoint(x: x0, y: sy(v0)), CGPoint(x: x1, y: sy(v1)), green: (v0 + v1) >= 0)
            }
        }

        // Recoup marker at the first break-even crossing.
        if let k = recoupIndex, k < n {
            let v0 = s[k - 1], v1 = s[k]
            let xc = v1 != v0 ? sx(k - 1) + (sx(k) - sx(k - 1)) * CGFloat(-v0 / (v1 - v0)) : sx(k)
            ctx.fill(Path(ellipseIn: CGRect(x: xc - 3, y: zy - 3, width: 6, height: 6)), with: .color(mint))
        }
    }

    private func seg(_ ctx: GraphicsContext, _ a: CGPoint, _ b: CGPoint, green: Bool) {
        var path = Path(); path.move(to: a); path.addLine(to: b)
        ctx.stroke(path, with: .color(green ? mint : red), lineWidth: 1.5)
    }

    private func yLabel(_ ctx: GraphicsContext, _ s: String, _ at: CGPoint) {
        ctx.draw(Text(s).font(.system(size: 8, design: .monospaced)).foregroundColor(ink.opacity(0.5)),
                 at: at, anchor: .trailing)
    }

    private func money(_ v: Int) -> String {
        let a = abs(v), sign = v < 0 ? "−" : ""
        if a >= 1_000_000 { return sign + "$" + String(format: "%.1fM", Double(a) / 1_000_000) }
        if a >= 1_000     { return sign + "$" + String(format: "%.0fk", Double(a) / 1_000) }
        return sign + "$\(a)"
    }
}
