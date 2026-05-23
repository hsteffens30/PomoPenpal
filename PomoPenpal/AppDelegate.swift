//
//  AppDelegate.swift
//  PomoPenpal
//

import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {

    private let engine = TimerEngine()
    private var statusItem: NSStatusItem?
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupWindow()

        engine.onTick = { [weak self] in
            self?.refreshStatusItemTitle()
        }
        refreshStatusItemTitle()

        // Show the window on launch (alongside the menu-bar entry).
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.target = self
            button.action = #selector(handleStatusItemClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.wantsLayer = true
            // Half the menu-bar thickness gives a fully rounded pill; the layer
            // clamps anything beyond half-height, so the value is safe at any size.
            button.layer?.cornerRadius = NSStatusBar.system.thickness / 2
            button.layer?.masksToBounds = true
        }
        statusItem = item
    }

    private func setupWindow() {
        let hosting = NSHostingController(rootView: TimerView(engine: engine))

        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 240),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        w.contentViewController = hosting
        w.title = "PomoPenpal"
        w.titleVisibility = .hidden
        w.titlebarAppearsTransparent = true
        w.isMovableByWindowBackground = true
        w.isReleasedWhenClosed = false
        w.level = .floating
        w.setFrameAutosaveName("PomoPenpalMainWindow")
        w.center()
        w.delegate = self
        window = w
    }

    @objc private func handleStatusItemClick(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu()
        } else {
            toggleWindow()
        }
    }

    private func toggleWindow() {
        guard let window else { return }
        if window.isVisible {
            window.orderOut(nil)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        }
    }

    private func showContextMenu() {
        guard let statusItem else { return }
        let menu = NSMenu()
        menu.addItem(
            NSMenuItem(
                title: "Quit PomoPenpal",
                action: #selector(NSApplication.terminate(_:)),
                keyEquivalent: "q"
            )
        )
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    private func refreshStatusItemTitle() {
        guard let button = statusItem?.button else { return }
        let phase = engine.phase
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.menuBarFont(ofSize: 0),
            .foregroundColor: Palette.inkNS(for: phase)
        ]
        button.attributedTitle = NSAttributedString(
            string: engine.formattedTime,
            attributes: attrs
        )
        button.layer?.backgroundColor = Palette.backgroundNS(for: phase).cgColor
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }
}
