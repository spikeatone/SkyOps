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

    /// Displayed currency symbol — euro in German, dollar elsewhere. The economy
    /// is USD-denominated internally; this is a symbol-only presentation swap (no
    /// FX), matching the view layer's `Currency.symbol`. Framework-free.
    static var currencySymbol: String { current == "de" ? "€" : "$" }
}

/// Per-language format tables: language code → (English source key → translated
/// format). EMPTY today = every language falls back to the English key, so the
/// app is unchanged. A translator fills, e.g., `["de": ["Hub established at %@":
/// "Drehkreuz eingerichtet in %@", …]]`. Keys are the exact English source
/// strings, matching the `.xcstrings` convention on the view side.
private let simLocalizationTables: [String: [String: String]] = [
    "de": [
        " as the market consolidates": " im Zuge der Marktkonsolidierung",
        " — priced out by your fare war": " — verdrängt durch deinen Preiskampf",
        "$%@ at %@%% · $%@/mo": "€%@ zu %@%% · €%@/Mon.",
        "$%@ from recouping its opening cost.": "€%@ bis zur Amortisierung der Eröffnungskosten.",
        "$%@ settled in full · no more interest": "€%@ vollständig getilgt · keine Zinsen mehr",
        "%@ Club": "%@ Club",
        "%@ acquired": "%@ übernommen",
        "%@ aircraft and %@ routes join your group — %@ keeps flying under its own flag.": "%@ Flugzeuge und %@ Routen kommen zu deiner Gruppe — %@ fliegt weiter unter eigener Flagge.",
        "%@ aircraft flying %@ route · $%@ on hand.": "%@ Flugzeuge auf %@ Route · €%@ verfügbar.",
        "%@ aircraft flying %@ routes · $%@ on hand.": "%@ Flugzeuge auf %@ Routen · €%@ verfügbar.",
        "%@ aircraft in the fleet": "%@ Flugzeuge in der Flotte",
        "%@ aircraft · %@ routes": "%@ Flugzeuge · %@ Routen",
        "%@ aircraft · %@ · ~%@d through the shop": "%@ Flugzeuge · %@ · ~%@ T in der Werkstatt",
        "%@ bought back stock": "%@ hat Aktien zurückgekauft",
        "%@ capacity expansion": "%@ Kapazitätsausbau",
        "%@ crews are back on the line.": "%@-Crews sind wieder im Dienst.",
        "%@ day left — margins are moving.": "%@ Tag übrig — die Margen bewegen sich.",
        "%@ day to raise funds before forced liquidation.": "%@ Tag, um Mittel zu beschaffen, bevor liquidiert wird.",
        "%@ day to staff it or the deal is forfeited.": "%@ Tag, um es zu besetzen, sonst verfällt der Deal.",
        "%@ days left — margins are moving.": "%@ Tage übrig — die Margen bewegen sich.",
        "%@ days to raise funds before forced liquidation.": "%@ Tage, um Mittel zu beschaffen, bevor liquidiert wird.",
        "%@ days to staff it or the deal is forfeited.": "%@ Tage, um es zu besetzen, sonst verfällt der Deal.",
        "%@ decision waiting": "%@ Entscheidung wartet",
        "%@ decisions waiting": "%@ Entscheidungen warten",
        "%@ doubles down": "%@ legt nach",
        "%@ dumps capacity %@-%@": "%@ wirft Kapazität auf den Markt %@-%@",
        "%@ handed back to the lessor": "%@ an den Leasinggeber zurückgegeben",
        "%@ has gone public — shares opened strong.": "%@ ist an die Börse gegangen — die Aktie startete stark.",
        "%@ heard a new airline is starting up — and they want to be your first customer. Fly %@ ↔ %@ and they'll waive every opening fee, plus a $%@ signing bonus. ~%@ travelers a day are waiting. Accept, then buy an aircraft that can fly it.": "%@ hat gehört, dass eine neue Airline startet — und will dein erster Kunde sein. Fliege %@ ↔ %@ und alle Eröffnungsgebühren werden erlassen, plus €%@ Willkommensbonus. ~%@ Reisende pro Tag warten. Nimm an und kaufe dann ein Flugzeug, das die Route fliegen kann.",
        "%@ hold at %@": "%@-Sperre in %@",
        "%@ hub closed — the build-out is written off": "Drehkreuz %@ geschlossen — der Ausbau wird abgeschrieben",
        "%@ hub is understaffed": "Drehkreuz %@ ist unterbesetzt",
        "%@ integrated": "%@ integriert",
        "%@ integration runs %@ months. %@": "Integration von %@ dauert %@ Monate. %@",
        "%@ is closed for its night curfew": "%@ ist wegen Nachtflugverbot geschlossen",
        "%@ is courting you for %@ ↔\\u{FE0E} %@": "%@ umwirbt dich für %@ ↔\\u{FE0E} %@",
        "%@ is expanding hub operations.": "%@ baut den Drehkreuz-Betrieb aus.",
        "%@ is expanding its %@ hub operation.": "%@ baut den Drehkreuz-Betrieb in %@ aus.",
        "%@ is fully integrated after %@ months.": "%@ ist nach %@ Monaten vollständig integriert.",
        "%@ is now a %@ hub — %@ banked, gates gone for good": "%@ ist jetzt ein %@-Drehkreuz — %@ verbucht, Gates für immer weg",
        "%@ is public": "%@ ist an der Börse",
        "%@ liquidated to cover debt": "%@ zur Schuldendeckung liquidiert",
        "%@ moves to %@ ↔\\u{FE0E} %@ after it lands at %@": "%@ wechselt nach der Landung in %@ auf %@ ↔\\u{FE0E} %@",
        "%@ net worth": "%@ Nettovermögen",
        "%@ new slots available": "%@ neue Slots verfügbar",
        "%@ now flies %@ ↔\\u{FE0E} %@%@": "%@ fliegt jetzt %@ ↔\\u{FE0E} %@%@",
        "%@ now flies for %@.": "%@ fliegt jetzt für %@.",
        "%@ opens at %@": "%@ eröffnet in %@",
        "%@ paid a dividend": "%@ hat eine Dividende gezahlt",
        "%@ parks as a spare after it lands at %@": "%@ wird nach der Landung in %@ zur Reserve geparkt",
        "%@ posts results": "%@ legt Zahlen vor",
        "%@ pulled out of %@ ↔\\u{FE0E} %@%@": "%@ hat sich aus %@ ↔\\u{FE0E} %@%@ zurückgezogen",
        "%@ reached hub eligibility": "%@ hat die Drehkreuz-Eignung erreicht",
        "%@ refreshes its fleet": "%@ erneuert seine Flotte",
        "%@ returns to the mainline fleet.": "%@ kehrt zur Hauptflotte zurück.",
        "%@ rings the bell": "%@ läutet die Börsenglocke",
        "%@ routes in the network": "%@ Routen im Netzwerk",
        "%@ routes now use %@ — you can establish a hub (tap the airport)": "%@ Routen nutzen jetzt %@ — du kannst ein Drehkreuz errichten (tippe den Flughafen an)",
        "%@ secondary offering": "%@ Kapitalerhöhung",
        "%@ wants to fund your first route: %@ ↔\\u{FE0E} %@": "%@ will deine erste Route finanzieren: %@ ↔\\u{FE0E} %@",
        "%@ wants your airline. Launch %@ ↔ %@, pocket a %@ signing incentive, and we cover your setup costs. This market's been overlooked too long.": "%@ will deine Airline. Eröffne %@ ↔ %@, sichere dir einen %@ Startanreiz, und wir übernehmen deine Einrichtungskosten. Dieser Markt wurde zu lange übersehen.",
        "%@ went public": "%@ ging an die Börse",
        "%@ → %@ ↔\\u{FE0E} %@": "%@ → %@ ↔\\u{FE0E} %@",
        "%@ ↔\\u{FE0E} %@": "%@ ↔\\u{FE0E} %@",
        "%@ ↔\\u{FE0E} %@ closed under activist pressure": "%@ ↔\\u{FE0E} %@ unter Aktivistendruck geschlossen",
        "%@ ↔\\u{FE0E} %@ — %@ %@": "%@ ↔\\u{FE0E} %@ — %@ %@",
        "%@ ↔\\u{FE0E} %@ — locking in loyal flyers": "%@ ↔\\u{FE0E} %@ — treue Vielflieger binden",
        "%@ ↔\\u{FE0E} %@ — undercutting rivals to reclaim the route": "%@ ↔\\u{FE0E} %@ — Konkurrenten unterbieten, um die Route zurückzugewinnen",
        "%@ ↔\\u{FE0E} %@: $%@": "%@ ↔\\u{FE0E} %@: €%@",
        "%@ ↔\\u{FE0E} %@: %@ assigned · +$%@ bonus": "%@ ↔\\u{FE0E} %@: %@ zugewiesen · +€%@ Bonus",
        "%@ ↔\\u{FE0E} %@: not staffed in time — $%@ bonus clawed back": "%@ ↔\\u{FE0E} %@: nicht rechtzeitig besetzt — €%@ Bonus zurückgefordert",
        "%@ ↔\\u{FE0E} %@: staff within %@ days · +$%@ bonus": "%@ ↔\\u{FE0E} %@: binnen %@ Tagen besetzen · +€%@ Bonus",
        "%@'s airport authority is courting you: fly %@ ↔ %@ and we'll waive every opening fee, plus a %@ marketing package. ~%@ travelers a day, and no direct link to your network yet.": "Die Flughafenbehörde von %@ umwirbt dich: fliege %@ ↔ %@ und wir erlassen alle Eröffnungsgebühren, plus ein %@ Marketing-Paket. ~%@ Reisende pro Tag, und noch keine direkte Anbindung an dein Netzwerk.",
        "%@'s bid for the %@ hub was turned down": "Das Gebot von %@ für das Drehkreuz %@ wurde abgelehnt",
        "%@'s curfew has lifted": "Das Nachtflugverbot in %@ wurde aufgehoben",
        "%@: %@ crew in recurrent training": "%@: %@ Crew in Wiederholungsschulung",
        "%@: %@ crew sidelined": "%@: %@ Crew ausgesetzt",
        "%@: %@ grounded": "%@: %@ am Boden",
        "%@: activist investor": "%@: aktivistischer Investor",
        "%@: activist rebuffed": "%@: Aktivist abgewiesen",
        "%@: activist stands down": "%@: Aktivist gibt auf",
        "%@: ousted by the board": "%@: vom Vorstand abgesetzt",
        "%@: scheduled in 30 days": "%@: in 30 Tagen geplant",
        "%@: the board is restless": "%@: der Vorstand wird unruhig",
        "%@–%@ is almost profitable": "%@–%@ ist fast profitabel",
        "%@–%@ needs an aircraft": "%@–%@ braucht ein Flugzeug",
        "1,000 flights flown": "1.000 Flüge absolviert",
        "100 flights flown": "100 Flüge absolviert",
        "365 days of operations — your first anniversary.": "365 Betriebstage — dein erstes Jubiläum.",
        "A beach for every day": "Ein Strand für jeden Tag",
        "A dividend satisfied the activist and they stood down.": "Eine Dividende stellte den Aktivisten zufrieden und er gab auf.",
        "A major carrier.": "Eine große Airline.",
        "A powerhouse of the skies.": "Ein Gigant der Lüfte.",
        "A real fleet now.": "Jetzt eine echte Flotte.",
        "A real network.": "Ein echtes Netzwerk.",
        "A rough quarter — margins under pressure and costs climbing.": "Ein schwaches Quartal — Margen unter Druck und steigende Kosten.",
        "A serious network.": "Ein ernstzunehmendes Netzwerk.",
        "A sprawling, worldwide map.": "Eine weitläufige, weltweite Karte.",
        "ATC staffing shortage": "Personalmangel bei der Flugsicherung",
        "Acquired %@": "%@ übernommen",
        "Activist investor campaign": "Kampagne eines aktivistischen Investors",
        "Ad campaign launched": "Werbekampagne gestartet",
        "Aircraft assigned": "Flugzeug zugewiesen",
        "Aircraft reassigned": "Flugzeug neu zugewiesen",
        "Airline": "Airline",
        "Airworthiness Directive": "Lufttüchtigkeitsanweisung",
        "All %@ aircraft are back in service in the new livery": "Alle %@ Flugzeuge sind in der neuen Lackierung wieder im Dienst",
        "All quiet on the network": "Alles ruhig im Netzwerk",
        "An activist took a %@%% stake, pressing for change while the stock trades below its IPO price.": "Ein Aktivist hat %@%% übernommen und drängt auf Veränderung, während die Aktie unter dem Ausgabepreis notiert.",
        "Analysts say %@ could be an acquisition target this year.": "Analysten sagen, %@ könnte dieses Jahr ein Übernahmeziel sein.",
        "Atlantic dunes and shimmering salt flats": "Atlantische Dünen und schimmernde Salzfelder",
        "BANKRUPTCY": "INSOLVENZ",
        "Below 5 routes — benefits suspended while the bills keep coming.": "Unter 5 Routen — Vorteile ausgesetzt, während die Kosten weiterlaufen.",
        "Black-sand shores of French Polynesia": "Schwarzsandküsten Französisch-Polynesiens",
        "Books opened for %@.": "Bücher geöffnet für %@.",
        "Brazil's restless, endless metropolis": "Brasiliens rastlose, endlose Metropole",
        "Bright lights in the desert night": "Helle Lichter in der Wüstennacht",
        "Bula — islands of warm welcomes": "Bula — Inseln herzlicher Begrüßung",
        "Cash is negative": "Barmittel sind negativ",
        "Cash on hand is negative": "Barmittel sind negativ",
        "Check the alerts bell — aircraft or offers need a call.": "Prüfe die Meldungsglocke — Flugzeuge oder Angebote brauchen eine Entscheidung.",
        "Chic harbor of yachts and glamour": "Schicker Hafen voller Yachten und Glamour",
        "Competitor entered your market": "Konkurrent ist in deinen Markt eingetreten",
        "Competitor exited": "Konkurrent hat sich zurückgezogen",
        "Control lost and the stock in the doldrums — the board voted you out.": "Kontrolle verloren und die Aktie am Boden — der Vorstand hat dich abgewählt.",
        "Crew training": "Crew-Schulung",
        "Crew training deferred": "Crew-Schulung aufgeschoben",
        "Crossroads of the wider world": "Kreuzung der weiten Welt",
        "Curfew lifted": "Nachtflugverbot aufgehoben",
        "Demand up — fares +%@%%": "Nachfrage steigt — Flugpreise +%@%%",
        "Desert skyline of gilded ambition": "Wüsten-Skyline vergoldeter Ambitionen",
        "Diver's paradise ringed by reefs": "Taucherparadies, umgeben von Riffen",
        "Double digits!": "Zweistellig!",
        "Dreamliner, stretched for range": "Dreamliner, gestreckt für mehr Reichweite",
        "Due diligence: %@": "Due Diligence: %@",
        "Economic Boom": "Wirtschaftsboom",
        "Efficient new-engine compact": "Sparsamer Kompakter mit neuen Triebwerken",
        "Emerald hills over turquoise harbors": "Smaragdgrüne Hügel über türkisen Buchten",
        "Extra-wide body, extra range": "Extrabreiter Rumpf, extra Reichweite",
        "FX shock": "Wechselkursschock",
        "Fare war": "Preiskampf",
        "Fare war launched": "Preiskampf gestartet",
        "Fares down %@%%": "Flugpreise −%@%%",
        "Finding your rhythm.": "Du findest deinen Rhythmus.",
        "First airline acquired!": "Erste Airline übernommen!",
        "First club opened!": "Erste Lounge eröffnet!",
        "First flight complete!": "Erster Flug abgeschlossen!",
        "First hub established!": "Erstes Drehkreuz errichtet!",
        "First international route!": "Erste internationale Route!",
        "First jet purchased!": "Erstes Flugzeug gekauft!",
        "First route opened!": "Erste Route eröffnet!",
        "First widebody!": "Erstes Großraumflugzeug!",
        "Fleet repaint complete": "Flotten-Neulackierung abgeschlossen",
        "Fleet repaint scheduled": "Flotten-Neulackierung geplant",
        "Fleet transfer": "Flottentransfer",
        "Forced sale": "Zwangsverkauf",
        "Four engines, long-haul stalwart": "Vier Triebwerke, treuer Langstreckenriese",
        "Four regions in your network": "Vier Regionen in deinem Netzwerk",
        "Frequent-Flyer Redemption Surge": "Ansturm bei Prämieneinlösungen",
        "Fuel Price Drop": "Treibstoffpreis-Sturz",
        "Fuel costs drop %@%%": "Treibstoffkosten sinken um %@%%",
        "Fuel costs surge %@%%": "Treibstoffkosten steigen um %@%%",
        "Garden city where the future lands": "Gartenstadt, in der die Zukunft landet",
        "Gateway to Kauai's emerald canyons": "Tor zu Kauais smaragdgrünen Schluchten",
        "Grace Bay's impossibly clear water": "Das unglaublich klare Wasser der Grace Bay",
        "Granite boulders on powder-white sand": "Granitfelsen auf pudrig-weißem Sand",
        "Green peaks meet Caribbean blue": "Grüne Gipfel treffen auf karibisches Blau",
        "Ground stop": "Bodenstopp",
        "Ground stop at %@": "Bodenstopp in %@",
        "Ground stop lifted": "Bodenstopp aufgehoben",
        "Ground stops: %@": "Bodenstopps: %@",
        "Harbor sails and golden beaches": "Hafensegel und goldene Strände",
        "Home of carnival and steelpan": "Heimat von Karneval und Steelpan",
        "Hub SOLD to %@": "Drehkreuz VERKAUFT an %@",
        "Hub decommissioned": "Drehkreuz stillgelegt",
        "Hub established at %@": "Drehkreuz errichtet in %@",
        "Hub offer declined": "Drehkreuz-Angebot abgelehnt",
        "Hurricane": "Hurrikan",
        "Insurance hard market": "Harter Versicherungsmarkt",
        "Integration complete": "Integration abgeschlossen",
        "Integration underway": "Integration läuft",
        "Japan's tropical island of longevity": "Japans tropische Insel der Langlebigkeit",
        "Labor action": "Arbeitskampf",
        "Labor action resolved": "Arbeitskampf beigelegt",
        "Land of fire, ice, and aurora": "Land aus Feuer, Eis und Polarlicht",
        "Last frontier under the midnight sun": "Letzte Wildnis unter der Mitternachtssonne",
        "Lease returned": "Leasing zurückgegeben",
        "Lift the share price or rebuild your stake before patience runs out.": "Hebe den Aktienkurs oder baue deinen Anteil wieder auf, bevor die Geduld endet.",
        "Listed at %@/share. Raised %@ selling %@%%.": "Notiert zu %@/Aktie. %@ durch Verkauf von %@%% eingenommen.",
        "Loan drawn": "Kredit aufgenommen",
        "Loan paid off early": "Kredit vorzeitig getilgt",
        "Loyalty has a lounge now.": "Treue hat jetzt eine Lounge.",
        "Loyalty push launched": "Treueoffensive gestartet",
        "Maintenance cost inflation": "Wartungskosten-Inflation",
        "Merger chatter": "Fusionsgerüchte",
        "Mile-high gateway to the Rockies": "Tor zu den Rockies, eine Meile hoch",
        "Monsoon": "Monsun",
        "Neon nights and ancient shrines": "Neonnächte und uralte Schreine",
        "New aircraft orders signal %@.": "Neue Flugzeugbestellungen signalisieren %@.",
        "Night curfew": "Nachtflugverbot",
        "Nimble short-field 737": "Wendige Kurzstartbahn-737",
        "No overlapping type ratings.": "Keine überschneidenden Musterberechtigungen.",
        "Normal": "Normal",
        "Oil Price Spike": "Ölpreisspitze",
        "Old San Juan's blue cobblestones": "Die blauen Pflastersteine von Alt-San-Juan",
        "One happy island, endless sun": "Eine glückliche Insel, endlose Sonne",
        "One year in the sky": "Ein Jahr am Himmel",
        "Overwater villas on glassy lagoons": "Überwasser-Villen auf glasklaren Lagunen",
        "Palm-lined gateway to the stars": "Palmengesäumtes Tor zu den Sternen",
        "Paradise on your map!": "Das Paradies auf deiner Karte!",
        "Parking scheduled": "Parken geplant",
        "Pastel Dutch facades on the sea": "Pastellfarbene holländische Fassaden am Meer",
        "Pink beaches and pastel cottages": "Rosa Strände und pastellfarbene Cottages",
        "Pink sands and pastel colonial charm": "Rosa Strände und pastellfarbener Kolonialcharme",
        "Premium lounge built for %@ — loyalty starts here": "Premium-Lounge für %@ gebaut — Treue beginnt hier",
        "Premiums up %@%%": "Prämien um %@%% gestiegen",
        "Queen of the Skies": "Königin der Lüfte",
        "Quiet, fuel-sipping bestseller": "Leise, sparsam, ein Bestseller",
        "Rainforest doorstep to living volcanoes": "Regenwald-Schwelle zu lebenden Vulkanen",
        "Raised %@": "%@ eingenommen",
        "Raised %@; your stake is now %@%%.": "%@ eingenommen; dein Anteil beträgt jetzt %@%%.",
        "Reassignment scheduled": "Neuzuweisung geplant",
        "Recession": "Rezession",
        "Recouped its opening cost.": "Hat die Eröffnungskosten amortisiert.",
        "Recover within 14 days or assets will be liquidated": "Erhole dich binnen 14 Tagen, sonst werden Vermögenswerte liquidiert",
        "Repair costs +%@%%": "Reparaturkosten +%@%%",
        "Repurchased %@ of shares; your stake is now %@%%.": "%@ an Aktien zurückgekauft; dein Anteil beträgt jetzt %@%%.",
        "Route closed": "Route geschlossen",
        "Route is profitable!": "Route ist profitabel!",
        "Route offer": "Routen-Angebot",
        "Route offer accepted": "Routen-Angebot angenommen",
        "Route offer forfeited": "Routen-Angebot verfallen",
        "Route opened": "Route eröffnet",
        "Rum, cricket, and Bajan sunshine": "Rum, Cricket und bajanische Sonne",
        "Sailor's gateway to the Virgin Islands": "Das Seglertor zu den Virgin Islands",
        "Seats fill (+%@%%), less cash per seat": "Sitze füllen sich (+%@%%), weniger Ertrag pro Sitz",
        "Security incident": "Sicherheitsvorfall",
        "Seniority agreement signed": "Senioritätsvereinbarung unterzeichnet",
        "Seniority dispute across %@ crew families.": "Senioritätsstreit über %@ Crew-Familien.",
        "Seniority dispute resolved": "Senioritätsstreit beigelegt",
        "Seven Mile Beach and Stingray City": "Seven Mile Beach und Stingray City",
        "Seven regions served": "Sieben Regionen bedient",
        "Short-field turboprop workhorse": "Kurzstartbahn-Turboprop-Arbeitstier",
        "Slot sold": "Slot verkauft",
        "Small, modern, remarkably quiet": "Klein, modern, erstaunlich leise",
        "Special dividend of %@ to shareholders.": "Sonderdividende von %@ an die Aktionäre.",
        "Spice trade and Stone Town alleys": "Gewürzhandel und die Gassen von Stone Town",
        "Straight talk from %@: ~%@ passengers a day are driving hours to the nearest hub. Open %@ ↔ %@ on us — zero opening cost, plus %@ to get started.": "Klartext aus %@: ~%@ Passagiere pro Tag fahren Stunden zum nächsten Drehkreuz. Eröffne %@ ↔ %@ auf unsere Kosten — null Eröffnungskosten, plus %@ für den Start.",
        "Stretched Next-Generation 737": "Gestreckte Next-Generation-737",
        "Stretched for more seats": "Gestreckt für mehr Sitze",
        "Stretched regional flagship": "Gestrecktes Regional-Flaggschiff",
        "Strong quarter — %@%% load factor and healthy margins.": "Starkes Quartal — %@%% Auslastung und gesunde Margen.",
        "Sun-baked lava coast and Kona coffee": "Sonnengebrannte Lavaküste und Kona-Kaffee",
        "Table Mountain guards two oceans": "Der Tafelberg wacht über zwei Ozeane",
        "Tahiti joins the network.": "Tahiti kommt ins Netzwerk.",
        "Tango, steak, and midnight streets": "Tango, Steak und mitternächtliche Straßen",
        "That 2,000-ft strip is a badge of honor.": "Diese 2.000-Fuß-Piste ist ein Ehrenabzeichen.",
        "The City of Light awaits": "Die Stadt der Lichter wartet",
        "The Dreamliner": "Der Dreamliner",
        "The Pitons rise from the sea": "Die Pitons ragen aus dem Meer",
        "The Superjumbo": "Der Superjumbo",
        "The activist grew to %@%% and is escalating (round %@).": "Der Aktivist ist auf %@%% gewachsen und eskaliert (Runde %@).",
        "The activist's demand was met and they stood down.": "Die Forderung des Aktivisten wurde erfüllt und er gab auf.",
        "The airline is insolvent — game over": "Die Airline ist zahlungsunfähig — Spiel vorbei",
        "The airline is really taking off.": "Die Airline hebt richtig ab.",
        "The airline rings the opening bell.": "Die Airline läutet die Eröffnungsglocke.",
        "The big metal has arrived.": "Das große Gerät ist da.",
        "The bigger E-Jet": "Der größere E-Jet",
        "The board is restless": "Der Vorstand ist unruhig",
        "The board is weighing your removal. Rebuild your stake above 50%% or lift the share price.": "Der Vorstand erwägt deine Absetzung. Bringe deinen Anteil wieder über 50%% oder hebe den Aktienkurs.",
        "The city that never sleeps": "Die Stadt, die niemals schläft",
        "The compact commuter jet": "Der kompakte Pendlerjet",
        "The compact single-aisle": "Der kompakte Single-Aisle",
        "The efficient re-engined 737": "Die sparsame neu motorisierte 737",
        "The everyday workhorse": "Das Arbeitstier für jeden Tag",
        "The fast regional turboprop": "Der schnelle Regional-Turboprop",
        "The final Queen of the Skies": "Die letzte Königin der Lüfte",
        "The fragrant Spice Isle awaits": "Die duftende Gewürzinsel wartet",
        "The long-legged narrowbody": "Der Langstrecken-Narrowbody",
        "The long-range leader": "Der Langstrecken-Spitzenreiter",
        "The longest Dreamliner": "Der längste Dreamliner",
        "The map is filling in.": "Die Karte füllt sich.",
        "The merger is complete": "Die Fusion ist abgeschlossen",
        "The mighty Triple Seven": "Die mächtige Triple Seven",
        "The modern A330neo": "Die moderne A330neo",
        "The network is humming.": "Das Netzwerk brummt.",
        "The pocket regional jet": "Der handliche Regionaljet",
        "The recovering share price sent the activist packing.": "Der sich erholende Aktienkurs vertrieb den Aktivisten.",
        "The regional express": "Der Regional-Express",
        "The regional feeder classic": "Der Regional-Zubringer-Klassiker",
        "The regional jet debut": "Das Regionaljet-Debüt",
        "The regional turboprop workhorse": "Das Regional-Turboprop-Arbeitstier",
        "The regional workhorse": "Das Regional-Arbeitstier",
        "The short-field island hopper": "Der Kurzstartbahn-Inselhüpfer",
        "The single-aisle workhorse": "Das Single-Aisle-Arbeitstier",
        "The stretched MAX": "Die gestreckte MAX",
        "The stretched regional jet": "Der gestreckte Regionaljet",
        "The whisper-quiet newcomer": "Der flüsterleise Newcomer",
        "The wild, unspoiled Nature Isle": "Die wilde, unberührte Naturinsel",
        "They hold %@%% and want change — settle it or outperform it.": "Sie halten %@%% und wollen Veränderung — löse es oder übertriff es.",
        "Thirty-three beaches, barely a crowd": "Dreiunddreißig Strände, kaum ein Mensch",
        "Volcanic gateway to the Grenadines": "Vulkanisches Tor zu den Grenadines",
        "Weather": "Wetter",
        "Wheels up — welcome to the skies.": "Abheben — willkommen am Himmel.",
        "Where East meets a neon skyline": "Wo der Osten auf eine Neon-Skyline trifft",
        "Where jets skim Maho Beach": "Wo Jets über Maho Beach hinwegziehen",
        "Where mountains meet the coral sea": "Wo Berge auf das Korallenmeer treffen",
        "Where the road to Hana begins": "Wo die Straße nach Hana beginnt",
        "Widebody fares −%@%%": "Großraum-Flugpreise −%@%%",
        "Winter storm": "Wintersturm",
        "You now serve St. Barths!": "Du bedienst jetzt St. Barths!",
        "You're crossing borders now.": "Du überquerst jetzt Grenzen.",
        "You're publicly traded!": "Du bist börsennotiert!",
        "Your empire grows by merger.": "Dein Imperium wächst durch Fusion.",
        "Your first city pair is live.": "Dein erstes Städtepaar ist aktiv.",
        "Your first customer": "Dein erster Kunde",
        "Your fleet has its first aircraft.": "Deine Flotte hat ihr erstes Flugzeug.",
        "Your fortress takes shape.": "Deine Festung nimmt Gestalt an.",
        "Your reach is spreading.": "Deine Reichweite wächst.",
        "a bid to cut operating costs": "den Versuch, Betriebskosten zu senken",
        "an aggressive growth push": "einen aggressiven Wachstumskurs",
        "parked as spare": "als Reserve geparkt",
        "reassigned": "neu zugewiesen",
    ],
]

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
