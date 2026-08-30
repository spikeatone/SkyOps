//
//  Localization.swift  (Sim/ layer)
//  Airline Architect — a FRAMEWORK-FREE localization shim for the Sim layer.
//
//  WHY THIS EXISTS (and why it's not just SwiftUI's String Catalog):
//  The Sim/ layer builds user-facing strings — Ops-log messages, decision-card
//  copy, offer pitches, route-closure lines (e.g. logOps(.structural,
//  "Hub established at \(code)", …)). But Sim/ MUST stay framework-free: the
//  headless harnesses compile it with plain `swiftc`, with no SwiftUI and no
//  Foundation-localization. SwiftUI's `LocalizedStringKey` / `String(localized:)`
//  and the `.xcstrings` catalog are UI-framework-bound, so the Sim strings can't
//  use them without breaking the harness. This shim is the answer: a tiny pure-
//  Swift lookup (a `[String: [String: String]]` table) that the harness compiles
//  as trivially as any dictionary.
//
//  HOW IT'S USED:
//  Wrap a Sim-layer user-facing literal in `L(...)`:
//      logOps(.structural, L("Hub established at %@", code), …)
//  `%@` placeholders are substituted positionally from the varargs, so word
//  ORDER can differ per language (German is verb-final) — the table stores a
//  format string per language and `L` fills it. English is the source: an
//  untranslated key returns its own English text, so the app is byte-identical
//  in English until a `de` (or any other) table is filled in.
//
//  STATE: INFRASTRUCTURE ONLY. `tables` is empty (English passthrough), so this
//  changes NOTHING user-visible today. Filling a language table (e.g. "de") is
//  the translation step, gated on timing per LOCALIZATION_SCOPING.md — NOT part
//  of this infra commit.
//
//  The VIEW layer does NOT use this — SwiftUI `Text("…")` localizes for free via
//  the `.xcstrings` catalog. This shim is exclusively for Sim/'s own strings.
//

/// The Sim layer's current UI language, as a lowercase code ("en", "de", …).
/// The VIEW layer sets this once at launch from the system locale (so it stays
/// out of Sim/, which has no Locale access) — see `Localization.current`.
/// Defaults to "en" so the headless harness and any un-set path get English.
enum SimLocale {
    /// Set by the view layer at launch (e.g. `SimLocale.current = Locale…languageCode`).
    /// Pure storage — no Foundation dependency here.
    nonisolated(unsafe) static var current: String = "en"
}

/// Per-language format tables: language code → (English source key → translated
/// format). EMPTY today = every language falls back to the English key, so the
/// app is unchanged. A translator fills, e.g., `["de": ["Hub established at %@":
/// "Drehkreuz eingerichtet in %@", …]]`. Keys are the exact English source
/// strings, matching the `.xcstrings` convention on the view side.
private let simLocalizationTables: [String: [String: String]] = [:]
// A filled example, for when the translation pass runs (do NOT populate now):
//   "de": ["Hub established at %@": "Drehkreuz eingerichtet in %@", …]

/// Localize a Sim-layer string. Returns the source `key` (English) unless a table
/// for the current language contains it. `%@` in the (possibly translated) format
/// is replaced positionally by `args`, so translations may reorder placeholders.
/// Framework-free by construction — safe in the headless harness.
func L(_ key: String, _ args: Any...) -> String {
    let format = simLocalizationTables[SimLocale.current]?[key] ?? key
    return formatPositional(format, args)
}

/// A minimal, dependency-free positional formatter: replaces each `%@` in
/// `format` with the next arg (String(describing:)). Deliberately supports only
/// `%@` — the one placeholder the Sim strings use — so it needs no Foundation
/// `String(format:)` (which is fine in the app but is the kind of dependency we
/// keep out of Sim/ on principle). Extra args are ignored; missing args leave the
/// `%@` literal (visible in dev, harmless).
private func formatPositional(_ format: String, _ args: [Any]) -> String {
    guard !args.isEmpty, format.contains("%@") else { return format }
    var out = ""
    var i = args.makeIterator()
    var chars = format.makeIterator()
    var pending: Character? = nil
    while let c = pending ?? chars.next() {
        pending = nil
        if c == "%" {
            if let n = chars.next() {
                if n == "@" {
                    out += (i.next().map { String(describing: $0) }) ?? "%@"
                } else if n == "%" {
                    out += "%"
                } else {
                    out.append(c); pending = n
                }
            } else {
                out.append(c)
            }
        } else {
            out.append(c)
        }
    }
    return out
}
