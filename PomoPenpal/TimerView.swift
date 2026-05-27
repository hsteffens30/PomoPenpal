//
//  TimerView.swift
//  PomoPenpal
//

import SwiftUI

struct TimerView: View {
    let engine: TimerEngine
    let taskList: TaskListModel
    var onShowAlbum: (() -> Void)? = nil

    /// Focus for the task input lives here so clicking anywhere else on the
    /// page can dismiss it.
    @FocusState private var taskFieldFocused: Bool

    /// macOS tells us whether the hosting window is key. When it isn't (user
    /// clicked out), the control buttons swap their tint to black so they stay
    /// readable instead of fading to the muted inactive look macOS applies by
    /// default.
    @Environment(\.controlActiveState) private var controlActive

    private var buttonTint: Color {
        controlActive == .key ? Palette.ink(for: engine.phase) : .black
    }

    var body: some View {
        ZStack {
            // Background tap target — when the user clicks anywhere that
            // isn't a control, the task input loses focus (no blinking caret
            // left behind).
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { taskFieldFocused = false }

            VStack(spacing: 10) {
                Text(engine.phase.label)
                    .font(.callout)
                    .textCase(.uppercase)
                    .tracking(2)
                    .foregroundStyle(Palette.ink(for: engine.phase).opacity(0.75))

                TaskListView(model: taskList,
                             phase: engine.phase,
                             focusBinding: $taskFieldFocused)
                    .frame(maxWidth: 280)

                Text(engine.formattedTime)
                    .font(.system(size: 52, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink(for: engine.phase))

                HStack(spacing: 8) {
                    Button(engine.isRunning ? "Pause" : "Start") {
                        engine.isRunning ? engine.pause() : engine.start()
                    }

                    Button("Reset") { engine.reset() }

                    Button("Skip") { engine.skip() }
                }
                .controlSize(.regular)
                .buttonStyle(.bordered)
                .tint(buttonTint)

                Text("Completed: \(engine.completedInCycle) / 4")
                    .font(.caption2)
                    .foregroundStyle(Palette.ink(for: engine.phase).opacity(0.55))
            }
            .padding(.top, 10)
        }
        .frame(width: 360, height: 240)
        .background(Palette.background(for: engine.phase))
        // Chevron is overlaid on the bottom edge in empty space so it never
        // collides with the timer content above.
        .overlay(alignment: .bottom) {
            if let onShowAlbum {
                Button(action: onShowAlbum) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Palette.ink(for: engine.phase).opacity(0.5))
                        .frame(width: 44, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.bottom, 4)
                .accessibilityLabel("Show album")
            }
        }
    }
}

#Preview("Idle") {
    TimerView(engine: TimerEngine(), taskList: TaskListModel(), onShowAlbum: {})
        .frame(width: 360, height: 240)
}
