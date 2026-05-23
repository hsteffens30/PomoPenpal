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
                .foregroundStyle(textColor.opacity(0.75))

            Text(engine.formattedTime)
                .font(.system(size: 52, weight: .light, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(textColor)

            HStack(spacing: 8) {
                Button(engine.isRunning ? "Pause" : "Start") {
                    engine.isRunning ? engine.pause() : engine.start()
                }

                Button("Reset") { engine.reset() }

                Button("Skip") { engine.skip() }
            }
            .controlSize(.regular)
            .buttonStyle(.bordered)
            .tint(textColor)

            Text("Completed: \(engine.completedWorkSessions)")
                .font(.caption2)
                .foregroundStyle(textColor.opacity(0.55))
        }
        .padding(.top, 12)
        .frame(width: 360, height: 240)
        .background(backgroundColor)
    }

    private var backgroundColor: Color {
        switch engine.phase {
        case .idle:       return Color(red: 1.000, green: 0.957, blue: 0.910) // cream  #FFF4E8
        case .working:    return Color(red: 0.769, green: 0.353, blue: 0.353) // muted red  #C45A5A
        case .shortBreak: return Color(red: 0.416, green: 0.596, blue: 0.471) // sage  #6A9878
        case .longBreak:  return Color(red: 0.353, green: 0.580, blue: 0.565) // dusty teal  #5A9490
        }
    }

    private var textColor: Color {
        switch engine.phase {
        case .idle: return Color(red: 0.20, green: 0.18, blue: 0.16) // dark on cream
        default:    return Color(red: 1.000, green: 0.957, blue: 0.910) // cream on saturated
        }
    }
}

#Preview {
    TimerView(engine: TimerEngine())
        .frame(width: 360, height: 240)
}
