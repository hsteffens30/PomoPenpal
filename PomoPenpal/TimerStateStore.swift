//
//  TimerStateStore.swift
//  PomoPenpal
//
//  Earlier iterations persisted a snapshot of the running timer (phase +
//  remaining seconds) to UserDefaults so quitting and reopening would resume
//  mid-cycle. The current design opens to a fresh idle page on every launch
//  by request, so save/restore is no longer wired up.
//
//  The legacy keys are removed on launch via `clearPersistedTimerState()` so
//  no stale data sticks around in UserDefaults for users upgrading from an
//  older build. Persisted SwiftData (letters in the album) is separate and
//  unaffected.
//

import Foundation

enum TimerStateStore {
    private static let phaseKey      = "TimerState.phase"
    private static let secondsKey    = "TimerState.secondsRemaining"
    // Older builds also wrote this — clear it on launch for users upgrading.
    private static let legacyCompletedKey = "TimerState.completedWorkSessions"

    static func clearPersistedTimerState() {
        let d = UserDefaults.standard
        d.removeObject(forKey: phaseKey)
        d.removeObject(forKey: secondsKey)
        d.removeObject(forKey: legacyCompletedKey)
    }
}
