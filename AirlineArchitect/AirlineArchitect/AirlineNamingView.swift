//
//  AirlineNamingView.swift
//  Airline Architect — first-launch "name your airline" screen
//
//  Built to the designer's Figma (SkyOps-Production, home-light 1:2 /
//  home-dark 1:456), theme-aware. Colours/sizes/spacing ported from the Figma
//  tokens. Uses the bundled Karla family (see Typography). The winged-plane
//  badge mark is unchanged; the wordmark is the two-line "Airline Architect".
//

import SwiftUI

struct AirlineNamingView: View {
    /// Called with the entered airline name, 2-letter fleet tail code, and the
    /// chosen home region when the player launches their airline.
    let onLaunch: (String, String, Airline.PlayerRegion) -> Void

    @Environment(\.colorScheme) private var scheme
    @State private var name = ""
    @State private var tailCode = ""
    @State private var region: Airline.PlayerRegion = .northAmerica
    @FocusState private var fieldFocused: Bool
    @FocusState private var tailFocused: Bool
    /// Drives the blinking prompt cursor shown in the empty, unfocused field.
    @State private var cursorOn = true

    private var isDark: Bool { scheme == .dark }

    // MARK: Tail-code validation
    /// The typed code is invalid to launch with when it's a partial entry or
    /// collides with a real airline. Blank is allowed (a safe default is used).
    private var tailInvalid: Bool {
        let c = tailCode.uppercased()
        if c.isEmpty { return false }
        if c.count != 2 { return true }
        return Airline.realCodes[c] != nil
    }
    private var tailHint: String {
        let c = tailCode.uppercased()
        if let owner = Airline.realCodes[c] { return "\(c) belongs to \(owner) — choose another." }
        if c.count == 1 { return "Enter two letters." }
        return "Two letters, painted on every aircraft in your fleet. Can't match a real airline (UA, DL…)."
    }
    private var errorRed: Color { isDark ? hex(0xFF9292) : hex(0xD70000) }

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
            // Scrolls on smaller iPhones now that the region picker adds height.
            ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                Spacer().frame(height: 8)

                // Logo badge — gradient circle with the winged mark + wordmark.
                ZStack {
                    Circle().fill(LinearGradient(colors: badgeGradient, startPoint: .top, endPoint: .bottom))
                    VStack(spacing: 8) {
                        AppLogo().frame(width: 117, height: 95)
                        // Two-line wordmark. Figma is Karla Light 25 with a
                        // 20pt line-height; Karla's natural height at 25 is
                        // ~29.2, so a −9 pitch tightens it to match.
                        VStack(spacing: -9) {
                            Text("Airline")
                            Text("Architect")
                        }
                        .font(.karla(25, .light))
                        .foregroundStyle(.white)
                    }
                    .padding(.top, 8)
                }
                .frame(width: 200, height: 200)

                // Welcome copy.
                VStack(spacing: 4) {
                    Text("Welcome, COO!")
                        .font(.karla(28, .bold))
                        .foregroundStyle(welcomeColor)
                    Text("The sky is the limit.\nWhat shall we call your global airline empire?")
                        .font(.karla(18))
                        .foregroundStyle(subtitleColor)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .frame(width: 386)
                }

                // Airline name field — no placeholder (self-explanatory); a
                // blinking cyan cursor prompts typing before the field is tapped.
                VStack(alignment: .leading, spacing: 8) {
                    Text("AIRLINE NAME")
                        .font(.karla(12, .semibold))
                        .foregroundStyle(labelColor)
                    ZStack(alignment: .leading) {
                        TextField("", text: $name)
                            .font(.karla(16))
                            .foregroundStyle(hex(0x1E293B))
                            .tint(hex(0x0EA5E9))          // cyan caret once focused
                            .focused($fieldFocused)
                            .submitLabel(.go)
                            .onSubmit(launch)
                        if name.isEmpty && !fieldFocused {
                            Rectangle().fill(hex(0x0EA5E9))
                                .frame(width: 2, height: 24)
                                .opacity(cursorOn ? 1 : 0)
                        }
                    }
                    .frame(height: 56)
                    .padding(.horizontal, 16)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(hex(0xE2E8F0), lineWidth: 1))
                }
                .frame(width: 360)

                // Fleet tail code — 2 letters, uppercased, letters only. Live
                // validation blocks real airline codes.
                VStack(alignment: .leading, spacing: 8) {
                    Text("FLEET TAIL CODE")
                        .font(.karla(12, .semibold))
                        .foregroundStyle(labelColor)
                    ZStack(alignment: .leading) {
                        TextField("", text: $tailCode)
                            .font(.karla(16))
                            .foregroundStyle(hex(0x1E293B))
                            .tint(hex(0x0EA5E9))
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .focused($tailFocused)
                            .submitLabel(.go)
                            .onSubmit(launch)
                            .onChange(of: tailCode) { _, v in
                                let cleaned = String(v.uppercased().filter { $0.isLetter }.prefix(2))
                                if cleaned != tailCode { tailCode = cleaned }
                            }
                        if tailCode.isEmpty && !tailFocused {
                            Text("e.g. ZQ").font(.karla(16)).foregroundStyle(hex(0x94A3B8))
                        }
                    }
                    .frame(height: 56)
                    .padding(.horizontal, 16)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4)
                        .stroke(tailInvalid ? errorRed : hex(0xE2E8F0), lineWidth: 1))
                    Text(tailHint)
                        .font(.karla(12))
                        .foregroundStyle(tailInvalid ? errorRed : subtitleColor.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(width: 360)

                // Home region — the designer's seven start choices (the map
                // frames here on launch; the player can still fly anywhere).
                // A snapping card carousel: neighbors peek at the margins so it
                // reads as swipeable; each card wears its region's map hue.
                VStack(alignment: .center, spacing: 8) {
                    Text("CHOOSE YOUR FOUNDING REGION")
                        .font(.karla(12, .semibold))
                        .foregroundStyle(labelColor)
                        .frame(width: 360, alignment: .leading)
                    RegionCarousel(region: $region)
                        .frame(maxWidth: 560)
                    Text("Your starting map focuses here — you can still fly anywhere.")
                        .font(.karla(12))
                        .foregroundStyle(subtitleColor.opacity(0.85))
                        .frame(width: 360, alignment: .leading)
                }

                // Launch button.
                Button(action: launch) {
                    Text("Launch Your Airline")
                        .font(.karla(16, .medium))
                        .foregroundStyle(buttonText)
                        .frame(height: 48)
                        .padding(.horizontal, 24)
                        .background(buttonBG)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .opacity(tailInvalid ? 0.4 : 1)
                }
                .buttonStyle(.plain)
                .disabled(tailInvalid)

                Spacer().frame(height: 24)
            }
            .padding(.top, 8)
            .frame(maxWidth: .infinity)
            }
        }
        .onAppear {
            // Blink the prompt cursor; don't auto-focus (keeps the keyboard
            // down until the player taps, matching the design).
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                cursorOn = false
            }
        }
    }

    private func launch() {
        guard !tailInvalid else { return }
        onLaunch(name, tailCode, region)
    }
}
