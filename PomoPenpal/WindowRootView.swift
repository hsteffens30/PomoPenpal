//
//  WindowRootView.swift
//  PomoPenpal
//
//  Two-page container hosted inside the 360x240 window: timer (default) and
//  album (swipe-down). Pages transition via .move(edge: .bottom) — album
//  slides up from below to cover the timer, and back the same way in reverse.
//  Scroll-wheel events anywhere in the window route to the same transitions.
//

import SwiftUI

struct WindowRootView: View {
    let engine: TimerEngine
    let taskList: TaskListModel

    enum Page { case timer, album }

    @State private var page: Page = .timer

    var body: some View {
        ZStack {
            switch page {
            case .timer:
                TimerView(engine: engine, taskList: taskList, onShowAlbum: showAlbum)
                    .transition(.move(edge: .top).combined(with: .opacity))
            case .album:
                AlbumView(onShowTimer: showTimer)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(width: 360, height: 240)
        .clipped()
        .background(
            ScrollWheelDetector { intent in
                switch (intent, page) {
                case (.down, .timer): showAlbum()
                case (.up, .album):   showTimer()
                default: break
                }
            }
        )
    }

    private func showAlbum() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            page = .album
        }
    }

    private func showTimer() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            page = .timer
        }
    }
}

#Preview {
    WindowRootView(engine: TimerEngine(), taskList: TaskListModel())
        .frame(width: 360, height: 240)
}
