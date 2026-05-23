//
//  TimerView.swift
//  PomoPenpal
//

import SwiftUI

struct TimerView: View {
    let engine: TimerEngine

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

            Text("Completed: \(engine.completedWorkSessions)")
                .font(.caption2)
                .foregroundStyle(Palette.ink(for: engine.phase).opacity(0.55))
        }
        .padding(.top, 12)
        .frame(width: 360, height: 240)
        .background(Palette.background(for: engine.phase))
    }
}

#Preview {
    TimerView(engine: TimerEngine())
        .frame(width: 360, height: 240)
}
