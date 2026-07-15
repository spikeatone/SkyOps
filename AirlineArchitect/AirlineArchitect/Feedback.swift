//
//  Feedback.swift
//  Airline Architect
//
//  The tactile + audio half of the "surprise and delight" layer. Deliberately
//  restrained: light haptics on the big moments, and ONE short, subtle jet
//  whoosh reserved for the flagship moment (acquiring an aircraft) — no chirps,
//  no chimes, nothing that would "cartoon it up". Sound honors the hardware
//  silent switch and mixes with the user's own audio (AVAudioSession .ambient),
//  so it never intrudes.
//
//  Lives in the VIEW layer (UIKit/AVFoundation) — the Sim layer is deliberately
//  framework-free so it stays headless-testable, so every trigger is a call from
//  a SwiftUI action or an .onChange on observed sim state.
//

import UIKit
import AVFoundation

enum Feedback {

    // MARK: - Raw haptics

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    static func failure() { UINotificationFeedbackGenerator().notificationOccurred(.error) }

    // MARK: - Named big events (one call site each)

    /// Buying / leasing / used-buying an aircraft — the flagship moment:
    /// a success tap + a short, subtle jet whoosh.
    static func aircraftAcquired() {
        success()
        JetSound.shared.play()
    }

    /// Opening a route — a solid medium tap, no sound.
    static func routeOpened() { impact(.medium) }

    /// A milestone celebration (first flight, fleet size, net-worth threshold,
    /// a route recouping) — the heaviest positive tap, no sound.
    static func milestone() { success() }

    /// A new decision needs the player's attention (AOG / crew / sell / offer).
    static func alert() { warning() }

    /// Bankruptcy — game over.
    static func gameOver() { failure() }
}

/// A short, subtle jet whoosh. Self-contained: if a real recording is bundled
/// (`jet` / `jet_takeoff` .caf/.wav/.m4a/.mp3) it's used INSTEAD — a true
/// drop-in upgrade path — otherwise it synthesizes a band-passed-noise whoosh
/// swept high→low with a soft swell, at low gain. Plays under .ambient so the
/// silent switch mutes it and background music keeps playing.
@MainActor
final class JetSound {
    static let shared = JetSound()

    private var player: AVAudioPlayer?
    private var sessionReady = false

    private func prepareSessionOnce() {
        guard !sessionReady else { return }
        sessionReady = true
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, options: [.mixWithOthers])
        try? session.setActive(true)
    }

    private func makePlayer() -> AVAudioPlayer? {
        // Prefer a real bundled recording if the designer supplies one.
        for name in ["jet", "jet_takeoff"] {
            for ext in ["caf", "wav", "m4a", "mp3"] {
                if let url = Bundle.main.url(forResource: name, withExtension: ext),
                   let p = try? AVAudioPlayer(contentsOf: url) {
                    p.prepareToPlay()
                    return p
                }
            }
        }
        // Otherwise synthesize a subtle whoosh once and reuse it.
        guard let data = JetSound.synthesizeWhooshWAV(),
              let p = try? AVAudioPlayer(data: data) else { return nil }
        p.prepareToPlay()
        return p
    }

    func play() {
        prepareSessionOnce()
        if player == nil { player = makePlayer() }
        guard let player else { return }
        player.currentTime = 0
        player.volume = 0.5          // subtle — this stacks under the source gain
        player.play()
    }

    // MARK: - Synthesis (fallback)

    /// A ~1.1s whoosh: white noise through a resonant band-pass whose centre
    /// sweeps 2200→400 Hz (a spooling / passing jet), shaped by a soft rise-then-
    /// fall envelope, encoded to a mono 16-bit WAV in memory.
    static func synthesizeWhooshWAV() -> Data? {
        let sr = 44_100.0
        let dur = 1.1
        let n = Int(sr * dur)
        var samples = [Float](repeating: 0, count: n)

        // Chamberlin state-variable filter state.
        var low = 0.0, band = 0.0
        // Deterministic LCG noise so the sound is identical every run.
        var seed: UInt64 = 0x2545F491_4F6CDD1D

        for i in 0..<n {
            let t = Double(i) / Double(n)                       // 0…1
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            let noise = Double(Int64(bitPattern: seed)) / Double(Int64.max)   // −1…1

            let fc = 2200.0 - 1800.0 * t                        // 2200 → 400 Hz
            let f = 2.0 * sin(Double.pi * min(fc, sr / 3) / sr)
            let q = 0.55                                        // damping (lower = more resonant)
            low += f * band
            let high = noise - low - q * band
            band += f * high

            let env = pow(sin(Double.pi * t), 1.4)              // rise-then-fall swell
            samples[i] = Float(band * env * 0.5)
        }

        // Guard against any resonant overshoot.
        var peak: Float = 0
        for s in samples { peak = max(peak, abs(s)) }
        if peak > 0.9 { let k = 0.9 / peak; for i in 0..<n { samples[i] *= k } }

        return wav16(samples, sampleRate: Int(sr))
    }

    /// Wrap mono float samples (−1…1) in a 16-bit PCM WAV container.
    private static func wav16(_ samples: [Float], sampleRate: Int) -> Data {
        let channels = 1, bits = 16
        let blockAlign = channels * bits / 8
        let byteRate = sampleRate * blockAlign
        let dataSize = samples.count * blockAlign

        func u32(_ v: UInt32) -> [UInt8] { [UInt8(v & 0xff), UInt8((v >> 8) & 0xff), UInt8((v >> 16) & 0xff), UInt8((v >> 24) & 0xff)] }
        func u16(_ v: UInt16) -> [UInt8] { [UInt8(v & 0xff), UInt8((v >> 8) & 0xff)] }

        var data = Data()
        data.append(contentsOf: Array("RIFF".utf8))
        data.append(contentsOf: u32(UInt32(36 + dataSize)))
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8))
        data.append(contentsOf: u32(16))
        data.append(contentsOf: u16(1))                        // PCM
        data.append(contentsOf: u16(UInt16(channels)))
        data.append(contentsOf: u32(UInt32(sampleRate)))
        data.append(contentsOf: u32(UInt32(byteRate)))
        data.append(contentsOf: u16(UInt16(blockAlign)))
        data.append(contentsOf: u16(UInt16(bits)))
        data.append(contentsOf: Array("data".utf8))
        data.append(contentsOf: u32(UInt32(dataSize)))
        for s in samples {
            let v = Int16(max(-1, min(1, s)) * 32767)
            data.append(contentsOf: u16(UInt16(bitPattern: v)))
        }
        return data
    }
}
