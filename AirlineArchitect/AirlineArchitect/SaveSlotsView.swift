//
//  SaveSlotsView.swift
//  Airline Architect
//
//  The load / slot-picker menu. Shown at cold launch when any saved game exists,
//  and again when the player taps QUIT. Up to three slots — enough to try a few
//  strategies side by side without saves becoming throwaway (a deliberate cap;
//  more would undercut the "run one airline with consequences" feel). Each saved
//  slot loads in place; each empty slot starts a fresh airline there.
//

import SwiftUI

struct SaveSlotsView: View {
    let onLoad: (Int) -> Void
    let onNew: (Int) -> Void
    let onDelete: (Int) -> Void

    /// Rebuilt from disk whenever the menu appears or a slot is deleted.
    @State private var slots: [SlotInfo?] = GameStore.slotInfos()
    /// Slot index awaiting delete confirmation (tap trash once to arm).
    @State private var confirmDelete: Int?

    @Environment(\.colorScheme) private var scheme
    private var isDark: Bool { scheme == .dark }
    private var screenBG: Color   { isDark ? Sky.darkBG : .white }
    private var cardBG: Color      { isDark ? Sky.navBarDark : .white }
    private var emptyBG: Color     { isDark ? .white.opacity(0.03) : Color(skyHex: 0xF6F7F9) }
    private var border: Color      { isDark ? Sky.onDarkStroke : Color(skyHex: 0xC9C9C9) }
    private var primary: Color     { isDark ? .white : .black }
    private var secondary: Color   { isDark ? Sky.lightBlue : Color(skyHex: 0x64748B) }

    var body: some View {
        ZStack {
            screenBG.ignoresSafeArea()
            VStack(spacing: 20) {
                VStack(spacing: 10) {
                    AppLogo().frame(width: 132, height: 106)
                    Text("Airline Architect").font(.karla(24, .bold)).foregroundStyle(primary)
                    Text("Choose a game to continue, or start a new airline.")
                        .font(.karla(13)).foregroundStyle(secondary)
                        .multilineTextAlignment(.center)
                }
                VStack(spacing: 12) {
                    ForEach(0..<GameStore.slotCount, id: \.self) { i in
                        slotRow(i, info: slots[safe: i] ?? nil)
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 420)
        }
        .onAppear { slots = GameStore.slotInfos() }
    }

    @ViewBuilder
    private func slotRow(_ index: Int, info: SlotInfo?) -> some View {
        if let info {
            savedRow(index, info)
        } else {
            emptyRow(index)
        }
    }

    private func savedRow(_ index: Int, _ info: SlotInfo) -> some View {
        VStack(spacing: 0) {
            Button { onLoad(index) } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(info.airlineName).font(.karla(17, .bold)).foregroundStyle(primary)
                            .lineLimit(1)
                        Text("Day \(info.day) · \(money(info.cash)) · \(info.fleet) aircraft · \(info.routes) routes")
                            .font(.karla(12)).foregroundStyle(secondary).lineLimit(1)
                        Text("Saved \(savedAgo(info.savedAtEpoch))")
                            .font(.karla(11)).foregroundStyle(secondary.opacity(0.7))
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 26)).foregroundStyle(Sky.brightBlue)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(cardBG)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(border, lineWidth: 1))
            }
            .buttonStyle(.plain).pressable()

            // Delete affordance — arm with one tap, confirm with the second.
            HStack {
                Spacer()
                if confirmDelete == index {
                    Text("Delete this airline?").font(.karla(11)).foregroundStyle(secondary)
                    Button("Cancel") { confirmDelete = nil }
                        .font(.karla(11, .semibold)).foregroundStyle(secondary)
                    Button("Delete") {
                        onDelete(index); confirmDelete = nil; slots = GameStore.slotInfos()
                    }
                    .font(.karla(11, .bold)).foregroundStyle(Sky.red)
                } else {
                    Button { confirmDelete = index } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "trash").font(.system(size: 10))
                            Text("Delete").font(.karla(11))
                        }.foregroundStyle(secondary.opacity(0.8))
                    }.buttonStyle(.plain)
                }
            }
            .padding(.top, 6).padding(.horizontal, 4)
        }
    }

    private func emptyRow(_ index: Int) -> some View {
        Button { onNew(index) } label: {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle").font(.system(size: 22)).foregroundStyle(secondary)
                Text("New Airline").font(.karla(16, .semibold)).foregroundStyle(secondary)
                Spacer()
                Text("Empty slot").font(.karla(12)).foregroundStyle(secondary.opacity(0.6))
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(emptyBG)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .stroke(border, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
        }
        .buttonStyle(.plain).pressable()
    }

    private func money(_ v: Int) -> String {
        let a = abs(v), sign = v < 0 ? "−" : ""
        if a >= 1_000_000 { return sign + "$" + String(format: "%.1fM", Double(a) / 1_000_000) }
        if a >= 1_000     { return sign + "$" + String(format: "%.0fk", Double(a) / 1_000) }
        return sign + "$\(a)"
    }

    /// Relative "saved …" label. Wall-clock, so it reads naturally in the menu.
    private func savedAgo(_ epoch: Double) -> String {
        guard epoch > 0 else { return "recently" }
        let secs = Date().timeIntervalSince1970 - epoch
        if secs < 90 { return "just now" }
        if secs < 3600 { return "\(Int(secs / 60))m ago" }
        if secs < 86_400 { return "\(Int(secs / 3600))h ago" }
        return "\(Int(secs / 86_400))d ago"
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
