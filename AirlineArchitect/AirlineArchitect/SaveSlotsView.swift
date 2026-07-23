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
    /// Shared architect's-tools brand motif, at the same geometry the splash
    /// and naming screen use — so a returning player's splash → load-menu
    /// handoff carries the texture through instead of dropping it. `nil` = off.
    var backdropOpacity: Double? = nil
    /// Tint for that motif — white on the dark theme, brand ink on the light one.
    var backdropTint: Color = .white

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
            if let o = backdropOpacity { ArchitectBackdrop(opacity: o, tint: backdropTint) }
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
            // Swipe-left-to-delete wraps ONLY the card, so the red delete button
            // is exactly the CARD's height — not the card + the tap affordance.
            SwipeToDeleteContainer(onDelete: { performDelete(index) }) {
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
            }

            // Tap-delete affordance — OUTSIDE the swipe container (kept below the
            // card, so the swipe reveal stays card-height). Arm with one tap,
            // confirm with the second.
            HStack {
                Spacer()
                if confirmDelete == index {
                    Text("Delete this airline?").font(.karla(11)).foregroundStyle(secondary)
                    Button("Cancel") { confirmDelete = nil }
                        .font(.karla(11, .semibold)).foregroundStyle(secondary)
                    Button("Delete") { performDelete(index) }
                        .font(.karla(11, .bold)).foregroundStyle(Sky.red)
                } else {
                    Button { confirmDelete = index } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "trash").font(.system(size: 15))   // +50% (was 10)
                            Text("Delete").font(.karla(12))
                        }.foregroundStyle(secondary.opacity(0.8))
                    }.buttonStyle(.plain)
                }
            }
            .padding(.top, 6).padding(.horizontal, 4)
        }
    }

    private func performDelete(_ index: Int) {
        onDelete(index)
        confirmDelete = nil
        slots = GameStore.slotInfos()
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

/// Swipe-left-to-delete for a saved slot (the standard iOS pattern), added
/// ALONGSIDE the tap affordance. A partial left-swipe reveals a red delete
/// button; a full swipe deletes outright; swiping back closes it. Kept as a
/// self-contained wrapper so the compact centered card design (not a List)
/// is preserved. The drag uses `minimumDistance` so a plain TAP still reaches
/// the card's load/delete buttons underneath.
private struct SwipeToDeleteContainer<Content: View>: View {
    var revealWidth: CGFloat = 84
    let onDelete: () -> Void
    @ViewBuilder var content: Content

    @State private var offset: CGFloat = 0
    @State private var startOffset: CGFloat = 0
    @State private var dragging = false
    /// Measured content height. The delete button matches it EXACTLY — using
    /// `maxHeight: .infinity` here made each row greedy and spread the slots
    /// apart; sizing to the content keeps the three boxes compact.
    @State private var rowHeight: CGFloat = 0

    var body: some View {
        ZStack(alignment: .trailing) {
            Button(role: .destructive, action: triggerDelete) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .frame(width: revealWidth, height: rowHeight)
            .background(Sky.red)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .opacity(offset < -2 ? 1 : 0)   // only visible while swiped open

            content
                .offset(x: offset)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { rowHeight = $0 }
                .highPriorityGesture(
                    DragGesture(minimumDistance: 18)
                        .onChanged { v in
                            if !dragging { dragging = true; startOffset = offset }
                            // Clamp between fully-open (+a little overscroll) and closed.
                            offset = min(0, max(startOffset + v.translation.width, -(revealWidth + 60)))
                        }
                        .onEnded { _ in
                            dragging = false
                            if offset < -(revealWidth + 25) { triggerDelete() }
                            else if offset < -revealWidth * 0.5 { withAnimation(.snappy) { offset = -revealWidth } }
                            else { withAnimation(.snappy) { offset = 0 } }
                        }
                )
        }
    }

    private func triggerDelete() {
        withAnimation(.snappy) { offset = 0 }
        onDelete()
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
