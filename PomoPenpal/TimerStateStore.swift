//
//  TimerStateStore.swift
//  PomoPenpal
//
//  UserDefaults-backed snapshot/restore for the timer. Quitting and reopening
//  the app picks up at the same phase and remaining time. The restored state
//  always comes back paused — the user has to click Start to resume, matching
//  the locked "no auto-advance" decision (#10).
//
//  `completedInCycle` is deliberately NOT persisted — by design that counter
//  resets on every app launch (it represents "since opening the window").
//

import Foundation

enum TimerStateStore {
    private static let phaseKey      = "TimerState.phase"
    private static let secondsKey    = "TimerState.secondsRemaining"

    static func save(_ engine: TimerEngine) {
        let d = UserDefaults.standard
        d.set(rawValue(for: engine.phase), forKey: phaseKey)
        d.set(engine.secondsRemaining, forKey: secondsKey)
    }

    static func restore(into engine: TimerEngine) {
        let d = UserDefaults.standard
        // If we've never persisted, leave the engine at its default idle state.
        guard d.object(forKey: phaseKey) != nil else { return }
        engine.phase = phase(forRaw: d.string(forKey: phaseKey)) ?? .idle
        engine.secondsRemaining = max(0, d.integer(forKey: secondsKey))
        engine.isRunning = false  // always restore paused
        // completedInCycle stays at its initialized 0 — by design.
    }

    private static func rawValue(for phase: TimerEngine.Phase) -> String {
        switch phase {
        case .idle:       return "idle"
        case .working:    return "working"
        case .shortBreak: return "shortBreak"
        case .longBreak:  return "longBreak"
        }
    }

    private static func phase(forRaw raw: String?) -> TimerEngine.Phase? {
        switch raw {
        case "idle":       return .idle
        case "working":    return .working
        case "shortBreak": return .shortBreak
        case "longBreak":  return .longBreak
        default:           return nil
        }
    }
}
