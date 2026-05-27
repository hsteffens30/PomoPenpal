//
//  TaskListModel.swift
//  PomoPenpal
//
//  Session-local single task shown on the timer page. Marking it done plays
//  the green-stamp animation and resets the slot to empty.
//
//  Deliberately NOT persisted — the task vanishes on app quit by design.
//  State survives page swaps inside the window because AppDelegate owns the
//  model for the app's lifetime.
//

import Foundation
import Observation

@Observable
final class TaskListModel {

    struct Task: Identifiable, Equatable {
        let id: UUID
        var title: String
        /// When true the row is fading out; the model resets it shortly after.
        var isCompleting: Bool

        init(id: UUID = UUID(), title: String = "", isCompleting: Bool = false) {
            self.id = id
            self.title = title
            self.isCompleting = isCompleting
        }
    }

    /// The one and only task slot. Single-task mode by design — no list,
    /// no row additions, no shifting.
    private(set) var task: Task = Task()

    /// How long the stamp stays visible before the row begins fading out.
    static let stampHoldDuration: TimeInterval = 0.55
    /// Fade duration of the row after the stamp dismisses.
    static let fadeOutDuration: TimeInterval = 0.35

    func update(title: String) {
        task.title = title
    }

    /// Clear the task back to empty (used by the × button).
    func clear() {
        task = Task()
    }

    /// Mark the task done. View animates the stamp first; we set isCompleting
    /// so the row fades, then reset to a fresh empty slot after a short delay.
    func markDone() {
        task.isCompleting = true
        let removalDelay = Self.fadeOutDuration + 0.05
        DispatchQueue.main.asyncAfter(deadline: .now() + removalDelay) { [weak self] in
            self?.task = Task()
        }
    }
}
