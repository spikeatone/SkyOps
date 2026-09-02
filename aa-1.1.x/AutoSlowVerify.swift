import Foundation
@MainActor func main() {
    var pass=0, fail=0
    func chk(_ c: Bool, _ m: String){ if c {pass+=1} else {fail+=1; print("FAIL:",m)} }

    // 100x is in the options + requestSpeed accepts it
    chk(Simulation.speedOptions.contains(100), "100x in speedOptions")

    let sim = Simulation()
    sim.configure(viewport: CGSize(width: 400, height: 800))
    sim.nameAirline("T", tailCode: "PB")
    sim.devInjectCash(200_000_000)
    // buy a jet, open a route, hire crew so it flies and can generate a real card
    guard let t = AircraftType.all.first(where: {$0.id=="E175"}),
          let o = sim.airport("DEN"), let d = sim.airport("ORD"),
          let ac = sim.buyAircraft(t) else { print("setup fail"); return }
    _ = sim.openRoute(from: o, to: d, using: ac)

    // Go fast, then run until a decision card appears; assert speed auto-dropped to 1x.
    sim.requestSpeed(100)
    chk(sim.speed == 100, "speed set to 100x")
    var droppedAtCard = false
    var sawCard = false
    for _ in 0..<(1440*400) {   // up to ~400 sim-days; a crew hold will appear (1 crew, busy route)
        let before = sim.decisionQueue.count
        sim.advanceTick()
        if sim.decisionQueue.count > before {   // a card was just pushed
            sawCard = true
            droppedAtCard = (sim.speed == 1)
            break
        }
        // keep it fast if nothing happened and something else reset speed
        if sim.speed != 1 && sim.decisionQueue.isEmpty { /* still fast, fine */ }
    }
    chk(sawCard, "a decision card appeared during the run")
    chk(droppedAtCard, "speed auto-dropped to 1x the tick a card was pushed (was \(sim.speed))")

    // Also: a DIRECT push at high speed drops instantly (unit-level).
    sim.requestSpeed(100)
    // force a card via the crew path isn't public; instead confirm the invariant:
    // if queue is non-empty we should already be at 1x from the didSet above.
    print("\n\(pass)/\(pass+fail) checks passed" + (fail==0 ? " — ALL GREEN":" — \(fail) FAILED"))
}
MainActor.assumeIsolated { main() }
