//
//  PomoPenpalApp.swift
//  PomoPenpal
//

import SwiftUI

@main
struct PomoPenpalApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}
