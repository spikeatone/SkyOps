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
    /// a success tap + a short jet whoosh. On the FIRST-EVER purchase the whoosh
    /// is skipped so it doesn't collide with the "First jet purchased!" milestone
    /// chime (which plays on the next tick); the chime is that moment's sound.
    static func aircraftAcquired(isFirst: Bool = false) {
        success()
        if !isFirst { JetSound.shared.play() }
    }

    /// Hiring a new crew — a success tap + the "new crew" clip.
    static func crewHired() {
        success()
        NewCrewSound.shared.play()
    }

    /// Opening a route — a solid medium tap plus a gate-style "now boarding"
    /// call. `announce: false` skips the voice call when it would collide with the
    /// jet whoosh (i.e. the route was opened by buying an aircraft in one action).
    static func routeOpened(airline: String?, announce: Bool = true) {
        impact(.medium)
        if announce { GateAnnouncement.shared.nowBoarding(airline: airline) }
    }

    /// A milestone celebration (first flight, fleet size, net-worth threshold,
    /// a route recouping) — a success tap plus the congrats chime, timed with the
    /// badge toast that slides in.
    static func milestone() {
        success()
        MilestoneSound.shared.play()
    }

    /// A new decision needs the player's attention (AOG / crew / sell / offer).
    static func alert() { warning() }

    /// Bankruptcy — game over.
    static func gameOver() { failure() }
}

/// Shared audio session for every game sound. `.playback` + `.mixWithOthers`
/// means the cues are AUDIBLE even when the phone's ring/silent switch is set to
/// silent (a game the player deliberately opened should still make its sounds),
/// while still mixing under — never interrupting — the player's own music.
///
/// NOTE: this was `.ambient` originally, which is muted by the hardware silent
/// switch — the reason on-device testing heard nothing while haptics worked
/// (the test device was on silent). `.playback` is the right category for
/// game SFX the player wants to hear.
@MainActor
enum GameAudio {
    private static var ready = false
    static func prepareAmbientSessionOnce() {
        guard !ready else { return }
        ready = true
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, options: [.mixWithOthers])
        try? session.setActive(true)
    }
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
        GameAudio.prepareAmbientSessionOnce()
        if player == nil { player = makePlayer() }
        guard let player else { return }
        player.currentTime = 0
        player.volume = 0.85         // audible-but-subtle; the synth gain is already low
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

/// A gate-style "now boarding" call, played on opening a route — a deliberate,
/// infrequent action, so it's a flavor nod rather than a nag. Plays the bundled
/// recording (`now_boarding.*`) if present; otherwise falls back to on-device TTS
/// in the player's own airline name. Plays under the shared game audio session.
@MainActor
final class GateAnnouncement {
    static let shared = GateAnnouncement()
    private let synth = AVSpeechSynthesizer()
    private var player: AVAudioPlayer?
    private var lookedUp = false

    /// The bundled recording, loaded once (nil if none is bundled → TTS fallback).
    private func recording() -> AVAudioPlayer? {
        if !lookedUp {
            lookedUp = true
            for ext in ["wav", "caf", "m4a", "mp3"] {
                if let url = Bundle.main.url(forResource: "now_boarding", withExtension: ext),
                   let p = try? AVAudioPlayer(contentsOf: url) {
                    p.prepareToPlay(); player = p; break
                }
            }
        }
        return player
    }

    func nowBoarding(airline: String?) {
        GameAudio.prepareAmbientSessionOnce()

        // Prefer the recorded PA clip.
        if let p = recording() {
            p.currentTime = 0
            p.volume = 0.9
            p.play()
            return
        }

        // Fallback: synthesize the call in the player's airline name.
        let name = (airline?.trimmingCharacters(in: .whitespaces)).flatMap { $0.isEmpty ? nil : $0 }
        let u = AVSpeechUtterance(string: name.map { "\($0), now boarding." } ?? "Now boarding.")
        u.rate = AVSpeechUtteranceDefaultSpeechRate * 0.94
        u.pitchMultiplier = 0.98
        u.volume = 0.9
        u.voice = AVSpeechSynthesisVoice(language: "en-US")
        u.preUtteranceDelay = 0.05
        synth.stopSpeaking(at: .immediate)
        synth.speak(u)
    }
}

/// A one-shot bundled sound clip, loaded once and reused. Backs the milestone
/// chime and the new-crew clip; no-op if the file isn't bundled.
@MainActor
final class ClipSound {
    private let resource: String
    private let volume: Float
    private var player: AVAudioPlayer?
    private var lookedUp = false

    init(_ resource: String, volume: Float = 0.9) { self.resource = resource; self.volume = volume }

    private func clip() -> AVAudioPlayer? {
        if !lookedUp {
            lookedUp = true
            for ext in ["wav", "caf", "m4a", "mp3"] {
                if let url = Bundle.main.url(forResource: resource, withExtension: ext),
                   let p = try? AVAudioPlayer(contentsOf: url) {
                    p.prepareToPlay(); player = p; break
                }
            }
        }
        return player
    }

    func play() {
        GameAudio.prepareAmbientSessionOnce()
        guard let p = clip() else { return }
        p.currentTime = 0
        p.volume = volume
        p.play()
    }
}

/// The milestone "congrats" chime, played alongside the badge toast.
@MainActor enum MilestoneSound { static let shared = ClipSound("milestone") }
/// The "new crew hired" clip.
@MainActor enum NewCrewSound { static let shared = ClipSound("new_crew") }
