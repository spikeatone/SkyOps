# RELEASE STATUS — App Store submission, v1.0 (build 26)

Snapshot of the 1.0 App Store submission as of **18 July 2026**. Written so a
future session (or a remote session with no conversation history) can pick this
up cold. `CLAUDE.md` holds the technical/design context; this file is ONLY the
release-and-store state.

Update it as items land, and delete it once 1.0 is live and this is history.

## The binary

- **Build 26** (`CURRENT_PROJECT_VERSION = 26`, marketing version `1.0`),
  commit "Bump build number to 26 for TestFlight".
- Archived to `~/Library/Developer/Xcode/Archives/2026-07-18/AA-build26.xcarchive`
  and **uploaded to App Store Connect** by the designer.
- Verified before archiving: `strings` on the Release binary returns **0**
  occurrences of "Pro (DEV)" / "Demand (DEV)" — the DEV toggles are `#if DEBUG`
  and genuinely absent from Release.
- 26 was cut specifically so the binary MATCHES the screenshots: it is the first
  build containing the splash jet icons, the Fleet/Marketplace filter + sort
  redesign, and the iPad-landscape map fix. **Do not submit build 25 with these
  screenshots** — its Fleet screen has no filter UI.

## Screenshots

Captured 18 July 2026 against build-26 code. Locations:

| Folder (under `~/Desktop/Airline Architect/App Store Screenshots/`) | Size | Notes |
|---|---|---|
| `iPhone/` | 1320×2868 | iPhone 6.9" — the size Apple actually requires |
| `iPhone-6.5in/` | 1284×2778 | Backup set, rescaled from the above; use only if ASC demands 6.5" |
| `iPad/` | 2064×2752 | iPad 13" |

20 per device (10 light + 10 dark). **ASC allows a maximum of 10 per display
size**, so a subset must be chosen. Recommended 10, in order:

1. `dark_02_network` · 2. `dark_03_marketplace` · 3. `dark_04_myfleet` ·
4. `dark_05_fleetdetail` · 5. `light_02_network` · 6. `dark_07_finance` ·
7. `dark_09_routepreview` · 8. `dark_06_ops` · 9. `dark_08_crews` ·
10. `light_01_naming`

The capture harness is documented in `CLAUDE.md` ("APP STORE SCREENSHOT
HARNESS") — the app-side seed is TEMPSHOT code that is deliberately never
committed.

## Store metadata (as drafted; the designer may have edited in ASC)

**Subtitle** (25/30): `Build your airline empire`

**Keywords** (exactly 100/100 — ASC's counter shows characters REMAINING, so
`0` there means full, not empty):
```
airline,tycoon,aviation,flight,simulator,management,strategy,routes,fleet,airport,business,transport
```
Deliberately excludes "Boeing", "Airbus", and any rival game's name —
trademarked keywords are a common first-submission rejection.

**Promotional text** (146/170):
```
New: turboprops for short island runways, plus hubs, lounges, and a redesigned marketplace. Start with one jet — see how far your network reaches.
```

**Description**: drafted in-session; opens "You start with $20 million and an
empty hangar." and covers real aircraft/tradeoffs, the 383-airport world, crews
and duty limits, the demand-driven economics, and hubs/clubs. The live copy is
whatever is in ASC — treat ASC as the source of truth for this one.

**Support URL**: https://spikeatone.github.io/airline-architect/
**Privacy Policy URL**: https://spikeatone.github.io/airline-architect/privacy.html

## The support/privacy site

- Public repo **`spikeatone/airline-architect`** (separate from this one), served
  by GitHub Pages from `main` / root. Two self-contained HTML files
  (`index.html`, `privacy.html`), no build step — edit and push to redeploy.
- Renders the real `AppLogo` vector paths (extracted from `AppLogo.swift`), so
  the mark stays crisp; if the logo ever changes, re-extract.
- Support page carries 6 FAQs written against real behavior (free-tier caps,
  Restore Purchases, iCloud sync, cancelling, the 3 save slots, and "why did my
  aircraft stop flying?" → crew duty limits).
- Privacy policy is accurate to the code: no accounts, no analytics, no ads, no
  tracking; saves are local + the user's own iCloud; **RevenueCat disclosed** as
  the one third party (anonymous ID + receipt). It must stay consistent with the
  ASC "Data Not Collected" declaration — change both together or neither.
- A local copy also sits in `~/Desktop/Airline Architect/Website/`.

## Subscriptions

Group **Airline Architect Pro** (ID 22234194), both products in "Prepare for
Submission":

| Level | Reference | Product ID | Duration | Price (intended) |
|---|---|---|---|---|
| 1 | Yearly | `yearly` | 1 year | $49.99 |
| 2 | Monthly | `monthly` | 1 month | $5.99 |

- **The product IDs matter**: `Store.swift` resolves them via RevenueCat as
  `offering.annual ?? package(identifier: "yearly")` (same for monthly). A
  rename in ASC breaks purchasing silently — the paywall would still show
  fallback prices but fail at purchase.
- Yearly at Level 1 is deliberate: both unlock identical functionality, so the
  level ordering only governs switching (Monthly→Yearly = immediate upgrade,
  Yearly→Monthly = at renewal).
- **No introductory offer / free trial is configured.** Considered, not done —
  a 7-day trial on annual is the obvious lever if conversion is weak, and
  RevenueCat picks it up with no code change.
- First-time subscriptions MUST be reviewed together with an app version; they
  cannot be submitted alone.

## ASC checklist

Done:
- [x] Build 26 uploaded and attached to iOS App Version 1.0
- [x] Description, keywords, promotional text, Support URL, copyright
- [x] **App Privacy** — questionnaire published as "Data Not Collected"
- [x] **Privacy Policy URL** added (App Privacy page → Privacy Policy → Edit;
      it is an APP-level field, not on the version page — easy to hunt for in
      the wrong place)
- [x] Both subscriptions + the group added to the draft submission
- [x] App version added to the submission → draft shows **4 items**
      (iOS App 1.0, the group, and Subscriptions (2)), warnings cleared

Outstanding at time of writing:
- [ ] **Screenshots uploaded** — were 0 of 10; use Media Manager → iPhone 6.9"
      and iPad 13" (the default drop zone offers 6.5", which the 1320×2868 files
      will not fit)
- [ ] **Reviewer notes** pasted into App Review Information → Notes (full text
      below)
- [ ] **Pricing and Availability** set to Free
- [ ] Choose **"Manually release this version"** so launch timing is controlled
- [ ] Uncheck **"Displayed"** on the App Store Promotion row (see below)
- [ ] Submit

## Reviewer notes (paste into App Review Information → Notes; 2,361 chars)

```
Airline Architect is a single-player airline management simulation. There is no
account system and no login, so no demo credentials are required — the app opens
directly into the game.

REACHING THE IN-APP PURCHASE

The app is free to play with the complete feature set. The free tier limits the
SIZE of the player's network rather than locking features:

  - Maximum 3 aircraft
  - Maximum 2 open routes

The subscription ("Airline Architect Pro", offered monthly or annually) removes
both limits. Three ways to reach the paywall:

  1. FASTEST — Finance tab (rightmost). In the "Your Plan" card, tap Upgrade.
     This opens the paywall directly, with no setup needed.

  2. Fleet tab > Marketplace. Tap "Buy new" on aircraft until 3 are owned;
     attempting a 4th opens the paywall. (Starting cash is $20M, so choose an
     inexpensive aircraft such as the Embraer ERJ135 — use the "RJ" category
     filter at the top of Marketplace.)

  3. Network tab > Open Route. After 2 routes are open, opening a 3rd shows
     the paywall.

"Restore Purchases" is at the bottom of the paywall screen.

FIRST LAUNCH

On first launch the app asks for an airline name, a 2-letter tail code, and a
starting region, then offers an optional 5-step walkthrough that can be skipped.

GAMEPLAY NOTES FOR TESTING

  - The simulation runs continuously and does not pause. Flights take several
    in-game hours, so aircraft will not appear to move much in real time.
    Use the speed control at the bottom of the Network tab (up to 25x) to
    advance time quickly and see revenue accumulate.
  - Aircraft need crew. If one sits at the gate, open the Crews tab and hire
    additional crew — crews follow real duty and rest limits, so a single
    crew cannot fly continuously. This is intended behavior, not a defect.
  - The map supports pan and pinch-to-zoom. Tapping an aircraft or airport
    opens its detail card.
  - Saved games sync across the user's own devices via iCloud key-value
    storage. No game data is transmitted to us, and there is no server.

PRIVACY

The app collects no personal data and contains no analytics or advertising
SDKs. RevenueCat is used solely to verify subscription status. This matches
the "Data Not Collected" declaration and the published privacy policy.

Thank you for reviewing. Any questions: postmarkdigitalco@gmail.com
```

Each section heads off a specific rejection: the Finance-tab path first (a
reviewer will not buy three aircraft to find the paywall — "could not locate the
IAP" is the likeliest rejection), Restore Purchases called out (Guideline
3.1.1), and the crew/time notes so intended behavior is not filed as a bug.
**Check the Finance card is still labelled "Your Plan"** before pasting — an
instruction that does not match the UI is worse than none.

## App Store Promotion — not used

ASC warns "these in-app purchases can't be promoted… your latest approved binary
doesn't include the required StoreKit APIs." That is the OPTIONAL promoted-IAP
feature (subscriptions purchasable from the App Store product page), which needs
`shouldAddStorePayment` / `PurchaseIntent` handling. **The app does not implement
it**, and there is no approved binary yet either way. It has zero effect on
in-app purchasing — just leave promotion off. If it is ever wanted, RevenueCat
exposes a delegate hook and the change is localized to `Store.swift`.

## Known open items (not blocking submission)

- **Restore Purchases shows no message when there is nothing to restore.** A
  real customer reinstalling would tap it and see silence. A fix was offered and
  not yet actioned — worth doing in a 1.0.1.
- The paywall's "There was a problem with the App Store" error seen during
  testing is expected until the subscriptions are approved; it is StoreKit's own
  string, not our bug. Re-verify with a **sandbox purchase on a real device**
  once they go live — that is the only definitive test.

## Remote control (workflow note, not a release item)

Claude Code Remote Control is **per-session and attached at launch** — an
existing session cannot gain it retroactively. Nothing is persisted in
`~/.claude/settings.json` (which holds only `enableWorkflows` and
`agentPushNotifEnabled`); the "enable by default" toggle lives in the Claude
desktop app's own settings. Start a session with `claude --remote-control [name]`,
or turn the default on in the app and start a NEW session. A phone error saying
to "reconnect or run remote control" generally means session-not-found, not an
auth failure.
