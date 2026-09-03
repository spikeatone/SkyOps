# NEXT SESSION PROMPT

Paste the block below into a fresh session. Everything above the line is context
for whoever is doing the pasting; the block itself is written to be understood
cold, with no memory of this conversation.

**Read first:** `HANDOFF.md` (one-read orientation) → `CLAUDE.md` (the persistent
design/technical record; it wins on any disagreement).

_Written 3 September 2026, at the end of the session that built the rest of 1.7 and MERGED
everything to `main`: the MX expanded-Details view + like-size route-coverage flow (Details →
cover with a comparable spare / acquire one / suspend the route; C/D forced-grounding fixed to a
sane calendar grace), the auto-slow alert banner (persists until tapped), the on-brand Figma
milestone/banner icons, real-launch-date game start, German for all the new strings, and the
next-75 airport-hero prompt table. The MX program itself + the 3 player-feedback fixes were
already on `main`. **1.7 is fully built + merged; the next session SHIPS it (version bump →
archive → upload → submit).**_

---

## The prompt

> You're picking up **Airline Architect** (repo dir is `SkyOps`; the app was renamed).
> Read `HANDOFF.md` first, then `CLAUDE.md`. Tree is clean on `main`, all pushed.
>
> **RELEASE STATE (verify, don't trust this snapshot):**
> `cd ~/Architect\ Universe/PostmarkOps/ASCTools && python3 asc.py GET "/v1/apps/6790569697/appStoreVersions?limit=3"`
> - **1.6.0 (build 55) is LIVE** (`READY_FOR_SALE`) — German localization + 43 city hero
>   images + per-achievement Game Center icons. Cleared 4.3(a) (the artwork made it a real
>   content update, not localization-only). Next new build = **56+**.
> - ⚠️ **App Review 4.3(a) is account-wide** — every submission leads its App Review notes with
>   the §1 studio-context block. Reuse `aa-1.1.x/app-review-notes-1.5.0.txt` (or `-1.4.3`), bump
>   the version line. Playbook: `PostmarkOps/APP_REVIEW_NOTES.md`.
>
> **YOUR JOB: SHIP 1.7. Everything is built + merged to `main`, tree clean, all pushed.** The
> task is the release chain — no new features unless the designer asks. Order:
>
> 1. **(optional, ~10 min) A quick confidence drive** — the 1.7 feature set was driven live piece
>    by piece with the designer, but not as one final pass on the merged `main` build. If you want
>    one: `xcodebuild` Debug, launch `-devScenario mx`, and glance at OPS ▸ MX (Details → cover /
>    acquire / suspend), set 100× and let an event fire (auto-slow banner + gauge icon), and open a
>    couple of milestone toasts if you can trigger them (on-brand icons). All harness-verified, so
>    this is a look-not-verify pass. Skip if you're confident.
>
> 2. **⭐ CUT THE BUILD — bump to 1.7.0 / build 56 and upload.** Real content release (MX +
>    coverage + new-game date + icons = user-facing), so it's a MINOR bump (1.6.0 → **1.7.0**), not
>    a patch. Steps (the release chain is scriptable end-to-end — see CLAUDE.md "upload is
>    SCRIPTABLE" + `PostmarkOps/ARCHITECT_FAMILY.md` §4):
>    - Bump `MARKETING_VERSION` 1.6.0 → **1.7.0** AND `CURRENT_PROJECT_VERSION` 55 → **56** in the
>      pbxproj (**6 configs each** — grep to confirm you got all).
>    - `xcodebuild archive` → `-exportArchive` (method=app-store-connect, teamID=D2PVU8X5Q7,
>      signingStyle=automatic, `-allowProvisioningUpdates`, ASC key `25FXKWL48U` /issuer
>      `55d522ad-1376-4704-a13d-3961750a4327`, key staged at
>      `~/.appstoreconnect/private_keys/AuthKey_25FXKWL48U.p8`) → `altool --validate-app` →
>      `altool --upload-app`. A build takes ~5 min to appear in `asc.py builds 6790569697`.
>    - Then the ASC record (designer-side steps, but you can do the API parts): create the **1.7**
>      version record, attach build 56, set What's New (lead with MX maintenance + the coverage
>      flow), and paste the **§1 4.3(a) studio-context block** into App Review notes — reuse
>      `aa-1.1.x/app-review-notes-1.5.0.txt` (or `-1.6.0`), just bump the version line. Submit.
>    - ⚠️ **Game Center per-version checkbox:** ASC refuses to submit a GC-entitlement build until
>      the version's Game Center checkbox is enabled — `POST /v1/gameCenterAppVersions` (relationship
>      appStoreVersion). Do it for 1.7 like every prior GC build.
>
> 3. **IF the designer's 50 new hero images landed** (`aa-1.1.x/HERO-PROMPTS-75.md` is the list;
>    they stage them in `Resources/Airport Photos/<City>.jpg`) — **bundle them BEFORE cutting the
>    build**: copy each to `AirlineArchitect/AirlineArchitect/Resources/AirportPhotos/airport_<CODE>.jpg`
>    (synchronized group auto-bundles on next build), then re-run `aa-1.1.x/archetype-audit` (add each
>    new CODE to `bundled`) to confirm. +50 heroes ≈ +20 MB → ~88 MB download, still fine (JPGs are
>    ~45% of the download and don't thin further). If they DIDN'T land, ship 1.7 without them; they
>    become a fast follow-up content update.
>
> **DON'T:** ship anything standalone-trivial during the account-wide 4.3(a) cascade — 1.7 is a real
> content release so it's safe, but the §1 studio block is still mandatory. Don't revive the SHELVED
> PM budget (`maint-budget-t22`) — MX supersedes it.
>
> **After 1.7 is live — monetization signals** (give ~2 weeks): RevenueCat trial→paid conversion +
> TelemetryDeck `Paywall.shown ÷ Game.started` (production view = Test Mode OFF) + the `hang.under3s`
> count trend (the 1.4.2/1.4.3 + build-at-occurrence-tag fixes should show in it now).
>
> **THE STANDING CONCERN:** the UI/"does it feel right" half no harness reaches. It found the
> ASSIGN-TO-NEW-ROUTE no-op + the SLC-artwork bug in past sessions; it keeps paying. Drive the
> app.
>
> **HOW THIS CODEBASE VERIFIES (don't skip):** every sim change gets a headless harness in
> `aa-1.1.x/` (compile the real `Sim/*.swift` with `swiftc`, excluding AircraftIcon/SVGPath and
> adding `RepaintVerifyStubs.swift`; entry file MUST be `main.swift`) + the soak
> (`SoakMain.swift`, ~6–8 min) + `RoundTripVerify.swift` (save-path) + a Debug `xcodebuild` + a
> live Simulator drive of any new UI. **German:** the app ships `de` on `main` — any NEW
> user-facing string needs a translation; the ONLY reliable gap check is
> `DD=<derivedDataRoot> python3 aa-1.1.x/de-findgaps.py` after a Debug build (scans ALL
> stringsdata; a `de.lproj` `de==en` diff and a hand-picked file list both MISS category-2
> gaps — a String reaching `Text` via a var/param/concatenation bypasses the catalog).
>
> **Simulator warnings:** tap coordinates are in POINTS (402×874 iPhone 17 Pro / 440×956 Pro Max),
> not screenshot pixels; the input channel degrades mid-session — re-screenshot before concluding
> a control is broken, a fresh `simctl launch` (or killing CoreSimulator + rebooting one device)
> clears a wedge, and terminate sibling Architect apps that steal focus; LANDSCAPE captures come
> out rotated (`sips -r 90`/`-r 270`). The `-devScenario` harness
> (`publicGate|listed|activist|ouster|fleet|bigfleet|legacyPlayer|subfleet|mx`) seeds otherwise-
> unreachable states (`mx` = a routed fleet staged at distinct MX due-states — A due, A overdue,
> C due, D due — with idle spares + a widebody D-check to exercise the C/D coverage flow).

---

## Useful commands

```bash
# review status
cd ~/Architect\ Universe/PostmarkOps/ASCTools && python3 asc.py GET "/v1/apps/6790569697/appStoreVersions?limit=3"

# headless harness pattern (entry file MUST be main.swift; ~30s compile under -O)
cd AirlineArchitect/AirlineArchitect
cp ../../aa-1.1.x/MXProbe.swift /tmp/main.swift      # or RoundTripVerify / SoakMain / AutoSlowVerify
swiftc -O -DDEBUG $(ls Sim/*.swift | grep -vE 'AircraftIcon.swift|SVGPath.swift') \
  Persistence.swift ../../aa-1.1.x/RepaintVerifyStubs.swift /tmp/main.swift -o /tmp/run && /tmp/run

# German gap scan (the ONLY reliable category-2 check — after a Debug build)
DD=<your -derivedDataPath root> python3 aa-1.1.x/de-findgaps.py

# release chain is scriptable end-to-end (see CLAUDE.md "upload is SCRIPTABLE"):
#   xcodebuild archive → -exportArchive → altool --validate-app → altool --upload-app
```
