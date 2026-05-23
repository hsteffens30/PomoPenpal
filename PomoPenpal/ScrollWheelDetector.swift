//
//  ScrollWheelDetector.swift
//  PomoPenpal
//
//  Transparent NSView that captures scroll-wheel events and reports a
//  normalized intent direction. Lets us treat a two-finger trackpad swipe as
//  a navigation gesture on a non-scrolling view.
//

import AppKit
import SwiftUI

enum ScrollIntent {
    case down  // user wants to reveal content below current view
    case up    // user wants to reveal content above current view
}

struct ScrollWheelDetector: NSViewRepresentable {
    var onIntent: (ScrollIntent) -> Void

    func makeNSView(context: Context) -> Capturer {
        let v = Capturer()
        v.onIntent = onIntent
        return v
    }

    func updateNSView(_ nsView: Capturer, context: Context) {
        nsView.onIntent = onIntent
    }

    final class Capturer: NSView {
        var onIntent: ((ScrollIntent) -> Void)?
        private var lastFire: Date = .distantPast
        private let cooldown: TimeInterval = 0.6
        private let threshold: CGFloat = 1.0

        override var acceptsFirstResponder: Bool { true }

        override func scrollWheel(with event: NSEvent) {
            // Normalize so "user wants to see content below" is always positive,
            // regardless of the user's natural-scrolling preference. With natural
            // scrolling on (the macOS default), AppKit hands us an inverted delta;
            // re-inverting recovers the raw device direction.
            let dy = event.scrollingDeltaY
            let normalized = event.isDirectionInvertedFromDevice ? -dy : dy
            guard abs(normalized) > threshold else { return }

            // Debounce so a single multi-event trackpad swipe fires once.
            let now = Date()
            guard now.timeIntervalSince(lastFire) > cooldown else { return }
            lastFire = now

            onIntent?(normalized > 0 ? .down : .up)
        }
    }
}
