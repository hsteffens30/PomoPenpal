//
//  TaskListView.swift
//  PomoPenpal
//
//  Single-task input shown between the phase label and the timer. Tapping
//  the check-circle slaps a small green postage-stamp onto the circle's
//  position and fades the row out.
//

import SwiftUI

struct TaskListView: View {
    let model: TaskListModel
    let phase: TimerEngine.Phase
    /// Focus is owned by the parent (TimerView) so clicking outside the field
    /// elsewhere on the timer page can dismiss it.
    var focusBinding: FocusState<Bool>.Binding

    /// Local animation state for the slap-in stamp.
    @State private var stampVisible: Bool = false

    private var task: TaskListModel.Task { model.task }

    private var hasContent: Bool {
        !task.title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var ink: Color { Palette.ink(for: phase) }

    var body: some View {
        HStack(spacing: 6) {
            // Check circle: only enabled when there's content and we're not
            // already mid-animation. The stamp overlay covers this spot when
            // the user marks the task done.
            Button(action: handleCheckTap) {
                ZStack {
                    Image(systemName: "circle")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(ink.opacity(hasContent ? 0.65 : 0.3))
                        .opacity(stampVisible ? 0 : 1)
                    if stampVisible {
                        GreenDoneStamp()
                            .transition(.scale(scale: 0.25).combined(with: .opacity))
                    }
                }
                .frame(width: 18, height: 18)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!hasContent || stampVisible || task.isCompleting)

            TextField("What's the goal for this session?", text: Binding(
                get: { task.title },
                set: model.update(title:)
            ))
            .textFieldStyle(.plain)
            .font(.system(size: 11, weight: .regular))
            .foregroundStyle(ink.opacity(0.9))
            .tint(ink)
            .focused(focusBinding)
            .onSubmit { focusBinding.wrappedValue = false }
            .disabled(task.isCompleting)

            if hasContent {
                Button(action: model.clear) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(ink.opacity(0.4))
                        .frame(width: 12, height: 12)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(stampVisible || task.isCompleting)
            } else {
                // Reserve the same horizontal space so the text field doesn't
                // jump width when × appears or disappears.
                Color.clear.frame(width: 12, height: 12)
            }
        }
        .padding(.horizontal, 6)
        .frame(height: 20)
        .opacity(task.isCompleting ? 0 : 1)
        .animation(.easeOut(duration: TaskListModel.fadeOutDuration), value: task.isCompleting)
    }

    private func handleCheckTap() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.55)) {
            stampVisible = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + TaskListModel.stampHoldDuration) {
            // Trigger fade-out and slot reset, then hide the stamp so the
            // re-used row has a clean check-circle again.
            model.markDone()
            DispatchQueue.main.asyncAfter(deadline: .now() + TaskListModel.fadeOutDuration + 0.1) {
                withAnimation(.easeOut(duration: 0.15)) { stampVisible = false }
            }
        }
    }
}

/// Small sage-green postage stamp with a cream checkmark. Tilted ~−14° for
/// hand-stamped feel. Used as the "task done" celebration.
private struct GreenDoneStamp: View {
    var body: some View {
        ZStack {
            Circle()
                .stroke(Palette.sage.opacity(0.55), lineWidth: 0.8)
                .frame(width: 18, height: 18)
            Circle()
                .fill(Palette.sage)
                .frame(width: 13, height: 13)
            Image(systemName: "checkmark")
                .font(.system(size: 8, weight: .heavy))
                .foregroundStyle(Palette.cream)
        }
        .rotationEffect(.degrees(-14))
    }
}
