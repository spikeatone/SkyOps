# App Store Description — Airline Architect (1.1 / build 33)

Paste the text between the lines into App Store Connect → App Information →
Description. App Store descriptions render as PLAIN TEXT (no markdown), so this
uses ALL-CAPS section headers + blank lines + • bullets for structure. Brand-safe:
no trademarked aircraft/airline names (same reason Boeing/Airbus are out of the
keywords). ~1,750 characters (limit is 4,000). "Build the sky." is a placeholder
closer — swap it for your own line if you'd rather.

Keep ASC as the source of truth for the LIVE copy; this file is just the draft.

------------------------------------------------------------------------------
You start with $20 million and an empty hangar. Where you take it is up to you.

Airline Architect is a deep, realistic airline-management sim. Buy or lease your fleet, open routes across a living world of real airports, hire crews, and grow a one-plane startup into a global carrier — while the simulation never pauses for anyone.

MATCH THE RIGHT AIRCRAFT TO THE RIGHT MARKET
A genuine passenger-demand model makes route selection the whole game — a big jet on a thin route flies half-empty, and a small one leaves money on the table. Thirty-plus real-world aircraft, from short-field turboprops to the largest widebodies, each with real range, capacity, and economics.

RUN A REAL OPERATION
• Own your fleet — buy new, lease, or hunt the used-aircraft market. Every airframe ages, and old metal costs more to keep flying.
• Crews follow real duty and rest limits — one crew can't fly forever, so staffing is a genuine decision.
• Weather, mechanical failures, and crew shortages surface as live choices you resolve while every other aircraft keeps flying. The clock never stops.

GO DEEP, NOT JUST WIDE
• Establish hubs and build airport clubs to fortify a city, hold off competitors, and build loyalty — with a live payback view so you know if it's working.
• Fund expansion with loans — or take your airline public, with a live share price, activist investors, and a board that can vote you out.
• Reached the top? Scout rival carriers and acquire them — then survive the messy integration.

A WORLD THAT FEELS ALIVE
• 380+ real airports across the Americas, Europe, Africa, Asia, and the Pacific — including exotic island strips only the right aircraft can reach.
• Real seasons — hurricane season, winter storms, and monsoon shape where and when disruptions strike.
• A day/night line sweeps across the map, and real airport night curfews close cities to late departures — a real cost of flying there.
• Rival carriers contest your most profitable routes and fly fleets true to the real world.

Speed time up to 25×, watch the revenue roll in, and keep the whole network flying.

Build the sky.
------------------------------------------------------------------------------


# Promotional Text (ASC → App Information → Promotional Text)

170-char max. Appears ABOVE the description and can be edited ANY time WITHOUT a
new review — good for rotating a hook. This one is ~156 chars.

------------------------------------------------------------------------------
One jet and $20M. Grow a global airline in a living world of real airports and aircraft — build hubs, ride the seasons, take it public, or buy out your rivals.
------------------------------------------------------------------------------


# What's New / Version release notes (ASC → the version's "What's New" field)

PUBLIC-FACING. New users never experienced any bug, so this stays positive and
never advertises a fix — the save reliability is framed as a benefit. For a FIRST
public release the App Store shows the Description over this field; it becomes
prominent on the first UPDATE. ~470 chars.

------------------------------------------------------------------------------
Welcome to Airline Architect — grow a global airline from a single jet.

• 380+ real airports and 30+ real-world aircraft in a living world
• Match aircraft to markets with a real passenger-demand model
• Grow deep: hubs, airport lounges, loans, IPOs, and rival buyouts
• Real seasons, a day/night map, and real airport night curfews
• Crews with real duty limits — and the clock never stops
• Progress saves automatically and syncs across your devices

Feedback is always welcome. Happy flying.
------------------------------------------------------------------------------


# What to Test (ASC → TestFlight → build 33 → "What to Test")

TESTER-FACING (not public). Existing testers HAVE hit the save loss, so this is
direct about the fix and exactly what to exercise. ~1,050 chars.

------------------------------------------------------------------------------
Build 33 — the headline fix is SAVED GAMES SURVIVING APP UPDATES.

If you've ever installed a new build and found your airline gone, this is the fix. From this build on, updating will not lose your save.

Please test:
• Update to this build over your existing one, then open the app — your airline(s) should still be in the load menu and open normally, with your cash, fleet, and routes intact.
• Play a bit, then Quit or background the app and relaunch — confirm nothing is lost.
• If an earlier build made an airline "disappear" and you did NOT start a new game over that slot, it may reappear now — please tell us if it does.
• New airport: Glasgow (GLA), Scotland — open a route to it and check it on the map.
• Map polish: weather icons now sit just below an affected airport, and a day/night line sweeps the map — do these read clearly?

Honest note: if an earlier build already lost a game AND you started a new airline in that slot, that one can't be recovered — but it won't happen again.

Thanks as always — reply in TestFlight with anything that feels off.
------------------------------------------------------------------------------


# App Review Information → Notes (reviewer notes)

Supersedes the 1.0 draft in RELEASE_STATUS.md. Updated for 1.1 (build 32): the
Finance plan card is now labelled "FREE PLAN" (was "Your Plan") and lives under
the Finance tab's REPORTS view, which is shown by default. ~2,300 chars.

------------------------------------------------------------------------------
Airline Architect is a single-player airline-management simulation. There is no
account system and no login, so no demo credentials are required — the app opens
directly into the game.

REACHING THE IN-APP PURCHASE

The app is free to play with the complete feature set. The free tier limits the
SIZE of the player's network rather than locking features:

  - Maximum 3 aircraft
  - Maximum 2 open routes

The subscription ("Airline Architect Pro", offered monthly or annually) removes
both limits. Three ways to reach the paywall:

  1. FASTEST — Finance tab (rightmost). It opens on the "REPORTS" view, which
     shows a "FREE PLAN" card at the top with a live usage count and an "Upgrade"
     button. Tapping Upgrade opens the paywall directly, with no setup needed.

  2. Fleet tab > Marketplace. Tap "Buy new" on aircraft until 3 are owned;
     attempting a 4th opens the paywall. (Starting cash is $20M, so choose an
     inexpensive aircraft — use the "RJ" category filter at the top of the
     Marketplace, or a turboprop.)

  3. Network tab > Open Route. After 2 routes are open, opening a 3rd shows the
     paywall.

"Restore Purchases" is at the bottom of the paywall screen.

FIRST LAUNCH

On first launch the app asks for an airline name, a 2-letter tail code, and a
starting region, then offers an optional walkthrough that can be skipped.

GAMEPLAY NOTES FOR TESTING

  - The simulation runs continuously and does not pause. Flights take several
    in-game hours, so aircraft will not appear to move much in real time. Use the
    speed control at the bottom of the Network tab (up to 25x) to advance time
    quickly and see revenue accumulate.
  - Aircraft need crew. If one sits idle at the gate, open the Crews tab and hire
    additional crew — crews follow real duty and rest limits, so a single crew
    cannot fly continuously. This is intended behavior, not a defect.
  - The map supports pan and pinch-to-zoom. Tapping an aircraft or airport opens
    its detail card.
  - Saved games sync across the user's own devices via iCloud key-value storage.
    No game data is transmitted to us, and there is no server.

REAL-WORLD REFERENCES

The app references real airports, aircraft types, and airline names as factual
reference data for the simulation (text only — no logos, liveries, or branding,
and no affiliation or endorsement is implied).

PRIVACY

The app collects no personal data and contains no analytics or advertising SDKs.
RevenueCat is used solely to verify subscription status. This matches the "Data
Not Collected" declaration and the published privacy policy.

Thank you for reviewing. Any questions: postmarkdigitalco@gmail.com
------------------------------------------------------------------------------


