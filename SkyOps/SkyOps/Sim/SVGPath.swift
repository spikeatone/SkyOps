//
//  SVGPath.swift
//  SkyOps — Phase 2
//
//  Minimal SVG path-data parser → SwiftUI Path. Enough to render the real
//  Figma-sourced aircraft icons, whose `d` strings use M/L/H/V/C/Z (absolute
//  and relative) with space/comma/implicit separators and scientific-notation
//  numbers (e.g. "4.81784e-06"). Not a full SVG spec implementation — no arcs
//  (A) or smooth/quadratic shorthands (S/Q/T), which these icons don't use.
//

import SwiftUI

enum SVGPath {

    static func parse(_ d: String) -> Path {
        var path = Path()
        let chars = Array(d)
        var i = 0
        var cur = CGPoint.zero      // current point
        var startPt = CGPoint.zero  // subpath start (for Z)

        func isSep(_ c: Character) -> Bool { c == " " || c == "," || c == "\n" || c == "\t" || c == "\r" }
        func skipSeps() { while i < chars.count && isSep(chars[i]) { i += 1 } }

        func peekIsNumberStart() -> Bool {
            skipSeps()
            guard i < chars.count else { return false }
            let c = chars[i]
            return c.isNumber || c == "+" || c == "-" || c == "."
        }

        func readNumber() -> Double? {
            skipSeps()
            var s = ""
            if i < chars.count && (chars[i] == "+" || chars[i] == "-") { s.append(chars[i]); i += 1 }
            while i < chars.count && chars[i].isNumber { s.append(chars[i]); i += 1 }
            if i < chars.count && chars[i] == "." {
                s.append("."); i += 1
                while i < chars.count && chars[i].isNumber { s.append(chars[i]); i += 1 }
            }
            if i < chars.count && (chars[i] == "e" || chars[i] == "E") {
                s.append("e"); i += 1
                if i < chars.count && (chars[i] == "+" || chars[i] == "-") { s.append(chars[i]); i += 1 }
                while i < chars.count && chars[i].isNumber { s.append(chars[i]); i += 1 }
            }
            return Double(s)
        }

        func num() -> CGFloat { CGFloat(readNumber() ?? 0) }

        while i < chars.count {
            skipSeps()
            guard i < chars.count else { break }
            let cmd = chars[i]
            guard cmd.isLetter else { i += 1; continue }
            i += 1
            let relative = cmd.isLowercase

            switch Character(cmd.uppercased()) {
            case "M":
                var p = CGPoint(x: num(), y: num())
                if relative { p = CGPoint(x: cur.x + p.x, y: cur.y + p.y) }
                path.move(to: p); cur = p; startPt = p
                // subsequent coordinate pairs are implicit L commands
                while peekIsNumberStart() {
                    var q = CGPoint(x: num(), y: num())
                    if relative { q = CGPoint(x: cur.x + q.x, y: cur.y + q.y) }
                    path.addLine(to: q); cur = q
                }
            case "L":
                repeat {
                    var p = CGPoint(x: num(), y: num())
                    if relative { p = CGPoint(x: cur.x + p.x, y: cur.y + p.y) }
                    path.addLine(to: p); cur = p
                } while peekIsNumberStart()
            case "H":
                repeat {
                    let x = num()
                    let p = CGPoint(x: relative ? cur.x + x : x, y: cur.y)
                    path.addLine(to: p); cur = p
                } while peekIsNumberStart()
            case "V":
                repeat {
                    let y = num()
                    let p = CGPoint(x: cur.x, y: relative ? cur.y + y : y)
                    path.addLine(to: p); cur = p
                } while peekIsNumberStart()
            case "C":
                repeat {
                    var c1 = CGPoint(x: num(), y: num())
                    var c2 = CGPoint(x: num(), y: num())
                    var end = CGPoint(x: num(), y: num())
                    if relative {
                        c1 = CGPoint(x: cur.x + c1.x, y: cur.y + c1.y)
                        c2 = CGPoint(x: cur.x + c2.x, y: cur.y + c2.y)
                        end = CGPoint(x: cur.x + end.x, y: cur.y + end.y)
                    }
                    path.addCurve(to: end, control1: c1, control2: c2); cur = end
                } while peekIsNumberStart()
            case "Z":
                path.closeSubpath(); cur = startPt
            default:
                // unsupported command — skip its numbers to stay in sync
                while peekIsNumberStart() { _ = readNumber() }
            }
        }
        return path
    }
}
