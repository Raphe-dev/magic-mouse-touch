//  magicmousetouchcontrolsApp.swift
//  Lives in the menu bar only (no Dock icon, no window).

import SwiftUI

@main
struct magicmousetouchcontrolsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            SettingsView()
        } label: {
            MenuBarIcon()
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MenuBarIcon: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        Image(systemName: settings.isEnabled ? "cursorarrow.click.2" : "cursorarrow")
            .symbolRenderingMode(.hierarchical)
    }
}

// MARK: – App Delegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        TouchManager.shared.start()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
