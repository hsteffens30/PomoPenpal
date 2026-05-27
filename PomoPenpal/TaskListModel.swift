//
//  TaskListModel.swift
//  PomoPenpal
//
//  Session-local task list shown on the timer page. Up to 3 slots; the second
//  and third only appear after the user presses Enter from a non-empty slot.
//  Marking a task done runs the green-stamp animation in the view, then
//  removes the slot here so the next one slides up.
//
//  Deliberately NOT persisted — tasks vanish on app quit by design. State
//  survives page swaps inside the window because AppDelegate owns the model
//  for the app's lifetime.
//

import Foundation
import Observation

@Observable
final class TaskListModel {

    struct Task: Identifiable, Equatable {
        let id: UUID
        var title: String
        /// When true the row is fading out; the model removes it shortly after.
        var isCompleting: Bool

        init(id: UUID = UUID(), title: String = "", isCompleting: Bool = false) {
            self.id = id
            self.title = title
            self.isCompleting = isCompleting
        }
    }

    /// Tasks in display order. Always has at least one slot so the input is
    /// never absent from the page.
    private(set) var tasks: [Task] = [Task()]

    /// How long the stamp stays visible before the row begins fading out.
    /// View-side animations use this so the timing reads as: tap → stamp
    /// scales in → brief pause → row fades.
    static let stampHoldDuration: TimeInterval = 0.55
    /// Fade duration of the row after the stamp dismisses.
    static let fadeOutDuration: TimeInterval = 0.35

    func update(taskID: UUID, title: String) {
        guard let idx = tasks.firstIndex(where: { $0.id == taskID }) else { return }
        tasks[idx].title = title
    }

    /// Called when the user submits (Enter) from a row. Appends a new empty
    /// slot if the submitting row has content and the cap (3) isn't reached.
    /// Returns the new slot's id, or nil if no slot was added.
    @discardableResult
    func handleSubmit(from taskID: UUID) -> UUID? {
        guard let idx = tasks.firstIndex(where: { $0.id == taskID }) else { return nil }
        guard !tasks[idx].title.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        guard tasks.count < 3 else { return nil }
        let new = Task()
        tasks.append(new)
        return new.id
    }

    /// Remove a slot. If this would leave the list empty, re-seed an empty slot
    /// so the input never disappears entirely.
    func removeSlot(taskID: UUID) {
        tasks.removeAll { $0.id == taskID }
        if tasks.isEmpty {
            tasks.append(Task())
        }
    }

    /// Mark a task done. View animates the stamp first; we set isCompleting so
    /// the row fades, then drop it from the array after a short delay.
    func markDone(taskID: UUID) {
        guard let idx = tasks.firstIndex(where: { $0.id == taskID }) else { return }
        tasks[idx].isCompleting = true
        let removalDelay = Self.fadeOutDuration + 0.05
        DispatchQueue.main.asyncAfter(deadline: .now() + removalDelay) { [weak self] in
            self?.removeSlot(taskID: taskID)
        }
    }
}
