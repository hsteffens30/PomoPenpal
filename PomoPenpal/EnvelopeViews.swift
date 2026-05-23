//
//  EnvelopeViews.swift
//  PomoPenpal
//
//  Thin wrappers around the finalized envelope SVG assets in Assets.xcassets.
//  The Phase 2 work-end animation will composite a small PostageStamp child
//  view onto `EnvelopeBack` — that compositing is intentionally deferred.
//

import SwiftUI

/// Cream envelope rendered front-facing (closed flap with drop shadow).
/// Used by the cold-start and work-start blank-envelope animations in Phase 2.
struct EnvelopeFront: View {
    var body: some View {
        Image("EnvelopeFront")
            .resizable()
            .aspectRatio(400.0 / 300.0, contentMode: .fit)
    }
}

/// Cream envelope back with two taupe address-lines.
/// In Phase 2 a PostageStamp child view will be layered onto this.
struct EnvelopeBack: View {
    var body: some View {
        Image("EnvelopeBack")
            .resizable()
            .aspectRatio(400.0 / 300.0, contentMode: .fit)
    }
}

#Preview("EnvelopeFront") {
    EnvelopeFront()
        .frame(width: 320, height: 240)
        .padding()
        .background(Palette.cream)
}

#Preview("EnvelopeBack") {
    EnvelopeBack()
        .frame(width: 320, height: 240)
        .padding()
        .background(Palette.cream)
}
