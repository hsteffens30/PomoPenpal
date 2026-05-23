//
//  AlbumView.swift
//  PomoPenpal
//
//  The mailbag-heap album view. Real SpriteKit heap is wired up in the next
//  deliverable; this file owns the page chrome (back chevron, cream bg).
//

import SwiftUI

struct AlbumView: View {
    var onShowTimer: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            Palette.cream.ignoresSafeArea()

            // Heap goes here in deliverable 5.
            Color.clear

            Button(action: onShowTimer) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.inkOnCream.opacity(0.45))
                    .frame(width: 36, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
            .accessibilityLabel("Back to timer")
        }
        .frame(width: 360, height: 240)
    }
}

#Preview {
    AlbumView(onShowTimer: {})
        .frame(width: 360, height: 240)
}
