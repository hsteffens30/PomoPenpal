//
//  TimerView.swift
//  PomoPenpal
//

import SwiftUI

struct TimerView: View {
    let engine: TimerEngine
    var onShowAlbum: (() -> Void)? = nil

    var body: some View {
        ZStack(alignment: .bottom) {
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

                Text("Completed: \(engine.completedWorkSessions)")
                    .font(.caption2)
                    .foregroundStyle(Palette.ink(for: engine.phase).opacity(0.55))
            }
            .padding(.top, 12)

            if let onShowAlbum {
                Button(action: onShowAlbum) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Palette.ink(for: engine.phase).opacity(0.45))
                        .frame(width: 36, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.bottom, 2)
                .accessibilityLabel("Show album")
            }
        }
        .frame(width: 360, height: 240)
        .background(Palette.background(for: engine.phase))
    }
}

#Preview("Idle") {
    TimerView(engine: TimerEngine(), onShowAlbum: {})
        .frame(width: 360, height: 240)
}
