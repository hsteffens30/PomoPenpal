//
//  AlbumView.swift
//  PomoPenpal
//
//  The mailbag heap, embedded in a SpriteView. Letters for the current ISO
//  week are dropped in on appear, new letters drop live mid-session, dragging
//  the window applies an impulse, and a corner readout shows this-week and
//  all-time best counts (Decision #13, album-layout-ideas.md).
//

import AppKit
import SpriteKit
import SwiftData
import SwiftUI

@MainActor
private final class WindowMoveBridge {
    private var observer: NSObjectProtocol?
    private var lastOrigin: NSPoint?

    func install(onMove: @escaping @MainActor (CGFloat, CGFloat) -> Void) {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            MainActor.assumeIsolated {
                guard let window = note.object as? NSWindow else { return }
                let origin = window.frame.origin
                if let last = self?.lastOrigin {
                    onMove(origin.x - last.x, origin.y - last.y)
                }
                self?.lastOrigin = origin
            }
        }
    }

    func uninstall() {
        if let token = observer {
            NotificationCenter.default.removeObserver(token)
            observer = nil
        }
        lastOrigin = nil
    }
}

struct AlbumView: View {
    var onShowTimer: () -> Void

    @Query private var weekLetters: [Letter]
    @Query private var allLetters: [Letter]

    @State private var scene: MailbagScene = {
        let s = MailbagScene()
        s.size = CGSize(width: 360, height: 240)
        return s
    }()
    @State private var windowBridge = WindowMoveBridge()
    @State private var didSeed: Bool = false

    /// Cutoff used to split already-seen letters from new-since-last-open ones.
    /// Persisted to UserDefaults so the fall animation never replays just
    /// because the user popped over to the album to look at the pile.
    private static let lastViewedKey = "AlbumView.lastViewedLetterDate"

    init(onShowTimer: @escaping () -> Void) {
        self.onShowTimer = onShowTimer
        let currentWeek = Letter.currentWeekIndex()
        _weekLetters = Query(
            filter: #Predicate<Letter> { $0.weekIndex == currentWeek },
            sort: [SortDescriptor(\.dateEarned)]
        )
        _allLetters = Query()
    }

    private var bestWeekCount: Int {
        Dictionary(grouping: allLetters, by: { $0.weekIndex })
            .values.map { $0.count }.max() ?? 0
    }

    private static func loadLastViewedDate() -> Date {
        let t = UserDefaults.standard.double(forKey: lastViewedKey)
        return t > 0 ? Date(timeIntervalSinceReferenceDate: t) : .distantPast
    }

    private static func saveLastViewedDate(_ date: Date) {
        UserDefaults.standard.set(date.timeIntervalSinceReferenceDate, forKey: lastViewedKey)
    }

    var body: some View {
        ZStack(alignment: .top) {
            // No .allowsTransparency — the scene paints a solid backWallColor and
            // per-pixel alpha compositing on Metal isn't needed here. Skipping it
            // keeps the SpriteView render path leaner.
            SpriteView(scene: scene)
                .frame(width: 360, height: 240)

            Button(action: onShowTimer) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.inkOnCream.opacity(0.5))
                    .frame(width: 36, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
            .accessibilityLabel("Back to timer")

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Text(readout)
                        .font(.system(size: 9.5, weight: .regular, design: .rounded))
                        .foregroundStyle(Palette.inkOnCream.opacity(0.55))
                        .padding(.trailing, 8)
                        .padding(.bottom, 6)
                }
            }
        }
        .frame(width: 360, height: 240)
        .onAppear {
            if !didSeed {
                seedSceneAndMarkSeen()
                didSeed = true
            }
            windowBridge.install { dx, dy in
                scene.applyWindowMoveImpulse(dx: dx, dy: dy)
            }
        }
        .onDisappear {
            windowBridge.uninstall()
        }
        .onChange(of: weekLetters.count) { oldCount, newCount in
            if newCount > oldCount {
                // New work session(s) completed while the album is open — drop them in
                // and roll the lastViewed cutoff forward so re-opening doesn't replay.
                for _ in 0..<(newCount - oldCount) {
                    scene.dropOneLetter()
                }
                markCurrentLettersSeen()
            } else if newCount < oldCount {
                // Week rolled over or a letter was removed; replay from scratch
                // (everything is "seen" — no drop animation).
                scene.reload(seen: weekLetters, new: [])
                markCurrentLettersSeen()
            }
        }
    }

    /// Split current-week letters into already-seen and new-since-last-open, hand
    /// both halves to the scene, and update the persisted cutoff to the most
    /// recent letter so the next open won't replay any fall animations.
    private func seedSceneAndMarkSeen() {
        let cutoff = Self.loadLastViewedDate()
        let seen = weekLetters.filter { $0.dateEarned <= cutoff }
        let new  = weekLetters.filter { $0.dateEarned >  cutoff }
        scene.reload(seen: seen, new: new)
        markCurrentLettersSeen()
    }

    private func markCurrentLettersSeen() {
        if let mostRecent = weekLetters.map({ $0.dateEarned }).max() {
            Self.saveLastViewedDate(mostRecent)
        }
    }

    private var readout: String {
        let n = weekLetters.count
        let best = max(bestWeekCount, n)
        let pluralN = n == 1 ? "letter" : "letters"
        return "\(n) \(pluralN) this week · best week \(best)"
    }
}

#Preview {
    AlbumView(onShowTimer: {})
        .frame(width: 360, height: 240)
        .modelContainer(for: Letter.self, inMemory: true)
}
