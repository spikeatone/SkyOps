# German App Store listing (de-DE) — DRAFT for 1.6.0

AI-drafted from the live en-US 1.5 listing, glossary-consistent (Drehkreuz / Route /
Crew / Slot / du-register). **Native-German review before publishing** — same rule as
the in-app strings. ASC character limits noted; all drafts are within them.

⚠️ Locale: create as **German (de-DE)** on the 1.6.0 version. Also mirror the two
LEGAL links (they're the same URLs, language-neutral).

---

## Name  (≤30 chars)
`Airline Architect`
→ **KEEP English** — it's the brand/product name (proper noun), same as in-app.
(17 chars.)

## Subtitle  (≤30 chars)
**`Bau dein Airline-Imperium`**  (25 chars)

Alternatives if you want a different angle:
- `Airline-Tycoon & Aufbausim`  (26)
- `Baue deine Fluggesellschaft`  (27)

## Promotional Text  (≤170 chars — editable anytime, NO review)
**`Bau aus einem Flugzeug und 20 Mio. $ eine globale Airline. Jetzt mit A350-1000 und Boeing 747-8i. Passe den Jet zum Markt, führe den Betrieb, beherrsche den Himmel.`**
(163 chars — dropped "Airbus" to fit ≤170.)

Version-agnostic option (drop the aircraft mention, so it survives past 1.6, 157 chars):
`Bau aus einem einzigen Flugzeug und 20 Mio. $ eine globale Airline. Passe den richtigen Jet zum richtigen Markt, führe den Betrieb und beherrsche den Himmel.`

## Keywords  (≤100 chars, comma-separated, NO spaces after commas)
**`airline,tycoon,flugzeug,luftfahrt,flug,simulator,management,strategie,route,flotte,flughafen,aufbausim`**
(101 → TRIM to fit ≤100; drop one. Suggested final, 96 chars:)
`airline,tycoon,flugzeug,luftfahrt,flug,simulator,management,strategie,flotte,flughafen,aufbausim`

Notes: ASC keywords are per-locale and DON'T need to match the display language 1:1 —
German users also search English "airline"/"tycoon"/"simulator", so keep those. Avoid
repeating words already in the Name/Subtitle (Apple indexes those separately).

---

## Description  (≤4000 chars)

Du startest mit 20 Millionen Dollar und einem leeren Hangar. Wohin du es bringst, liegt bei dir.

Airline Architect ist eine tiefgehende, realistische Airline-Management-Simulation. Kaufe oder lease deine Flotte, eröffne Routen in einer lebendigen Welt echter Flughäfen, stelle Crews ein und lass aus einem Ein-Flugzeug-Start-up eine globale Fluggesellschaft werden — während die Simulation niemals pausiert.

DAS RICHTIGE FLUGZEUG FÜR DEN RICHTIGEN MARKT
Ein echtes Passagiernachfrage-Modell macht die Routenwahl zum Kern des Spiels — ein großer Jet auf einer schwachen Route fliegt halb leer, ein zu kleiner lässt Geld liegen. Über dreißig reale Flugzeugtypen, vom Kurzstartbahn-Turboprop bis zum größten Großraumflugzeug, jedes mit echter Reichweite, Kapazität und Wirtschaftlichkeit.

FÜHRE EINEN ECHTEN BETRIEB
• Besitze deine Flotte — kaufe neu, lease oder durchstöbere den Gebrauchtmarkt. Jede Zelle altert, und alte Maschinen kosten mehr im Unterhalt.
• Crews folgen echten Dienst- und Ruhezeiten — eine Crew kann nicht ewig fliegen, also ist die Personalplanung eine echte Entscheidung.
• Wetter, technische Ausfälle und Crew-Engpässe erscheinen als Live-Entscheidungen, die du löst, während jedes andere Flugzeug weiterfliegt. Die Uhr steht nie still.

GEH IN DIE TIEFE, NICHT NUR IN DIE BREITE
• Errichte Drehkreuze und baue Airport-Lounges, um eine Stadt zu befestigen, Konkurrenten fernzuhalten und Loyalität aufzubauen — mit einer Live-Amortisationsansicht, die zeigt, ob es sich lohnt.
• Finanziere die Expansion mit Krediten — oder bring deine Airline an die Börse, mit Live-Aktienkurs, aktivistischen Investoren und einem Vorstand, der dich absetzen kann.
• Ganz oben angekommen? Späh Konkurrenten aus und übernimm sie — und überstehe die schwierige Integration.

EINE WELT, DIE LEBENDIG WIRKT
• Über 380 echte Flughäfen in Amerika, Europa, Afrika, Asien und im Pazifik — inklusive exotischer Inselpisten, die nur das richtige Flugzeug erreicht.
• Echte Jahreszeiten — Hurrikansaison, Winterstürme und Monsun bestimmen, wo und wann Störungen zuschlagen.
• Eine Tag-und-Nacht-Grenze wandert über die Karte, und echte nächtliche Flughafen-Sperrstunden schließen Städte für späte Abflüge — ein echter Preis dafür, sie anzufliegen.
• Konkurrenten machen dir deine profitabelsten Routen streitig und fliegen Flotten, die der realen Welt entsprechen.

Beschleunige die Zeit auf das 25-Fache, sieh zu, wie der Umsatz hereinkommt, und halte das ganze Netzwerk in der Luft.

Bau den Himmel.

RECHTLICHES
Nutzungsbedingungen (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Datenschutzrichtlinie: https://spikeatone.github.io/airline-architect/privacy.html

---

## What's New (de-DE)  — for the 1.6.0 version, once you write the English one
Draft (translate from whatever the English 1.6 "What's New" ends up being; placeholder):
`Airline Architect gibt es jetzt auf Deutsch! Außerdem: neue, stimmungsvolle Stadtbilder für Flughäfen weltweit. Danke fürs Spielen.`

---

## Notes for whoever publishes
- The 20 de screenshots already exist (`App Store Screenshots/de/`) — upload to the de-DE localization.
- Game Center: achievement titles/descriptions have their OWN German localizations (separate from this
  store listing), done in ASC via `asc.py` (see GAMEKIT_SETUP.md). Not covered here.
- "$" in the description/promo: kept as "$" / "Dollar" deliberately — the store copy describes the game's
  $20M starting stake (a game fact), while the in-APP currency shows € for German devices. Don't "fix"
  this to €; the two are intentionally different (game copy vs. in-app display).
