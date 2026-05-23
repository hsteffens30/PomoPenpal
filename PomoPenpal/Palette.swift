//
//  Palette.swift
//  PomoPenpal
//
//  The five locked colors from concept-and-implementation-plan.md §3 Decision #8.
//  Internal envelope SVG colors (#F9EEE3 flap, #E8D4BD address-lines) are part of
//  the SVGs themselves and intentionally not surfaced here.
//

import AppKit
import SwiftUI

enum Palette {
    static let cream       = Color(hex: 0xF7E9D9) // envelope + letter-edges + idle bg
    static let mutedRed    = Color(hex: 0xC45A5A) // work
    static let sage        = Color(hex: 0x6A9878) // short break
    static let dustyTeal   = Color(hex: 0x5A9490) // long break
    static let burntOrange = Color(hex: 0xC8622A) // postage stamp (used in Phase 2)

    static let creamNS      = NSColor(hex: 0xF7E9D9)
    static let mutedRedNS   = NSColor(hex: 0xC45A5A)
    static let sageNS       = NSColor(hex: 0x6A9878)
    static let dustyTealNS  = NSColor(hex: 0x5A9490)

    static let inkOnCream   = Color(red: 0.20, green: 0.18, blue: 0.16)
    static let inkOnCreamNS = NSColor(red: 0.20, green: 0.18, blue: 0.16, alpha: 1.0)

    static func background(for phase: TimerEngine.Phase) -> Color {
        switch phase {
        case .idle:       return cream
        case .working:    return mutedRed
        case .shortBreak: return sage
        case .longBreak:  return dustyTeal
        }
    }

    static func backgroundNS(for phase: TimerEngine.Phase) -> NSColor {
        switch phase {
        case .idle:       return creamNS
        case .working:    return mutedRedNS
        case .shortBreak: return sageNS
        case .longBreak:  return dustyTealNS
        }
    }

    static func ink(for phase: TimerEngine.Phase) -> Color {
        phase == .idle ? inkOnCream : cream
    }

    static func inkNS(for phase: TimerEngine.Phase) -> NSColor {
        phase == .idle ? inkOnCreamNS : creamNS
    }
}

extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

extension NSColor {
    convenience init(hex: UInt32) {
        let r = CGFloat((hex >> 16) & 0xFF) / 255.0
        let g = CGFloat((hex >> 8) & 0xFF) / 255.0
        let b = CGFloat(hex & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}
