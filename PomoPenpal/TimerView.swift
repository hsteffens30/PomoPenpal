//
//  TimerView.swift
//  PomoPenpal
//

import SwiftUI

struct TimerView: View {
    let engine: TimerEngine
    var onShowAlbum: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 14) {
            Text(engine.phase.label)
                .font(.callout)
                .textCase(.uppercase)
                .tracking(2)
                .foregroundStyle(Palette.ink(for: engine.phase).opacity(0.75))

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
            .tint(Palette.ink(for: engine.phase))

            Text("Completed: \(engine.completedInCycle) / 4")
                .font(.caption2)
                .foregroundStyle(Palette.ink(for: engine.phase).opacity(0.55))
        }
        .padding(.top, 12)
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
    TimerView(engine: TimerEngine(), onShowAlbum: {})
        .frame(width: 360, height: 240)
}
