//
//  NewLiveryPromptView.swift
//  Airline Architect — the ONE-TIME "your fleet can wear your own colors now"
//  card an EXISTING player sees the first time they continue a save after
//  updating to the livery release.
//
//  Why it exists: a save made before the livery feature restores with the DEFAULT
//  indices, so that player's fleet is already painted in a livery they never
//  picked, and nothing on screen tells them they can change it. The Fleet header
//  button reads "Add Livery" with a dot, but a returning player has no reason to
//  look there. This says it once, on the tab they're already on.
//
//  Deliberately NOT a blocking modal on the load menu or a forced flow: it appears
//  over the game they just resumed, both buttons dismiss it, and it never returns
//  (`LiveryPromptState.seen`). Interrupting someone's saved game on update is the
//  thing to avoid — this is a nudge with a clear way out.
//

import SwiftUI

/// One-time flag for the update prompt. Separate from `TutorialState` because it
/// targets EXISTING players specifically — a new airline never sees it (they pick
/// a livery during creation, so `liveryChosen` is already true).
enum LiveryPromptState {
    private static let key = "hasSeenLiveryPrompt_v1"
    static var seen: Bool {
        get { UserDefaults.standard.bool(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}

struct NewLiveryPromptView: View {
    var airlineName: String
    var onDesign: () -> Void
    var onLater: () -> Void

    @Environment(\.colorScheme) private var scheme
    private var isDark: Bool { scheme == .dark }
    private var cardBG: Color     { isDark ? Sky.navBarDark : .white }
    private var cardBorder: Color { isDark ? Sky.onDarkStroke.opacity(0.6) : Color(skyHex: 0xE6E6E6) }
    private var titleColor: Color { isDark ? Sky.lightBlue : Color(skyHex: 0x4E67A0) }
    private var bodyColor: Color  { isDark ? .white : Color(skyHex: 0x1C2028) }
    private var secondary: Color  { isDark ? Sky.lightBlue.opacity(0.75) : Color(skyHex: 0x64748B) }

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
                .onTapGesture(perform: onLater)

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "paintbrush.fill")
                        .font(.system(size: 15, weight: .semibold)).foregroundStyle(titleColor)
                    Text("PAINT YOUR FLEET")
                        .font(.karla(20, .bold)).foregroundStyle(titleColor)
                }
                .padding(.bottom, 8)

                Text("\(airlineName) can now fly in colors you choose — a palette, a tail emblem, and your name on the fuselage.")
                    .font(.karla(14)).foregroundStyle(bodyColor)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 10)

                Text("Your first livery is free. After that, changing it means repainting the fleet — real money, and aircraft out of service while they're in the shop.")
                    .font(.karla(13)).foregroundStyle(secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 18)

                HStack(spacing: 10) {
                    Button(action: onLater) {
                        Text("Later")
                            .font(.karla(15, .semibold)).foregroundStyle(titleColor)
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(cardBorder, lineWidth: 1))
                    }
                    Button(action: onDesign) {
                        Text("Design it")
                            .font(.karla(15, .bold)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 4).fill(Sky.brightBlue))
                    }
                }
            }
            .padding(18)
            .background(RoundedRectangle(cornerRadius: 4).fill(cardBG))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(cardBorder, lineWidth: 1))
            .padding(.horizontal, 24)
        }
    }
}
