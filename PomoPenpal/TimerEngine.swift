//
//  TimerEngine.swift
//  PomoPenpal
//

import Foundation

@Observable
final class TimerEngine {

    enum Phase {
        case idle
        case working
        case shortBreak
        case longBreak

        var label: String {
            switch self {
            case .idle:       return "Ready"
            case .working:    return "Work"
            case .shortBreak: return "Short Break"
            case .longBreak:  return "Long Break"
            }
        }

        var durationSeconds: Int {
            switch self {
            case .idle, .working: return 25 * 60
            case .shortBreak:     return 5 * 60
            case .longBreak:      return 15 * 60
            }
        }
    }

    var phase: Phase = .idle
    var secondsRemaining: Int = Phase.working.durationSeconds
    var isRunning: Bool = false
    /// Work sessions completed in the current Pomodoro cycle (0–4). Resets to 0
    /// after a long break finishes (i.e. when the next work phase is queued) and
    /// also resets on every app launch — it's a "this-cycle progress" indicator,
    /// not a lifetime counter.
    var completedInCycle: Int = 0

    var onTick: (() -> Void)?
    /// Fired exactly once each time a work session ends (work → break transition).
    /// Not fired when Skip is pressed from the idle state.
    var onWorkSessionComplete: ((Date) -> Void)?
    /// Fired after every state change. Currently unused — the host opens fresh
    /// on every launch by design — but left as a hook for any future host that
    /// wants to react to state transitions (e.g. analytics, persistence).
    var onStateChanged: (() -> Void)?

    private var timer: Timer?

    var formattedTime: String {
        let minutes = secondsRemaining / 60
        let seconds = secondsRemaining % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    func start() {
        if phase == .idle {
            phase = .working
            secondsRemaining = Phase.working.durationSeconds
        }
        isRunning = true
        startTicking()
        onTick?()
        onStateChanged?()
    }

    func pause() {
        isRunning = false
        stopTicking()
        onTick?()
        onStateChanged?()
    }

    func reset() {
        stopTicking()
        isRunning = false
        phase = .idle
        secondsRemaining = Phase.working.durationSeconds
        completedInCycle = 0
        onTick?()
        onStateChanged?()
    }

    func skip() {
        advance()
        isRunning = false
        stopTicking()
        onTick?()
        onStateChanged?()
    }

    private func startTicking() {
        stopTicking()
        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func stopTicking() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard isRunning else { return }
        if secondsRemaining > 0 {
            secondsRemaining -= 1
        } else {
            // Phase complete: queue up the next phase but stop ticking.
            // The user has to click Start to begin the next phase.
            advance()
            isRunning = false
            stopTicking()
        }
        onTick?()
        onStateChanged?()
    }

    private func advance() {
        let wasWorking = phase == .working
        switch phase {
        case .idle, .working:
            completedInCycle += 1
            phase = (completedInCycle >= 4) ? .longBreak : .shortBreak
        case .shortBreak:
            phase = .working
        case .longBreak:
            // Cycle complete — start the next one at zero.
            completedInCycle = 0
            phase = .working
        }
        secondsRemaining = phase.durationSeconds
        if wasWorking {
            onWorkSessionComplete?(Date())
        }
    }
}
