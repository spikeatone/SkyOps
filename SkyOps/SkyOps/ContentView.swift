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

    // Gesture accumulators (cumulative values → per-frame deltas).
    @State private var dragLast: CGSize = .zero
    @State private var magLast: CGFloat = 1

    private let speeds: [Double] = [1, 5, 10, 25]
    private let fleetSizes: [Int] = [10, 60, 120, 250]

    var body: some View {
        ZStack(alignment: .top) {
            MapView(sim: sim,
                    tick: sim.tick,
                    cameraZoom: sim.cameraZoom,
                    cameraCenter: sim.cameraCenter)
                .gesture(panGesture.simultaneously(with: zoomGesture))

            hud
                .padding(.horizontal, 16)
                .padding(.top, 8)
        }
        .task {
            // Start the async tick loop; it cancels when the view goes away.
            await sim.run()
        }
    }

    // MARK: - Map gestures

    private var panGesture: some Gesture {
        DragGesture()
            .onChanged { v in
                let delta = CGSize(width: v.translation.width - dragLast.width,
                                   height: v.translation.height - dragLast.height)
                sim.pan(by: delta)
                dragLast = v.translation
            }
            .onEnded { _ in dragLast = .zero }
    }

    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { v in
                let factor = v.magnification / magLast
                sim.zoom(by: factor, anchor: v.startLocation)
                magLast = v.magnification
            }
            .onEnded { _ in magLast = 1 }
    }

    private var hud: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SkyOps")
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                    Text("tick \(sim.tick)  ·  \(sim.fleetCount) aircraft")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                controlRow(speeds, isActive: { sim.speed == $0 }, label: speedLabel) {
                    sim.speed = $0
                }
            }
            HStack {
                Text("FLEET")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                controlRow(fleetSizes, isActive: { sim.fleetCount == $0 }, label: { "\($0)" }) {
                    sim.setFleetSize($0)
                }
                Spacer()
                Button { sim.resetCamera() } label: {
                    Text("RESET VIEW")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .padding(.vertical, 5).padding(.horizontal, 8)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
        .foregroundStyle(.white)
    }

    /// A row of pill buttons for a set of values.
    private func controlRow<T: Hashable>(_ values: [T],
                                         isActive: @escaping (T) -> Bool,
                                         label: @escaping (T) -> String,
                                         action: @escaping (T) -> Void) -> some View {
        HStack(spacing: 6) {
            ForEach(values, id: \.self) { v in
                Button { action(v) } label: {
                    Text(label(v))
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .frame(minWidth: 34)
                        .padding(.vertical, 5)
                        .padding(.horizontal, 2)
                        .background(isActive(v) ? Color.accentColor.opacity(0.85)
                                                : Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func speedLabel(_ s: Double) -> String {
        s == s.rounded() ? "\(Int(s))×" : "\(s)×"
    }
}

#Preview {
    ContentView()
}
