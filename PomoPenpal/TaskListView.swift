//
//  TaskListView.swift
//  PomoPenpal
//
//  Session task input that lives between the phase label and the timer.
//  Renders 1–3 rows from TaskListModel. Each row has a check-circle, a
//  text field, and an × delete button. Tapping the circle slaps a small
//  green postage-stamp on the row and fades it out.
//

import SwiftUI

struct TaskListView: View {
    let model: TaskListModel
    let phase: TimerEngine.Phase

    @FocusState private var focusedID: UUID?

    var body: some View {
        VStack(spacing: 2) {
            ForEach(model.tasks) { task in
                TaskRow(
                    task: task,
                    isFirstSlot: task.id == model.tasks.first?.id,
                    phase: phase,
                    onTitleChange: { newTitle in
                        model.update(taskID: task.id, title: newTitle)
                    },
                    onSubmit: {
                        if let newID = model.handleSubmit(from: task.id) {
                            // Defer focus so the new row exists before we focus it.
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) {
                                focusedID = newID
                            }
                        }
                    },
                    onDelete: {
                        model.removeSlot(taskID: task.id)
                    },
                    onMarkDone: {
                        model.markDone(taskID: task.id)
                    },
                    focusBinding: $focusedID
                )
                .id(task.id)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: model.tasks.map(\.id))
    }
}

private struct TaskRow: View {
    let task: TaskListModel.Task
    let isFirstSlot: Bool
    let phase: TimerEngine.Phase
    let onTitleChange: (String) -> Void
    let onSubmit: () -> Void
    let onDelete: () -> Void
    let onMarkDone: () -> Void
    let focusBinding: FocusState<UUID?>.Binding

    /// Local animation state for the slap-in stamp.
    @State private var stampVisible: Bool = false

    private var placeholder: String {
        isFirstSlot ? "What's the goal for this session?" : "Another task?"
    }

    private var hasContent: Bool {
        !task.title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var ink: Color { Palette.ink(for: phase) }

    var body: some View {
        HStack(spacing: 6) {
            // Check circle: only enabled when there's content to check off
            // and we're not already mid-animation.
            Button(action: handleCheckTap) {
                Image(systemName: "circle")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(ink.opacity(hasContent ? 0.65 : 0.3))
                    .frame(width: 14, height: 14)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!hasContent || stampVisible || task.isCompleting)

            TextField(placeholder, text: Binding(
                get: { task.title },
                set: onTitleChange
            ))
            .textFieldStyle(.plain)
            .font(.system(size: 11, weight: .regular))
            .foregroundStyle(ink.opacity(0.9))
            .tint(ink)
            .focused(focusBinding, equals: task.id)
            .onSubmit(onSubmit)
            .disabled(task.isCompleting)

            if hasContent {
                Button(action: onDelete) {
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
                // jump width when × appears.
                Color.clear.frame(width: 12, height: 12)
            }
        }
        .padding(.horizontal, 6)
        .frame(height: 18)
        .overlay(alignment: .trailing) {
            if stampVisible {
                GreenDoneStamp()
                    .padding(.trailing, 22)
                    .transition(.scale(scale: 0.25).combined(with: .opacity))
            }
        }
        .opacity(task.isCompleting ? 0 : 1)
        .animation(.easeOut(duration: TaskListModel.fadeOutDuration), value: task.isCompleting)
    }

    private func handleCheckTap() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.55)) {
            stampVisible = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + TaskListModel.stampHoldDuration) {
            onMarkDone()
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

#Preview {
    let model = TaskListModel()
    model.update(taskID: model.tasks[0].id, title: "Wire up TaskListView")
    return VStack {
        TaskListView(model: model, phase: .idle)
            .frame(width: 280)
            .padding()
            .background(Palette.cream)
    }
    .frame(width: 360, height: 240)
}
