import Foundation
#if canImport(MetricKit)
import MetricKit
#endif

// Crash + hang reporting via Apple's MetricKit. The family had NONE (2026-08-24 audit found it in
// 1 of 10 apps); Airline — a shipped app — was blind to its own crash/hang rate. Ported from
// Flight Ops Architect's CrashReporter (the family reference).
//
// WHY: TelemetryDeck ships NO crash capture (no uncaught-exception/signal handler). MetricKit is
// the zero-dependency Apple way to SEE crashes without embedding a third-party crash SDK. It is
// NOT real-time: the OS collects diagnostics after a crash and delivers them to the subscriber on
// a LATER launch (often the next one, sometimes batched up to ~24h). So this is "how often / what
// kind", not a live alert — which is exactly the visibility we want, and it stays privacy-first.
//
// PRIVACY (the same rule as Telemetry): we report the crash's TYPE only — a stable slug from the
// exception/signal/termination codes — and NEVER the call stack, binary images, addresses, or any
// symbol. Those can carry paths and are exactly what we don't collect. Every report routes through
// `Telemetry.errorOccurred`, so a driven session (which never configures Telemetry) reports
// nothing, and a real crash lands in the Errors dashboard bucketed by kind next to handled errors.
//
// View layer only (the Sim/ seam): MetricKit is a framework; `Sim/` stays framework-free. Subscribe
// once from the App's `init()`, after `Telemetry.configure()`.

enum CrashReporter {

    #if canImport(MetricKit)
    /// The retained subscriber — MXMetricManager holds it weakly, so it must live for the app's
    /// lifetime. A single shared instance does that.
    private static let subscriber = Subscriber()
    #endif

    /// Begin receiving MetricKit diagnostics. Call once from `AirlineArchitectApp.init()`, AFTER
    /// `Telemetry.configure()` (a report is a no-op until Telemetry is configured, so order matters
    /// only in that the config should already have run this launch).
    static func start() {
        #if canImport(MetricKit)
        // A driven session never configures Telemetry, so reports would no-op anyway — but skip
        // subscribing at all so a verification run does nothing observable.
        guard !Telemetry.isDriven() else { return }
        MXMetricManager.shared.add(subscriber)
        #endif
    }

    #if canImport(MetricKit)
    /// Receives the OS's batched diagnostic payloads (delivered on a launch AFTER the event).
    private final class Subscriber: NSObject, MXMetricManagerSubscriber {
        // We only care about diagnostics (crashes/hangs), not the daily metric payloads.
        func didReceive(_ payloads: [MXMetricPayload]) { /* metrics unused */ }

        @available(iOS 14.0, *)
        func didReceive(_ payloads: [MXDiagnosticPayload]) {
            for payload in payloads {
                for crash in payload.crashDiagnostics ?? [] { report(crash) }
                for hang in payload.hangDiagnostics ?? [] { report(hang) }
            }
        }

        // MARK: Crashes → Telemetry.errorOccurred, TYPE ONLY

        @available(iOS 14.0, *)
        private func report(_ crash: MXCrashDiagnostic) {
            // A stable slug from the numeric codes — never the call stack. Any of these may be nil
            // depending on how the process died; compose what's present.
            var parts: [String] = []
            if let sig = crash.signal?.intValue { parts.append("sig\(sig)") }
            if let type = crash.exceptionType?.intValue { parts.append("exc\(type)") }
            if let code = crash.exceptionCode?.intValue { parts.append("code\(code)") }
            if let reason = crash.terminationReason, !reason.isEmpty {
                // terminationReason is an OS-authored string (e.g. a watchdog message). It can be
                // long; keep only a short, slugged head so grouping stays stable and no stray
                // detail rides along.
                parts.append(slug(reason))
            }
            let id = "crash." + (parts.isEmpty ? "unknown" : parts.joined(separator: "."))
            // The OS version this crash happened on is useful triage and carries nothing personal —
            // MetricKit already scopes it to the app.
            let os = crash.metaData.osVersion
            Telemetry.errorOccurred(id, category: .thrown, detail: os)
        }

        @available(iOS 14.0, *)
        private func report(_ hang: MXHangDiagnostic) {
            // A main-thread hang the OS deemed report-worthy. Bucket by coarse duration so a 2s
            // stutter and a 20s freeze don't collapse into one number.
            let ms = hang.hangDuration.converted(to: .milliseconds).value
            let bucket: String
            switch ms {
            case ..<3000:  bucket = "under3s"
            case ..<10000: bucket = "3to10s"
            default:       bucket = "over10s"
            }
            Telemetry.errorOccurred("hang.\(bucket)", category: .appState,
                                    detail: hang.metaData.osVersion)
        }

        /// A short, safe slug of an OS-authored reason string: lowercase, alnum-and-dots, first few
        /// tokens only. Defensive — MetricKit's strings are OS text, not player text, but we still
        /// keep it terse and stable for grouping.
        private func slug(_ s: String) -> String {
            let allowed = CharacterSet.alphanumerics
            var out = String.UnicodeScalarView()
            for sc in s.lowercased().unicodeScalars {
                out.append(allowed.contains(sc) ? sc : " ")
            }
            let tokens = String(out).split(separator: " ").prefix(3)
            return tokens.joined(separator: "-")
        }
    }
    #endif
}
