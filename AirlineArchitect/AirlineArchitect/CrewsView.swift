//
//  CrewsView.swift
//  Airline Architect — the CREWS tab
//
//  Built to the Figma (crews home 5:2439 light / 5:2218 dark; hire success
//  12:4509 / 12:4713). One card per crew family the player owns aircraft in:
//  a 2×2 grid (Available / On duty / Resting / Reserve), a "Running thin" chip
//  when there's no crew ready, and a "New crew · $X · HIRE" action. Hiring is
//  immediate (sim.hireCrew) with a green success banner. Theme-aware via the
//  Sky tokens + light Figma colours.
//

import SwiftUI

struct CrewsView: View {
    let sim: Simulation
    var onBell: () -> Void = {}
    var onSave: () -> Void = {}
    var onQuit: () -> Void = {}
    @Environment(\.colorScheme) private var scheme
    private var isDark: Bool { scheme == .dark }

    @State private var successMessage: String?

    // Theme tokens (light Figma / dark Sky).
    private var bg: Color         { isDark ? Sky.darkBG : Color(skyHex: 0xF1F1F1) }
    private var cardBG: Color      { isDark ? Sky.navBarDark : .white }
    private var cardBorder: Color  { isDark ? Sky.onDarkStroke.opacity(0.6) : Color(skyHex: 0xE6E6E6) }
    private var titleColor: Color  { isDark ? Sky.lightBlue : Color(skyHex: 0x4E67A0) }
    private var primary: Color     { isDark ? .white : .black }
    private var secondary: Color   { isDark ? Sky.lightBlue.opacity(0.75) : Color(skyHex: 0x64748B) }

    // Sub-box palette (accent boxes identical both themes; Resting differs).
    private let available = Color(skyHex: 0x10B981)
    private let onDuty = Color(skyHex: 0x497AA5)
    private let reserve = Color(skyHex: 0x6E43A6)
    private var restingBG: Color   { isDark ? Color(skyHex: 0x555E70) : Color(skyHex: 0xF1F1F1) }
    private var restingText: Color { isDark ? .white : Color(skyHex: 0x64748B) }
    private let hireBlue = Color(skyHex: 0x5B98CE)

    var body: some View {
        let _ = sim.tick   // live crew counts
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
    private func successBanner(_ msg: String) -> some View {
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

    // MARK: Crew card
    private func crewCard(_ fam: String) -> some View {
        let pool = sim.crewPoolsByFamily[fam] ?? []
        let avail = pool.filter { $0.status == .available }.count
        let duty = pool.filter { $0.status == .onDuty }.count
        let resting = pool.filter { $0.status == .resting }.count
        let reserveN = sim.reserveCrewsByFamily[fam] ?? 0
        let info = CREW_FAMILY_INFO[fam] ?? (name: FAMILY_LABELS[fam] ?? fam, coverage: "")
        let thin = avail == 0 && sim.ownedCount(family: fam) > 0
        let cost = sim.crewHireCost(family: fam)
        let afford = sim.playerBalance >= cost

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(info.name).font(.karla(20, .heavy)).foregroundStyle(primary)
                    Text(info.coverage).font(.karla(14)).foregroundStyle(secondary)
                }
                Spacer()
                if thin { runningThinChip }
            }
            // 2×2 grid
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
            // Labor-action alert (a #9 event has sidelined crew in this family)
            if let expiry = sim.laborActionExpiryByFamily[fam], expiry > sim.displayTick {
                laborAlertBox(pool.filter { $0.status == .sidelined }.count, expiry)
            }
            // Action box
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("New crew").font(.karla(14)).foregroundStyle(secondary)
                    Text(money(cost)).font(.karla(14, .bold)).foregroundStyle(primary)
                }
                Spacer()
                Button { hire(fam, name: info.name) } label: {
                    Text("HIRE").font(.karla(12, .bold)).foregroundStyle(.white)
                        .frame(height: 24).padding(.horizontal, 8)
                        .background(hireBlue).clipShape(RoundedRectangle(cornerRadius: 4))
                        .opacity(afford ? 1 : 0.4)
                }.buttonStyle(.plain).disabled(!afford)
            }
            .padding(8)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(cardBorder, lineWidth: 1))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBG)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(cardBorder, lineWidth: 1))
    }

    /// Red "N sidelined; labor action — D days left" box (Figma crew alert box).
    private func laborAlertBox(_ sidelined: Int, _ expiry: Int) -> some View {
        let daysLeft = max(1, (expiry - sim.displayTick + 1439) / 1440)
        let red = isDark ? Color(skyHex: 0xFF9292) : Color(skyHex: 0xD70000)
        return HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 14)).foregroundStyle(red)
            Text("\(sidelined) sidelined; labor action — \(daysLeft) day\(daysLeft == 1 ? "" : "s") left")
                .font(.karla(14, .bold)).foregroundStyle(red)
            Spacer(minLength: 0)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isDark ? Sky.darkBG : Color(skyHex: 0xF9F9F9))
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(red, lineWidth: 1))
    }

    private func dataBox(_ label: String, _ value: Int, _ boxBG: Color, _ textColor: Color) -> some View {
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
            .background(Color(skyHex: 0xFFAB44))
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(skyHex: 0xFFB75F), lineWidth: 1))
    }

    // MARK: Hire
    private func hire(_ fam: String, name: String) {
        guard sim.hireCrew(family: fam) != nil else { return }
        Feedback.crewHired()
        withAnimation { successMessage = "New \(name) crew successfully hired!" }
        Task {
            try? await Task.sleep(for: .seconds(3))
            withAnimation { if successMessage != nil { successMessage = nil } }
        }
    }

    private var cashString: String { cashLabel(sim.playerBalance) }

    private func money(_ v: Int) -> String { "$" + v.formatted(.number.grouping(.automatic)) }
}
