//
//  ChimePlayer.swift
//  PomoPenpal
//
//  Subtle chime on work-session end (Decision #12). Tries an AVAudioPlayer
//  with a bundled `chime` resource (.caf/.aiff/.wav). If the file isn't in
//  the bundle yet — Phase 1 ships without a curated sound asset — falls back
//  to a built-in macOS NSSound so the chime still fires. Both paths respect
//  the `soundEnabled` UserDefaults flag controlled by the status-item menu.
//

import AppKit
import AVFoundation

@MainActor
final class ChimePlayer {
    static let soundEnabledKey = "soundEnabled"

    private var player: AVAudioPlayer?

    init() {
        if let url = ChimePlayer.bundledChimeURL() {
            do {
                player = try AVAudioPlayer(contentsOf: url)
                player?.prepareToPlay()
            } catch {
                print("PomoPenpal: AVAudioPlayer init failed for \(url): \(error). Falling back to NSSound.")
                player = nil
            }
        }
    }

    func playWorkEnd() {
        guard UserDefaults.standard.bool(forKey: ChimePlayer.soundEnabledKey) else { return }
        if let player {
            player.currentTime = 0
            player.play()
        } else {
            // Fallback chime — quiet, short, ships with macOS.
            NSSound(named: NSSound.Name("Tink"))?.play()
        }
    }

    private static func bundledChimeURL() -> URL? {
        let candidates = ["chime", "Chime"]
        let extensions = ["caf", "aiff", "wav", "m4a", "mp3"]
        for name in candidates {
            for ext in extensions {
                if let url = Bundle.main.url(forResource: name, withExtension: ext) {
                    return url
                }
            }
        }
        return nil
    }
}
