//
//  SaveQuitBar.swift
//  Airline Architect
//
//  The Save / Quit control pair, flushed right on the cash line. Persistent
//  across every top-level tab (Network / Fleet / Crews / Ops / Finance) so the
//  player can save or quit from wherever they are. Self-contained "Saved ✓"
//  flash so every tab gives the same confirmation.
//

import SwiftUI

struct SaveQuitBar: View {
    let onSave: () -> Void
    let onQuit: () -> Void

    @State private var showSaved = false
    @Environment(\.colorScheme) private var scheme
    private var isDark: Bool { scheme == .dark }
    private var barBG: Color     { isDark ? Sky.navBarDark.opacity(0.92) : .white }
    private var barBorder: Color { isDark ? Sky.onDarkStroke.opacity(0.7) : Color(skyHex: 0xC9C9C9) }
    private var barText: Color   { isDark ? Sky.lightBlue : Color(skyHex: 0x497AA5) }

    var body: some View {
        HStack(spacing: 6) {
            if showSaved {
                Text("Saved ✓").font(.karla(12, .semibold)).foregroundStyle(Sky.coreGreen)
                    .transition(.opacity)
            }
            pill("Save", "arrow.down.circle") {
                onSave()
                Feedback.impact(.light)
                withAnimation(.easeOut(duration: 0.2)) { showSaved = true }
                Task {
                    try? await Task.sleep(for: .seconds(1.6))
                    withAnimation(.easeOut(duration: 0.3)) { showSaved = false }
                }
            }
            pill("Quit", "rectangle.portrait.and.arrow.right", action: onQuit)
        }
        // Keep the pills at their intrinsic width so the labels never truncate to
        // "S…" / "Q…" when the cash line gets tight.
        .fixedSize(horizontal: true, vertical: false)
    }

    private func pill(_ label: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 11, weight: .semibold))
                Text(label).font(.karla(12, .semibold))
            }
            .foregroundStyle(barText)
            .padding(.horizontal, 9).frame(height: 26)
            .background(barBG)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(barBorder, lineWidth: 1))
        }
        .buttonStyle(.plain).pressable()
    }
}
