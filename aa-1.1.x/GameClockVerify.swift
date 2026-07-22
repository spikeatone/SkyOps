import Foundation

@MainActor
func run() {
    var pass = 0, fail = 0
    func check(_ c: Bool, _ m: String) { if c { pass += 1 } else { fail += 1; print("FAIL: \(m)") } }
    func monthIdx(_ s: String) -> Int {
        Simulation.monthAbbrev.firstIndex(of: String(s.split(separator: " ")[0])) ?? -1
    }

    // ---- 1-indexed Game Day + year in the date (default calendar, offset 0) ----
    check(Simulation.gameDay(at: 0) == 1, "Day 1 at start (1-indexed)")
    check(Simulation.gameDateString(at: 0) == "Jan 1, 2026", "start = Jan 1, 2026 (got \(Simulation.gameDateString(at: 0)))")
    check(Simulation.gameTimeString(at: 0) == "00:00", "time 00:00 at start")

    // Day 7 lines up with Jan 7 within the first month (1-indexed).
    check(Simulation.gameDay(at: 6 * 1440) == 7, "Day 7 at 6 days elapsed")
    check(Simulation.gameDateString(at: 6 * 1440) == "Jan 7, 2026", "Day 7 = Jan 7, 2026")

    // Specific time: Day 4, 14:32
    let t = 3 * 1440 + 14 * 60 + 32
    check(Simulation.gameDay(at: t) == 4, "Day 4")
    check(Simulation.gameDateString(at: t) == "Jan 4, 2026", "Jan 4, 2026")
    check(Simulation.gameTimeString(at: t) == "14:32", "time 14:32 (got \(Simulation.gameTimeString(at: t)))")

    // Month rollover: 35 days in -> Feb 6, Day 36
    check(Simulation.gameDay(at: 35 * 1440) == 36, "Day 36 at 35 days")
    check(Simulation.gameDateString(at: 35 * 1440) == "Feb 6, 2026", "Feb 6, 2026 (got \(Simulation.gameDateString(at: 35 * 1440)))")

    // Year rollover at 360 days -> Jan 1, 2027, Day 361
    check(Simulation.gameDateString(at: 360 * 1440) == "Jan 1, 2027", "year rolls to 2027 (got \(Simulation.gameDateString(at: 360 * 1440)))")
    check(Simulation.gameDay(at: 360 * 1440) == 361, "Day 361 at day-360 boundary")

    // Time edges
    check(Simulation.gameTimeString(at: 23 * 60 + 59) == "23:59", "23:59 edge")
    check(Simulation.gameTimeString(at: 5 * 60) == "05:00", "05:00 zero-pad")

    // ---- Randomized calendar start (per new game) ----
    // A non-zero start offset shifts the DATE + season, not Game Day or the clock.
    check(Simulation.gameDay(at: 0) == 1, "Game Day is offset-independent (still Day 1)")
    check(Simulation.gameDateString(at: 0, startDay: 200) == "Jul 21, 2026", "offset 200 -> Jul 21, 2026 (got \(Simulation.gameDateString(at: 0, startDay: 200)))")
    check(Simulation.gameDateString(at: 6 * 1440, startDay: 200) == "Jul 27, 2026", "6 days after Jul 21 = Jul 27")
    check(Simulation.gameStartYear == 2026, "start year 2026")

    // The date's month ALWAYS equals the seasonal monthOfYear, even with a random
    // start — so the displayed date can't drift from the weather model.
    let sim = Simulation()
    sim.configure(viewport: CGSize(width: 400, height: 800))
    sim.randomizeCalendarStart()
    let sd = sim.calendarStartDay
    check(sd >= 0 && sd < 360, "randomized start in [0,360) (got \(sd))")
    var mism = 0
    for _ in 0..<6 {
        if monthIdx(Simulation.gameDateString(at: sim.tick, startDay: sd)) != sim.monthOfYear { mism += 1 }
        for _ in 0..<(23 * 1440) { sim.advanceTick() }   // advance ~23 days
    }
    check(mism == 0, "random-offset date month == seasonal monthOfYear across the year (\(mism) mismatches)")

    // Persistence round-trip of the offset + legacy default.
    let snap = sim.snapshot()
    let data = try! JSONEncoder().encode(snap)
    let restored = Simulation(); restored.configure(viewport: CGSize(width: 400, height: 800))
    restored.restore(from: try! JSONDecoder().decode(GameSnapshot.self, from: data))
    check(restored.calendarStartDay == sd, "calendarStartDay persists (\(restored.calendarStartDay) == \(sd))")
    var obj = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
    obj.removeValue(forKey: "calendarStartDay")   // simulate a pre-feature save
    let legacy = try? JSONDecoder().decode(GameSnapshot.self, from: try! JSONSerialization.data(withJSONObject: obj))
    check(legacy?.calendarStartDay == 0, "legacy save (no offset) -> 0 (Jan start)")

    // Default-0 invariant still holds over 3 sim-years (unchanged behavior).
    var mismatches = 0
    for day in stride(from: 0, to: 360 * 3, by: 1) {
        let tk = day * 1440 + 720
        if monthIdx(Simulation.gameDateString(at: tk)) != (tk / 43200) % 12 { mismatches += 1 }
    }
    check(mismatches == 0, "default-calendar date month == seasonal month, 1080 days (\(mismatches) off)")

    print("\n\(pass)/\(pass + fail) checks passed" + (fail == 0 ? " — ALL GREEN" : " — \(fail) FAILED"))
}
MainActor.assumeIsolated { run() }
