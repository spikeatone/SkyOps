//
//  AirlineNamingView.swift
//  SkyOps — first-launch "name your airline" screen
//
//  Built to the designer's Figma (SkyOps-Production, home-light 1:2 /
//  home-dark 1:456), theme-aware. Colours/sizes/spacing ported from the Figma
//  tokens. Fonts: the design uses Karla + Geist (not on iOS); approximated
//  with the system font at the same weights/sizes for now — bundle the real
//  families for pixel-exact type.
//

import SwiftUI

struct AirlineNamingView: View {
    /// Called with the entered name when the player launches their airline.
    let onLaunch: (String) -> Void

    @Environment(\.colorScheme) private var scheme
    @State private var name = ""
    @FocusState private var fieldFocused: Bool

    private var isDark: Bool { scheme == .dark }

    // Figma tokens
    private func hex(_ h: UInt) -> Color {
        Color(red: Double((h >> 16) & 0xFF) / 255, green: Double((h >> 8) & 0xFF) / 255, blue: Double(h & 0xFF) / 255)
    }
    private var background: Color { isDark ? hex(0x2B303D) : .white }
    private var badgeGradient: [Color] { isDark ? [hex(0x4E67A1), hex(0x0C1A42)] : [hex(0x40588F), hex(0x101937)] }
    private var welcomeColor: Color { isDark ? .white : hex(0x4E67A0) }
    private var subtitleColor: Color { isDark ? hex(0xBDE0FF) : hex(0x5B98CE) }
    private var labelColor: Color { isDark ? hex(0xBDE0FF) : hex(0x64748B) }
    private var buttonBG: Color { isDark ? hex(0xBDE0FF) : hex(0x497AA5) }
    private var buttonText: Color { isDark ? hex(0x4E67A0) : .white }

    var body: some View {
        ZStack {
            background.ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer().frame(height: 8)

                // Logo badge — gradient circle with the winged mark + wordmark.
                ZStack {
                    Circle().fill(LinearGradient(colors: badgeGradient, startPoint: .top, endPoint: .bottom))
                    VStack(spacing: 8) {
                        SkyOpsLogo().frame(width: 126, height: 102)
                        Text("SkyOps")
                            .font(.system(size: 25, weight: .light))
                            .foregroundStyle(.white)
                    }
                    .padding(.top, 8)
                }
                .frame(width: 200, height: 200)

                // Welcome copy.
                VStack(spacing: 4) {
                    Text("Welcome, COO!")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(welcomeColor)
                    Text("The sky is the limit.\nWhat shall we call your global airline empire?")
                        .font(.system(size: 16))
                        .foregroundStyle(subtitleColor)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .frame(width: 360)
                }

                // Airline name field.
                VStack(alignment: .leading, spacing: 8) {
                    Text("AIRLINE NAME")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(labelColor)
                    TextField("", text: $name, prompt: Text("SkyOps Air").foregroundColor(hex(0x64748B)))
                        .font(.system(size: 16))
                        .foregroundStyle(hex(0x1E293B))
                        .tint(hex(0x0EA5E9))          // cyan caret, matching the design
                        .focused($fieldFocused)
                        .submitLabel(.go)
                        .onSubmit(launch)
                        .frame(height: 56)
                        .padding(.horizontal, 16)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(hex(0xE2E8F0), lineWidth: 1))
                }
                .frame(width: 360)

                // Launch button.
                Button(action: launch) {
                    Text("Launch Your Airline")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(buttonText)
                        .frame(height: 48)
                        .padding(.horizontal, 24)
                        .background(buttonBG)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.top, 8)
        }
        .onAppear { fieldFocused = true }
    }

    private func launch() { onLaunch(name) }
}
