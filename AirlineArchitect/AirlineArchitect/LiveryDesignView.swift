//
//  LiveryDesignView.swift
//  Airline Architect — the livery design screen. Shown right after the player
//  names their airline (before the game starts): pick a title font, a 2-colour
//  palette, and a tail emblem, with a live preview on the 737 MAX 9. "Launch
//  Airline" commits the selection and starts the game.
//
//  Theme-aware, built from the same tokens/typography as the naming screen.
//

import SwiftUI

struct LiveryDesignView: View {
    /// The airline name the player just entered (the fuselage text defaults to it).
    let airlineName: String
    /// Opacity for the shared brand backdrop behind the screen (nil = off).
    var backdropOpacity: Double? = nil
    /// Called with the chosen font / palette / tail-emblem indices + the fuselage
    /// text on Launch.
    let onLaunch: (Int, Int, Int, String) -> Void

    @Environment(\.colorScheme) private var scheme
    private var isDark: Bool { scheme == .dark }

    @State private var fontIndex = 0
    @State private var paletteIndex = 0
    @State private var tailIndex = 1        // 1-based; 0 = none
    /// What's painted on the fuselage — seeded from the airline name, capped, editable.
    @State private var fuselageText = ""
    @FocusState private var textFocused: Bool

    /// The reference aircraft for the preview (designer's call).
    private let previewType = "MAX9"

    private var livery: Livery {
        Livery(fontIndex: fontIndex, paletteIndex: paletteIndex, tailArtIndex: tailIndex)
    }

    // Tokens (match AirlineNamingView)
    private func hex(_ h: UInt) -> Color { Color(hex: h) }
    private var background: Color { isDark ? hex(0x2B303D) : .white }
    private var titleColor: Color { isDark ? .white : hex(0x4E67A0) }
    private var subtitleColor: Color { isDark ? hex(0xBDE0FF) : hex(0x5B98CE) }
    private var labelColor: Color { isDark ? hex(0xBDE0FF) : hex(0x64748B) }
    private var buttonBG: Color { isDark ? hex(0xBDE0FF) : hex(0x497AA5) }
    private var buttonText: Color { isDark ? hex(0x4E67A0) : .white }
    private var cardBG: Color { isDark ? hex(0x353B49) : hex(0xF4F6F9) }
    private var cardStroke: Color { isDark ? Sky.onDarkStroke.opacity(0.6) : hex(0xE2E8F0) }
    private var selRing: Color { isDark ? hex(0xBDE0FF) : hex(0x497AA5) }

    var body: some View {
        ZStack {
            background.ignoresSafeArea()
            if let o = backdropOpacity { ArchitectBackdrop(opacity: o) }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    header

                    // Live preview — the MAX 9 wearing the current selection, on a
                    // soft sky panel so light liveries still read on the white theme.
                    previewPanel

                    textSection
                    fontSection
                    paletteSection
                    tailSection

                    launchButton
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 8)
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
            }
            .safeAreaPadding(.top, 70)   // clear the status bar / notch — header sits below the clock
        }
        .onAppear {
            // Seed the fuselage text from the airline name (trimmed to the cap) the
            // first time in — the player can then shorten/edit it.
            if fuselageText.isEmpty {
                fuselageText = String(airlineName.trimmingCharacters(in: .whitespaces).prefix(Livery.maxTextLength))
            }
        }
        .animation(.easeInOut(duration: 0.22), value: paletteIndex)
        .animation(.easeInOut(duration: 0.22), value: fontIndex)
        .animation(.easeInOut(duration: 0.22), value: tailIndex)
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 2) {
            Text("Design your livery")
                .font(.karla(22, .bold))
                .foregroundStyle(titleColor)
            Text("Paint \(airlineName.isEmpty ? "your airline" : airlineName) onto the fleet.")
                .font(.karla(15))
                .foregroundStyle(subtitleColor)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: Preview

    private var previewPanel: some View {
        // A gentle sky gradient behind the jet — dark navy on dark, pale blue on
        // light — so a light-coloured livery never disappears against the page.
        let g: [Color] = isDark ? [hex(0x1B2233), hex(0x11172A)] : [hex(0xEAF3FB), hex(0xF7FBFF)]
        return AircraftLiveryImage(typeID: previewType, name: previewText, livery: livery)
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(LinearGradient(colors: g, startPoint: .top, endPoint: .bottom))
            )
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(cardStroke, lineWidth: 1))
    }

    // MARK: Fuselage text

    private var textSection: some View {
        section("FUSELAGE TEXT") {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    TextField("Text on your planes", text: $fuselageText)
                        .font(.karla(16))
                        .foregroundStyle(isDark ? .white : hex(0x1E293B))
                        .tint(hex(0x0EA5E9))
                        .focused($textFocused)
                        .autocorrectionDisabled()
                        .onChange(of: fuselageText) { _, v in
                            if v.count > Livery.maxTextLength { fuselageText = String(v.prefix(Livery.maxTextLength)) }
                        }
                    Text("\(fuselageText.count)/\(Livery.maxTextLength)")
                        .font(.karla(12))
                        .foregroundStyle(fuselageText.count >= Livery.maxTextLength ? selRing : labelColor)
                }
                .padding(.horizontal, 14).frame(height: 44)
                .background(RoundedRectangle(cornerRadius: 8).fill(isDark ? hex(0x353B49) : .white))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(cardStroke, lineWidth: 1))

                Text("What's painted on the fuselage — usually a short form of your name.")
                    .font(.karla(12))
                    .foregroundStyle(subtitleColor.opacity(0.85))
            }
        }
    }

    // MARK: Font

    private var fontSection: some View {
        section("TITLE FONT") {
            // Horizontal chips, each rendering the airline name in that face.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(LiveryFont.all) { f in
                        let sel = f.id == fontIndex
                        Button { fontIndex = f.id } label: {
                            Text(sampleName)
                                .font(f.font(19))
                                .lineLimit(1)
                                .foregroundStyle(sel ? selRing : titleColor)
                                .padding(.horizontal, 16)
                                .frame(minWidth: 96)
                                .frame(height: 52)   // uniform chip height across fonts
                                .background(RoundedRectangle(cornerRadius: 10).fill(cardBG))
                                .overlay(RoundedRectangle(cornerRadius: 10)
                                    .stroke(sel ? selRing : cardStroke, lineWidth: sel ? 2 : 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2).padding(.vertical, 2)
            }
        }
    }

    /// What the preview paints — the fuselage text, or a stand-in if it's empty.
    private var previewText: String {
        let t = fuselageText.trimmingCharacters(in: .whitespaces)
        return t.isEmpty ? "Airline" : t
    }

    /// Keep the font chips readable: a short stand-in for a long/empty title.
    private var sampleName: String {
        let n = previewText
        return n.count > 12 ? String(n.prefix(11)) + "…" : n
    }

    // MARK: Palette

    private var paletteSection: some View {
        section("COLOR PALETTE") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
                ForEach(LiveryPalette.all) { p in
                    let sel = p.id == paletteIndex
                    Button { paletteIndex = p.id } label: {
                        VStack(spacing: 6) {
                            // Two-tone swatch: colour 1 (titles) over colour 2 (tail).
                            ZStack {
                                RoundedRectangle(cornerRadius: 8).fill(p.secondary)
                                RoundedRectangle(cornerRadius: 8).fill(p.primary)
                                    .padding(.trailing, 22)   // reveal the accent as a wedge
                            }
                            .frame(height: 40)
                            .overlay(RoundedRectangle(cornerRadius: 8)
                                .stroke(sel ? selRing : cardStroke, lineWidth: sel ? 2.5 : 1))
                            Text(p.name)
                                .font(.karla(11, sel ? .bold : .regular))
                                .foregroundStyle(sel ? selRing : labelColor)
                                .lineLimit(1).minimumScaleFactor(0.7)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Tail emblem

    private var tailSection: some View {
        section("TAIL EMBLEM") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
                ForEach(1...TailArt.count, id: \.self) { n in
                    let sel = n == tailIndex
                    Button { tailIndex = n } label: {
                        Group {
                            if let ui = TailArt.uiImage(n) {
                                Image(uiImage: ui)
                                    .renderingMode(.template).resizable().scaledToFit()
                                    .foregroundStyle(sel ? LiveryPalette.at(paletteIndex).secondary : (isDark ? .white : hex(0x334155)))
                                    .padding(4)
                            } else { Color.clear }
                        }
                        .frame(height: 62)
                        .frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: 10).fill(cardBG))
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .stroke(sel ? selRing : cardStroke, lineWidth: sel ? 2 : 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Launch

    private var launchButton: some View {
        Button {
            onLaunch(fontIndex, paletteIndex, tailIndex, fuselageText)
        } label: {
            Text("Launch Airline")
                .font(.karla(17, .medium))
                .foregroundStyle(buttonText)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(buttonBG)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }

    // MARK: Section chrome

    @ViewBuilder private func section<V: View>(_ title: String, @ViewBuilder _ content: () -> V) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.karla(12, .semibold))
                .foregroundStyle(labelColor)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#if DEBUG
/// DEBUG (-liveryGallery): EMBLEM FIT TEST — all 10 emblems on the same aircraft
/// (MAX9 by default; `-galleryType <ID>` to change) so we can nail the fin fit in
/// the REAL SwiftUI renderer. Then a per-airframe spread across fin shapes.
struct LiveryGalleryView: View {
    private func arg(_ flag: String) -> String? {
        if let i = CommandLine.arguments.firstIndex(of: flag), i + 1 < CommandLine.arguments.count {
            return CommandLine.arguments[i+1]
        }
        return nil
    }
    var previewType: String { arg("-galleryType") ?? "MAX9" }
    var name: String { arg("-galleryName") ?? "ASTER AIR" }
    var palette: Int { Int(arg("-galleryPalette") ?? "0") ?? 0 }
    // A spread of fin shapes: swept, T-tail, turboprop, widebody.
    let spread = ["A320","A380","B773","CRJ900","ERJ145","DH8B","AT46","E190"]
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text("ALL 10 EMBLEMS · \(name) · \(LiveryPalette.at(palette).name)")
                    .font(.system(size: 12, weight: .heavy)).frame(maxWidth: .infinity, alignment: .leading)
                ForEach(1...TailArt.count, id: \.self) { n in
                    HStack(spacing: 4) {
                        Text("\(n)").font(.system(size: 11, weight: .bold)).frame(width: 18)
                        AircraftLiveryImage(typeID: previewType, name: name,
                                            livery: Livery(fontIndex: 1, paletteIndex: palette, tailArtIndex: n))
                    }
                }
                Divider().padding(.vertical, 4)
                Text("WING EMBLEM ACROSS FIN SHAPES")
                    .font(.system(size: 12, weight: .heavy)).frame(maxWidth: .infinity, alignment: .leading)
                ForEach(spread, id: \.self) { id in
                    VStack(spacing: 0) {
                        Text(id).font(.system(size: 10, weight: .bold)).frame(maxWidth: .infinity, alignment: .leading)
                        AircraftLiveryImage(typeID: id, name: name,
                                            livery: Livery(fontIndex: 1, paletteIndex: palette, tailArtIndex: 1))
                    }
                }
            }
            .padding(8)
        }
        .background(Color(white: 0.93))
    }
}
#endif
