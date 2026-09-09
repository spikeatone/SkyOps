//
//  CrewsView.swift
//  Airline Architect — the CREWS tab (v2, the training pipeline)
//
//  Built to the Figma (crews home 5:2439 light / 5:2218 dark; hire success
//  12:4509 / 12:4713), extended 8 Sep 2026 for the crew-training pipeline
//  (aa-1.1.x/CREW_TRAINING_SCOPE.md). One card per crew family the player owns
//  aircraft in, three bands: DEPLOYMENT (the 2×2 grid + a coverage readout —
//  line-ready crews per aircraft with a verdict from the sim's own duty/rest
//  math), the TRAINING PIPELINE (who's in a course and when they're back, lapsed
//  crews with a requalify action, the auto-recurrent policy), and HIRE (two
//  doors: a rated hire that's line-ready in ~10 days, or a new hire through the
//  type-rating course). Hiring is no longer instant — the banner says when the
//  crew will be line-ready. Theme-aware via the Sky tokens + light Figma colours.
//

import SwiftUI

/// The Chief Pilot's bundled portrait. Loaded by PATH, not `UIImage(named:)` —
/// `Resources/` uses file-system-synchronized groups, so loose files land FLAT in
/// the bundle root rather than in an asset catalog (the same reason
/// `ArchitectArt` loads its backdrops this way). Loaded once; nil if absent, and
/// the card falls back to a monogram.
enum ChiefPilotArt {
    static let portrait: Image? = {
        guard let path = Bundle.main.path(forResource: "ChiefPilot", ofType: "png"),
              let ui = UIImage(contentsOfFile: path) else { return nil }
        return Image(uiImage: ui)
    }()
}

struct CrewsView: View {
    let sim: Simulation
    var onBell: () -> Void = {}
    var onSave: () -> Void = {}
    var onQuit: () -> Void = {}
    @Environment(\.colorScheme) private var scheme
    private var isDark: Bool { scheme == .dark }

    @State private var successMessage: LocalizedStringKey?

    // Theme tokens (light Figma / dark Sky).
    private var bg: Color         { isDark ? Sky.darkBG : Color(skyHex: 0xF1F1F1) }
    private var cardBG: Color      { isDark ? Sky.navBarDark : .white }
    private var cardBorder: Color  { isDark ? Sky.onDarkStroke.opacity(0.6) : Color(skyHex: 0xE6E6E6) }
    private var titleColor: Color  { isDark ? Sky.lightBlue : Color(skyHex: 0x4E67A0) }
    private var primary: Color     { isDark ? .white : .black }
    private var secondary: Color   { isDark ? Sky.lightBlue.opacity(0.75) : Color(skyHex: 0x64748B) }
    private var subBG: Color       { isDark ? Sky.darkBG : Color(skyHex: 0xF9F9F9) }
    private var red: Color         { isDark ? Color(skyHex: 0xFF9292) : Color(skyHex: 0xD70000) }
    private let amber = Color(skyHex: 0xFFAB44)

    // Sub-box palette (accent boxes identical both themes; Resting differs).
    private let available = Color(skyHex: 0x10B981)
    private let onDuty = Color(skyHex: 0x497AA5)
    private let reserve = Color(skyHex: 0x6E43A6)
    private var restingBG: Color   { isDark ? Color(skyHex: 0x555E70) : Color(skyHex: 0xF1F1F1) }
    private var restingText: Color { isDark ? .white : Color(skyHex: 0x64748B) }
    private let hireBlue = Color(skyHex: 0x5B98CE)

    var body: some View {
        let _ = sim.displayTick   // throttled UI heartbeat (not raw tick) — keeps tab-switching/scrolling responsive
        ZStack {
            bg.ignoresSafeArea()
            VStack(spacing: 16) {
                header
                if let msg = successMessage { successBanner(msg) }
                let fams = sim.ownedFamilies
                if fams.isEmpty {
                    VStack(spacing: 8) {
                        Text("No crews yet").font(.karla(16, .bold)).foregroundStyle(primary)
                        Text("Buy or lease an aircraft to start a crew pool.")
                            .font(.karla(14)).foregroundStyle(secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity).padding(.top, 40)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            chiefPilotCard
                            providerCard
                            ForEach(fams, id: \.self) { crewCard($0) }
                        }
                        .padding(.bottom, 8)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
        }
    }

    // MARK: Header
    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("Cash on hand:").font(.karla(15, .semibold)).foregroundStyle(primary)
                Text(cashString).font(.karla(15, .semibold))
                    .foregroundStyle(sim.playerBalance < 0 ? Sky.red : Sky.coreGreen)
                Spacer(minLength: 8)
                SaveQuitBar(onSave: onSave, onQuit: onQuit)
            }
            Divider().overlay(cardBorder)
            HStack {
                Text("CREWS HOME").font(.karla(22, .bold)).foregroundStyle(titleColor)
                Spacer()
                AlertBell(count: sim.decisionQueue.count, tint: titleColor, action: onBell)
            }
        }
    }

    // MARK: Success banner (hire confirmation)
    private func successBanner(_ msg: LocalizedStringKey) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "hand.thumbsup.fill").font(.system(size: 16)).foregroundStyle(.white)
            Text(msg).font(.karla(14, .bold)).foregroundStyle(.white)
            Spacer(minLength: 0)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(skyHex: 0x10B981))
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(skyHex: 0x87ED7A), lineWidth: 1))
        .transition(.opacity)
    }

    // MARK: Chief Pilot — the crew read-out that answers "structural or transient?"
    //
    // He REPORTS and FORECASTS; he never acts. There is deliberately no hire button
    // here — the arithmetic across ~10 family cards is what's hard to see, not the
    // decision. Portrait is optional: a bundled photo if present, else a monogram.
    private var chiefPilotCard: some View {
        let outlooks = sim.crewOutlooks()
        let flagged = outlooks.filter { $0.kind != .healthy }
        let healthy = outlooks.count - flagged.count
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                chiefPilotPortrait
                VStack(alignment: .leading, spacing: 2) {
                    Text("CHIEF PILOT").font(.karla(11, .bold)).foregroundStyle(secondary).tracking(0.5)
                    Text(Simulation.chiefPilotName).font(.karla(17, .heavy)).foregroundStyle(primary)
                    Text(headline(flagged: flagged.count, healthy: healthy))
                        .font(.karla(12)).foregroundStyle(secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            if flagged.isEmpty {
                Text("\"Crew levels look healthy across the fleet. Nothing needs you today.\"")
                    .font(.karla(13)).foregroundStyle(secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                // Cap the list — at ~10 families a wall of rows is the problem, not the fix.
                ForEach(Array(flagged.prefix(4).enumerated()), id: \.offset) { _, o in
                    adviceRow(o)
                }
                if flagged.count > 4 {
                    Text("+\(flagged.count - 4) more families below")
                        .font(.karla(11)).foregroundStyle(secondary)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBG)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(cardBorder, lineWidth: 1))
    }

    /// Bundled portrait if the designer has dropped one in; a monogram otherwise, so
    /// the card looks deliberate either way.
    @ViewBuilder private var chiefPilotPortrait: some View {
        let side: CGFloat = 52
        if let art = ChiefPilotArt.portrait {
            art.resizable().aspectRatio(contentMode: .fill)
                .frame(width: side, height: side).clipShape(Circle())
                .overlay(Circle().stroke(cardBorder, lineWidth: 1))
        } else {
            ZStack {
                Circle().fill(hireBlue.opacity(0.18))
                Image(systemName: "person.fill").font(.system(size: 22)).foregroundStyle(hireBlue)
            }
            .frame(width: side, height: side)
            .overlay(Circle().stroke(cardBorder, lineWidth: 1))
        }
    }

    private func headline(flagged: Int, healthy: Int) -> LocalizedStringKey {
        if flagged == 0 { return "All \(healthy) crew families staffed for continuous coverage" }
        if flagged == 1 { return "1 family needs a look · \(healthy) staffed" }
        return "\(flagged) families need a look · \(healthy) staffed"
    }

    /// One line of advice. States what IS and what's coming — never what to click.
    @ViewBuilder private func adviceRow(_ o: Simulation.CrewOutlook) -> some View {
        let name = CREW_FAMILY_INFO[o.family]?.name ?? FAMILY_LABELS[o.family] ?? o.family
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: adviceIcon(o.kind)).font(.system(size: 12, weight: .semibold))
                .foregroundStyle(adviceColor(o.kind)).frame(width: 14)
            VStack(alignment: .leading, spacing: 1) {
                Text(LocalizedStringKey(name)).font(.karla(13, .bold)).foregroundStyle(primary)
                Text(adviceText(o)).font(.karla(12)).foregroundStyle(adviceColor(o.kind))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
    private func adviceIcon(_ k: Simulation.CrewOutlookKind) -> String {
        switch k {
        case .lapsed:     return "exclamationmark.triangle.fill"
        case .structural: return "person.badge.plus"
        case .transient:  return "graduationcap.fill"
        case .wave:       return "calendar"
        case .healthy:    return "checkmark.circle"
        }
    }
    private func adviceColor(_ k: Simulation.CrewOutlookKind) -> Color {
        switch k {
        case .lapsed:     return red
        case .structural: return amber
        case .transient:  return hireBlue
        case .wave:       return secondary
        case .healthy:    return available
        }
    }
    private func adviceText(_ o: Simulation.CrewOutlook) -> LocalizedStringKey {
        switch o.kind {
        case .lapsed:
            return o.lapsed == 1
                ? "1 crew grounded on lapsed currency — requalify to get it back on the line"
                : "\(o.lapsed) crews grounded on lapsed currency — requalify to get them back on the line"
        case .structural:
            // The one case where hiring is genuinely the answer — say so, don't do it.
            return o.hireNeeded == 1
                ? "Short 1 crew even after training lands — a permanent shortfall"
                : "Short \(o.hireNeeded) crews even after training lands — a permanent shortfall"
        case .transient:
            if let d = o.backInDays {
                return "Thin right now, but \(o.inTraining) in training — first one back in \(d) days"
            }
            return "Thin right now, but \(o.inTraining) in training"
        case .wave:
            return "Staffed, but \(o.dueSoon) due for recurrent within \(Simulation.recurrentWindowDays) days — expect a dip"
        case .healthy:
            return "Staffed for continuous coverage"
        }
    }

    // MARK: Provider card — the contract trainer, or the player's own Training Center (Phase 2)
    @ViewBuilder private var providerCard: some View {
        if let center = sim.trainingCenter { centerCard(center) } else { contractCard }
    }

    private var contractCard: some View {
        let hubs = sim.trainingCenterEligibleHubs
        let cost = Simulation.trainingCenterFacilityCost
        return VStack(alignment: .leading, spacing: 8) {
            Text("TRAINING").font(.karla(11, .bold)).foregroundStyle(secondary).tracking(0.5)
            HStack(spacing: 8) {
                MilestoneIconArtView(name: "graduationcap.fill", color: hireBlue).frame(width: 18, height: 18)
                Text(Simulation.crewProviderName).font(.karla(16, .heavy)).foregroundStyle(primary)
                Text("· contract provider").font(.karla(13)).foregroundStyle(secondary)
                Spacer(minLength: 0)
            }
            Text("Rated hire line-ready in \(Simulation.ratedHireDays) days · type-rating course \(Simulation.newHireCourseDays) days · recurrent \(Simulation.recurrentDays) days, every \(Crew.currencyDays) days (auto-scheduled a few crews at a time)")
                .font(.karla(12)).foregroundStyle(secondary).fixedSize(horizontal: false, vertical: true)
            Divider().overlay(cardBorder.opacity(0.5))
            // Build your own — the mid-game facility.
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Build a training center").font(.karla(14, .bold)).foregroundStyle(primary)
                    Text(hubs.isEmpty
                         ? "Needs an operating hub. Then a sim bay per crew family (\(Simulation.simBayMinAircraft)+ aircraft) trains it in-house: courses 60% cheaper, a third shorter, no class-slot wait."
                         : "At one of your hubs. Then a sim bay per crew family (\(Simulation.simBayMinAircraft)+ aircraft) trains it in-house: courses 60% cheaper, a third shorter, no class-slot wait.")
                        .font(.karla(12)).foregroundStyle(secondary).fixedSize(horizontal: false, vertical: true)
                    Text(money(cost)).font(.karla(14, .bold)).foregroundStyle(primary)
                }
                Spacer(minLength: 6)
                buildCenterControl(hubs: hubs, cost: cost)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBG)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(cardBorder, lineWidth: 1))
    }

    /// One hub → a direct BUILD; several → a menu to pick the site; none → disabled.
    @ViewBuilder private func buildCenterControl(hubs: [String], cost: Int) -> some View {
        let afford = sim.playerBalance >= cost
        if hubs.count == 1, let h = hubs.first {
            Button { if sim.buildTrainingCenter(at: h) { Feedback.success() } } label: {
                actionLabel("BUILD · \(h)", enabled: afford)
            }.buttonStyle(.plain).disabled(!afford)
        } else if hubs.count > 1 {
            Menu {
                ForEach(hubs, id: \.self) { h in
                    Button("Build at \(h)") { if sim.buildTrainingCenter(at: h) { Feedback.success() } }
                }
            } label: { actionLabel("BUILD ▾", enabled: afford) }
            .disabled(!afford)
        } else {
            actionLabel("BUILD", enabled: false)
        }
    }
    private func actionLabel(_ t: LocalizedStringKey, enabled: Bool) -> some View {
        Text(t).font(.karla(12, .bold)).foregroundStyle(.white)
            .frame(height: 24).padding(.horizontal, 8)
            .background(hireBlue).clipShape(RoundedRectangle(cornerRadius: 4))
            .opacity(enabled ? 1 : 0.4)
    }

    private func centerCard(_ center: TrainingCenter) -> some View {
        let opex = sim.trainingCenterMonthlyOpex
        let payback = center.ledger.payback
        let bays = center.bays.keys.sorted()
        return VStack(alignment: .leading, spacing: 8) {
            Text("TRAINING").font(.karla(11, .bold)).foregroundStyle(secondary).tracking(0.5)
            HStack(spacing: 8) {
                Image(systemName: "building.2.fill").font(.system(size: 16)).foregroundStyle(hireBlue)
                Text("Training Center · \(center.hubCode)").font(.karla(16, .heavy)).foregroundStyle(primary)
                Spacer(minLength: 0)
                // Literal-with-interpolation (NOT Text(verbatim:) + concatenation) so
                // the "/mo" suffix actually enters the string catalog and gets German.
                Text("−\(compact(opex))/mo").font(.karla(13, .bold)).foregroundStyle(secondary)
            }
            if bays.isEmpty {
                Text("No sim bays yet — add one on a crew family's card (\(Simulation.simBayMinAircraft)+ aircraft) to train that family in-house. Everyone else still trains with \(Simulation.crewProviderName).")
                    .font(.karla(12)).foregroundStyle(secondary).fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(bays, id: \.self) { fam in
                    HStack(spacing: 6) {
                        MilestoneIconArtView(name: "graduationcap.fill", color: hireBlue).frame(width: 13, height: 13)
                        Text(LocalizedStringKey(CREW_FAMILY_INFO[fam]?.name ?? fam)).font(.karla(13, .bold)).foregroundStyle(primary)
                        Spacer(minLength: 6)
                        Text("\(sim.centerLoad(family: fam))/\(Simulation.simBayCapacity) bay seats in use")
                            .font(.karla(12)).foregroundStyle(secondary)
                    }
                }
            }
            // TRAINING P&L — what in-house courses saved against the contract price
            // (a counterfactual, labelled as such), minus the facility + opex.
            Divider().overlay(cardBorder.opacity(0.5))
            HStack(alignment: .firstTextBaseline) {
                Text("TRAINING P&L").font(.karla(11, .bold)).foregroundStyle(secondary).tracking(0.5)
                Spacer(minLength: 6)
                Text(verbatim: payback >= 0 ? "+" + compact(payback) : "−" + compact(-payback))
                    .font(.karla(16, .heavy)).foregroundStyle(payback >= 0 ? available : red)
            }
            // The two halves, split on purpose: at real simulator prices the course
            // FEE saving alone can never repay a bay — throughput is the actual
            // reason airlines own simulators, so the chart shows both.
            ledgerLine("Course savings vs. contract", center.ledger.savings, available)
            ledgerLine("Crew time returned to the line", center.ledger.timeValue ?? 0, available)
            ledgerLine("Facility + sim bays", -center.ledger.facilitySpend, red)
            ledgerLine("Running costs to date", -center.ledger.opexPaid, red)
            Text("Crew time is valued at what a crew-day is worth to the families you fly — and only while crew is actually your binding constraint. Deep cover, little value; stretched, a lot.")
                .font(.karla(11)).foregroundStyle(secondary)
                .fixedSize(horizontal: false, vertical: true)
            PaybackSparkline(values: center.ledger.monthly.map { Double($0.payback) } + [Double(payback)],
                             mint: available, red: red, frame: cardBorder)
                .frame(height: 44)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBG)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(cardBorder, lineWidth: 1))
    }

    /// One line of the Training P&L breakdown.
    private func ledgerLine(_ label: LocalizedStringKey, _ amount: Int, _ tint: Color) -> some View {
        HStack {
            Text(label).font(.karla(12)).foregroundStyle(secondary)
            Spacer(minLength: 6)
            Text(verbatim: (amount < 0 ? "−" : "+") + compact(abs(amount)))
                .font(.karla(12, .bold)).foregroundStyle(amount < 0 ? red : tint)
        }
    }

    /// The family's sim-bay status once a center exists: an IN-HOUSE line with the
    /// bay's load, or the ADD BAY action (gated on 6+ aircraft + cash).
    private func bayRow(_ fam: String) -> some View {
        HStack(spacing: 8) {
            if sim.hasSimBay(family: fam) {
                Image(systemName: "building.2.fill").font(.system(size: 12)).foregroundStyle(hireBlue)
                Text("Trains in-house · \(sim.centerLoad(family: fam))/\(Simulation.simBayCapacity) bay seats in use")
                    .font(.karla(13)).foregroundStyle(primary)
                Spacer(minLength: 0)
            } else {
                let owned = sim.ownedCount(family: fam)
                let enough = owned >= Simulation.simBayMinAircraft
                let cost = sim.simBayCost(family: fam)
                let can = sim.canAddSimBay(family: fam)
                let payback = sim.simBayPaybackAircraft(family: fam)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sim bay").font(.karla(13, .bold)).foregroundStyle(primary)
                    Text(enough ? "Train this family in-house · \(money(cost))"
                                : "Needs \(Simulation.simBayMinAircraft) aircraft in the family (have \(owned))")
                        .font(.karla(12)).foregroundStyle(secondary).fixedSize(horizontal: false, vertical: true)
                    // The build gate is well below break-even, so say where that is
                    // rather than letting the player buy a bay that never repays.
                    if enough && owned < payback {
                        // Fee savings alone — crew-time value counts on top, and is
                        // what actually carries a bay at real simulator prices.
                        Text("Course fees alone repay it above ~\(payback) aircraft; crew time saved counts on top")
                            .font(.karla(11)).foregroundStyle(amber).fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 6)
                Button { if sim.addSimBay(family: fam) { Feedback.success() } } label: {
                    actionLabel("ADD BAY", enabled: can)
                }.buttonStyle(.plain).disabled(!can)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(subBG)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: Crew card
    private func crewCard(_ fam: String) -> some View {
        let pool = sim.crewPoolsByFamily[fam] ?? []
        let avail = pool.filter { $0.status == .available }.count
        let duty = pool.filter { $0.status == .onDuty }.count
        let resting = pool.filter { $0.status == .resting }.count
        let reserveN = sim.reserveCrewsByFamily[fam] ?? 0
        let info = CREW_FAMILY_INFO[fam] ?? (name: FAMILY_LABELS[fam] ?? fam, coverage: "")
        let thin = avail == 0 && sim.ownedCount(family: fam) > 0
        let coverage = sim.crewCoverage(family: fam)
        let training = pool.filter { $0.status == .training }.sorted { ($0.readyTick ?? 0) < ($1.readyTick ?? 0) }
        let lapsed = pool.filter { $0.status == .lapsed }.count

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey(info.name)).font(.karla(20, .heavy)).foregroundStyle(primary)
                    Text(LocalizedStringKey(info.coverage)).font(.karla(14)).foregroundStyle(secondary)
                }
                Spacer()
                if thin { runningThinChip }
            }
            // DEPLOYMENT — the 2×2 grid + the coverage readout
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    dataBox("Available", avail, available, .white)
                    dataBox("On duty", duty, onDuty, .white)
                }
                HStack(spacing: 8) {
                    dataBox("Resting", resting, restingBG, restingText)
                    dataBox("Reserve", reserveN, reserve, .white)
                }
            }
            coverageLine(coverage)
            if sim.trainingCenter != nil { bayRow(fam) }
            // TRAINING PIPELINE — only when there's something in it, or the policy is off
            if !training.isEmpty || lapsed > 0 || !sim.crewAutoRecurrentOn(fam) {
                pipelineBand(fam, pool: pool, training: training, lapsed: lapsed)
            } else {
                recurrentLine(fam, pool: pool)
            }
            // Labor-action alert (a #9 event has sidelined crew in this family)
            if let expiry = sim.laborActionExpiryByFamily[fam], expiry > sim.displayTick {
                laborAlertBox(pool.filter { $0.status == .sidelined }.count, expiry)
            }
            // HIRE — the two doors
            hireRow(title: "Rated hire",
                    detail: "Already type-rated · line-ready in \(Simulation.ratedHireDays) days",
                    cost: sim.crewHireCost(family: fam, mode: .rated)) { hire(fam, name: info.name, mode: .rated) }
            hireRow(title: "New hire + type rating",
                    detail: newHireDetail(fam),
                    cost: sim.crewHireCost(family: fam, mode: .newHire)) { hire(fam, name: info.name, mode: .newHire) }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBG)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(cardBorder, lineWidth: 1))
    }

    // MARK: Coverage readout (designer decision 4 — ratio + verdict)
    private func coverageLine(_ c: Simulation.CrewCoverage) -> some View {
        let ratio = String(format: "%.1f", c.ratio)
        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\(c.lineReady) line-ready for \(c.aircraft) aircraft · \(ratio) per aircraft")
                .font(.karla(13)).foregroundStyle(secondary)
            Spacer(minLength: 6)
            Text(verdictLabel(c.verdict)).font(.karla(12, .bold)).foregroundStyle(verdictColor(c.verdict))
                .multilineTextAlignment(.trailing)
        }
    }
    private func verdictLabel(_ v: Simulation.CrewCoverageVerdict) -> LocalizedStringKey {
        switch v {
        case .continuous: return "Continuous coverage"
        case .thin:       return "Thin — expect occasional crew holds"
        case .under:      return "Under-crewed — holds likely"
        case .none:       return "No aircraft"
        }
    }
    private func verdictColor(_ v: Simulation.CrewCoverageVerdict) -> Color {
        switch v {
        case .continuous: return available
        case .thin:       return amber
        case .under:      return red
        case .none:       return secondary
        }
    }

    // MARK: Training pipeline band
    private func pipelineBand(_ fam: String, pool: [Crew], training: [Crew], lapsed: Int) -> some View {
        let now = sim.displayTick
        return VStack(alignment: .leading, spacing: 8) {
            Text("TRAINING PIPELINE").font(.karla(11, .bold)).foregroundStyle(secondary).tracking(0.5)
            ForEach(training, id: \.id) { c in
                let days = max(1, ((c.readyTick ?? now) - now + 1439) / 1440)
                HStack(spacing: 6) {
                    MilestoneIconArtView(name: "graduationcap.fill", color: hireBlue).frame(width: 13, height: 13)
                    Text(pipelineLabel(c.trainingKind, days: days)).font(.karla(13)).foregroundStyle(primary)
                    if c.trainingProvider == .center {
                        Text("· in-house").font(.karla(12)).foregroundStyle(hireBlue)
                    }
                    Spacer(minLength: 0)
                }
            }
            if lapsed > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 13)).foregroundStyle(red)
                    Text(lapsed == 1 ? "1 crew lapsed — can't fly until requalified"
                                     : "\(lapsed) crews lapsed — can't fly until requalified")
                        .font(.karla(13, .bold)).foregroundStyle(red)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 6)
                    let cost = sim.crewRetrainCost(family: fam)
                    Button {
                        if sim.retrainLapsed(family: fam) { Feedback.impact(.medium) }
                    } label: {
                        Text("REQUALIFY \(compact(cost))").font(.karla(12, .bold)).foregroundStyle(.white)
                            .frame(height: 24).padding(.horizontal, 8)
                            .background(red).clipShape(RoundedRectangle(cornerRadius: 4))
                            .opacity(sim.playerBalance >= cost ? 1 : 0.4)
                    }.buttonStyle(.plain).disabled(sim.playerBalance < cost)
                }
            }
            recurrentLine(fam, pool: pool)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(subBG)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    /// The recurrent schedule line + the per-family AUTO toggle.
    private func recurrentLine(_ fam: String, pool: [Crew]) -> some View {
        let auto = sim.crewAutoRecurrentOn(fam)
        let now = sim.displayTick
        let dueSoon = pool.filter { $0.isLineReady && $0.currencyExpiresTick - now <= Simulation.recurrentWindowDays * 1440 }.count
        return HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Recurrent training").font(.karla(13, .bold)).foregroundStyle(primary)
                Text(auto ? recurrentAutoText(dueSoon) : "OFF — crews lapse when their currency runs out")
                    .font(.karla(12)).foregroundStyle(auto ? secondary : red)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 6)
            Toggle("", isOn: Binding(get: { sim.crewAutoRecurrentOn(fam) },
                                     set: { sim.setCrewAutoRecurrent($0, family: fam) }))
                .labelsHidden().tint(available)
        }
    }
    private func recurrentAutoText(_ dueSoon: Int) -> LocalizedStringKey {
        switch dueSoon {
        case 0:  return "Auto-scheduled · none due within \(Simulation.recurrentWindowDays) days"
        case 1:  return "Auto-scheduled · 1 crew due within \(Simulation.recurrentWindowDays) days"
        default: return "Auto-scheduled · \(dueSoon) crews due within \(Simulation.recurrentWindowDays) days"
        }
    }
    private func pipelineLabel(_ k: Crew.TrainingKind?, days: Int) -> LocalizedStringKey {
        switch k {
        case .initial:       return days == 1 ? "New crew in training · line-ready tomorrow" : "New crew in training · line-ready in \(days) days"
        case .recurrent:     return days == 1 ? "Recurrent training · back tomorrow" : "Recurrent training · back in \(days) days"
        case .requal, .none: return days == 1 ? "Requalifying · back tomorrow" : "Requalifying · back in \(days) days"
        }
    }

    /// Red "N sidelined; labor action — D days left" box (Figma crew alert box).
    private func laborAlertBox(_ sidelined: Int, _ expiry: Int) -> some View {
        let daysLeft = max(1, (expiry - sim.displayTick + 1439) / 1440)
        return HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 14)).foregroundStyle(red)
            Text(daysLeft == 1
                 ? "\(sidelined) sidelined; labor action — \(daysLeft) day left"
                 : "\(sidelined) sidelined; labor action — \(daysLeft) days left")
                .font(.karla(14, .bold)).foregroundStyle(red)
            Spacer(minLength: 0)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(subBG)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(red, lineWidth: 1))
    }

    private func dataBox(_ label: LocalizedStringKey, _ value: Int, _ boxBG: Color, _ textColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.karla(14)).foregroundStyle(textColor.opacity(0.95))
            Text("\(value)").font(.karla(24, .heavy)).foregroundStyle(textColor)
        }
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .topLeading)
        .padding(8)
        .background(boxBG)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private var runningThinChip: some View {
        Text("RUNNING THIN").font(.karla(10, .bold)).foregroundStyle(.white)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(amber)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(skyHex: 0xFFB75F), lineWidth: 1))
    }

    // MARK: Hire (two doors)
    private func hireRow(title: LocalizedStringKey, detail: LocalizedStringKey, cost: Int,
                         action: @escaping () -> Void) -> some View {
        let afford = sim.playerBalance >= cost
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.karla(14, .bold)).foregroundStyle(primary)
                Text(detail).font(.karla(12)).foregroundStyle(secondary).fixedSize(horizontal: false, vertical: true)
                Text(money(cost)).font(.karla(14, .bold)).foregroundStyle(primary)
            }
            Spacer()
            Button(action: action) {
                Text("HIRE").font(.karla(12, .bold)).foregroundStyle(.white)
                    .frame(height: 24).padding(.horizontal, 8)
                    .background(hireBlue).clipShape(RoundedRectangle(cornerRadius: 4))
                    .opacity(afford ? 1 : 0.4)
            }.buttonStyle(.plain).disabled(!afford)
        }
        .padding(8)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(cardBorder, lineWidth: 1))
    }

    /// The new-hire door's detail line: in-house (30 days, no wait) once the family
    /// has a bay seat free, otherwise the contract course plus its class-slot wait.
    private func newHireDetail(_ fam: String) -> LocalizedStringKey {
        sim.trainingProvider(for: fam) == .center
            ? "\(Simulation.centerNewHireCourseDays)-day course in-house · no class-slot wait"
            : "\(Simulation.newHireCourseDays)-day course with \(Simulation.crewProviderName) · plus up to \(Simulation.contractLeadDaysMax) days for a class slot"
    }

    private func hire(_ fam: String, name: String, mode: Simulation.CrewHireMode) {
        guard let id = sim.hireCrew(family: fam, mode: mode) else { return }
        Feedback.crewHired()
        // Quote the crew's ACTUAL readyTick, not the course baseline: a contract new
        // hire also waits 0–10 days for a class slot, so the baseline disagreed with
        // the pipeline row rendered right below (banner said 45, the row said 52).
        let hired = sim.crewPoolsByFamily[fam]?.first { $0.id == id }
        let days = hired?.readyTick.map { max(1, ($0 - sim.tick + 1439) / 1440) }
            ?? sim.crewHireDays(mode: mode, family: fam)
        let msg: LocalizedStringKey = mode == .rated
            ? "New \(name) crew hired — line-ready in \(days) days"
            : "New \(name) crew hired — in the type-rating course, line-ready in \(days) days"
        withAnimation { successMessage = msg }
        Task {
            try? await Task.sleep(for: .seconds(3))
            withAnimation { if successMessage != nil { successMessage = nil } }
        }
    }

    private var cashString: String { cashLabel(sim.playerBalance) }

    private func money(_ v: Int) -> String { Currency.symbol + v.formatted(.number.grouping(.automatic)) }
    private func compact(_ v: Int) -> String {
        v >= 1_000_000 ? (Currency.symbol + String(format: "%.1fM", Double(v) / 1_000_000)) : "\(Currency.symbol)\(v / 1000)k"
    }
}

/// The Training Center's payback line: the monthly ledger points + a live trailing
/// point, red below break-even / mint above, dashed zero line. Takes `values` as a
/// CHANGING input (the live point moves), so the Canvas re-renders — the documented
/// freeze-avoidance pattern.
private struct PaybackSparkline: View {
    let values: [Double]
    let mint: Color, red: Color, frame: Color

    var body: some View {
        Canvas { ctx, size in
            // Draw the break-even line even with a single point — the ledger has no
            // monthly points until the first billing tick, and an empty 44pt band
            // under a live "TRAINING P&L" figure reads as broken.
            guard let first = values.first else { return }
            let maxY = max(values.max() ?? 0, 0), minY = min(values.min() ?? 0, 0)
            let range = max(1, maxY - minY)
            let pad: CGFloat = 3
            func sx(_ i: Int) -> CGFloat { pad + (size.width - 2 * pad) * CGFloat(i) / CGFloat(max(1, values.count - 1)) }
            func sy(_ v: Double) -> CGFloat { pad + (size.height - 2 * pad) * CGFloat(1 - (v - minY) / range) }
            // Break-even (zero) line.
            var z = Path(); z.move(to: CGPoint(x: pad, y: sy(0))); z.addLine(to: CGPoint(x: size.width - pad, y: sy(0)))
            ctx.stroke(z, with: .color(frame), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            guard values.count >= 2 else {
                // Single point (a center built this month): mark where it stands.
                let r: CGFloat = 2.5, y = sy(first)
                ctx.fill(Path(ellipseIn: CGRect(x: pad - r, y: y - r, width: r * 2, height: r * 2)),
                         with: .color(first >= 0 ? mint : red))
                return
            }
            // One segment per step, coloured by which side of zero it ends on.
            for i in 1..<values.count {
                var p = Path()
                p.move(to: CGPoint(x: sx(i - 1), y: sy(values[i - 1])))
                p.addLine(to: CGPoint(x: sx(i), y: sy(values[i])))
                ctx.stroke(p, with: .color(values[i] >= 0 ? mint : red), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            }
        }
    }
}
