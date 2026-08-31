# German Localization — Terminology Glossary (de)

The canonical German term for each recurring domain concept, so the whole app translates
CONSISTENTLY. Register: **du (informal)**. Aviation terms use the forms common in German-language
aviation/sim games, not literal dictionary translations. ⚠️ AI-drafted, NOT native-reviewed — a
native German aviation speaker should sanity-check the starred (★) terms.

## Core domain nouns

| English | German | Notes |
|---|---|---|
| Airline | Fluggesellschaft ★ | "Airline" is also understood/used in DE gaming; "Fluggesellschaft" is the correct full term. Use "Airline" where space is tight (tab labels). |
| Aircraft | Flugzeug | plural: Flugzeuge |
| Fleet | Flotte | |
| Route | Route | (das Route → **die Route**, pl. Routen) — the English loanword is standard in German aviation |
| Hub | Drehkreuz ★ | the correct German aviation term; "Hub" is also used colloquially |
| Crew | Crew ★ | English loanword is standard in German aviation; "Besatzung" is the formal alternative |
| Gate | Gate | English loanword standard at German airports |
| Slot | Slot | English loanword standard (airport slots) |
| Passenger | Passagier | pl. Passagiere; "Fluggast" is the formal alt |
| Cargo | Fracht | |
| Revenue | Umsatz ★ | or "Einnahmen"; "Umsatz" = turnover/revenue in business German |
| Cash / Cash on hand | Barmittel ★ | "Barmittel" = liquid funds; "Bargeld" is literal cash. For "Cash on hand" → "Verfügbare Mittel" |
| Lease / to lease | Leasing / leasen | English loanword standard in German business |
| Maintenance | Wartung | |
| Landing | Landung | |
| Takeoff | Start | (aviation "Start" = takeoff; "Abflug" = departure) |
| Airport | Flughafen | |
| Widebody | Großraumflugzeug ★ | or keep "Widebody" (used in DE aviation) |
| Narrowbody | Standardrumpfflugzeug ★ | awkward in German; "Schmalrumpfflugzeug" or keep "Narrowbody" |
| Turboprop | Turboprop | loanword standard |

## Actions / buttons

| English | German | Notes |
|---|---|---|
| Buy | Kaufen | |
| Sell | Verkaufen | |
| Lease | Leasen | |
| Acquire | Erwerben | (Acquire aircraft → Flugzeug erwerben) |
| Open Route | Route eröffnen | |
| Hire Crew | Crew einstellen | |
| Assign | Zuweisen | |
| Save | Speichern | |
| Quit | Beenden | |
| Continue | Fortfahren / Weiter | |
| Upgrade | Upgrade ★ | loanword standard; or "Vollversion freischalten" for the paywall |
| Restore Purchase | Kauf wiederherstellen | |
| Confirm | Bestätigen | |
| Cancel | Abbrechen | |
| Delete | Löschen | |
| Borrow | Aufnehmen ★ | (a loan → Kredit aufnehmen) |

## Economy / finance

| English | German | Notes |
|---|---|---|
| Loan | Kredit | |
| Net worth | Nettovermögen | |
| Net revenue / Net | Nettoumsatz / Netto | |
| Operating cost | Betriebskosten | |
| Fees | Gebühren | |
| Fare | Flugpreis ★ | ticket price; "Tarif" for fare-class |
| Load factor | Auslastung | (Sitzplatzauslastung); standard airline German |
| Demand | Nachfrage | |
| Profitable | Profitabel / Rentabel | |
| Hub / Club | Drehkreuz / Lounge | "Club" (airport lounge) → "Lounge" ★ |
| Go Public / IPO | Börsengang | |
| Share price | Aktienkurs | |
| Dividend | Dividende | |

## Game systems / UI

| English | German | Notes |
|---|---|---|
| Network | Netzwerk | (the tab) |
| Marketplace | Marktplatz | |
| Alerts | Meldungen ★ | or "Benachrichtigungen" (longer) |
| Ops / Operations | Betrieb ★ | (the Ops tab) |
| Finance | Finanzen | (the tab) |
| Achievement | Erfolg | (Game Center standard German = "Erfolge") |
| Milestone | Meilenstein | |
| Reputation | Reputation / Ansehen | |
| Livery | Lackierung ★ | aircraft livery = "Lackierung" |
| Tail code | Kennung ★ | aircraft registration/tail = "Kennung" |
| Region | Region | |
| Subsidiary | Tochtergesellschaft | |

## Register + style rules

- **du**, not Sie. ("Deine Flotte", "Du hast...", imperatives: "Wähle...", "Eröffne...")
- Keep English loanwords where they're genuinely standard in German aviation/business (Route, Slot,
  Gate, Crew, Leasing, Hub, Lounge, Upgrade) — do NOT over-Germanize; that reads as stilted.
- German compound nouns get long — for tight UI (tab bar, chips, control-bar buttons) prefer the
  shortest acceptable form and rely on `minimumScaleFactor` (already 0.7 on the control bar).
- Currency is shown in **€** in the German build (designer direction, 30 Aug) — a
  symbol-only presentation swap via `Currency.symbol` (view) / `SimLocale.currencySymbol`
  (Sim); the economy stays USD-denominated internally, NO FX conversion, so the numbers
  are identical and every balance/invariant is unchanged. (Supersedes the earlier
  "currency stays `$`" note.) English build keeps `$`.
- Airport codes, aircraft type names (Boeing 737, Airbus A320), and real airline names are PROPER
  NOUNS — never translate them.
