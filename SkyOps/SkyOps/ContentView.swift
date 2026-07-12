//
//  ContentView.swift
//  SkyOps
//
//  Created by Michael Stevens on 7/12/26.
//
//  Phase 1 shell: the live map plus a minimal HUD. The speed buttons change
//  how often the tick loop fires WITHOUT touching the tick logic itself —
//  the clearest demonstration that the sim clock is decoupled from real time.
//

import SwiftUI

struct ContentView: View {
    @State private var sim = Simulation()

    private let speeds: [Double] = [1, 5, 10, 25]

    var body: some View {
        ZStack(alignment: .top) {
            MapView(sim: sim, tick: sim.tick)

            hud
                .padding(.horizontal, 16)
                .padding(.top, 8)
        }
        .task {
            // Start the async tick loop; it cancels when the view goes away.
            await sim.run()
        }
    }

    private var hud: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("SkyOps")
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                Text("tick \(sim.tick)")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
                if let ac = sim.aircraft.first {
                    Text("\(ac.tail)  \(ac.origin.code)→\(ac.dest.code)  \(phaseLabel(ac.state))")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            HStack(spacing: 6) {
                ForEach(speeds, id: \.self) { s in
                    Button {
                        sim.speed = s
                    } label: {
                        Text(speedLabel(s))
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .frame(minWidth: 34)
                            .padding(.vertical, 5)
                            .background(sim.speed == s ? Color.accentColor.opacity(0.85)
                                                       : Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .foregroundStyle(.white)
    }

    private func speedLabel(_ s: Double) -> String {
        s == s.rounded() ? "\(Int(s))×" : "\(s)×"
    }

    private func phaseLabel(_ state: FlightState) -> String {
        String(describing: state).uppercased()
    }
}

#Preview {
    ContentView()
}
