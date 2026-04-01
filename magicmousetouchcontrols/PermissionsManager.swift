//  PermissionsManager.swift
//  Checks and prompts for the two permissions this app needs.

import AppKit
import Combine
import ApplicationServices

@MainActor
final class PermissionsManager: ObservableObject {
    static let shared = PermissionsManager()

    @Published private(set) var accessibilityGranted = false

    private var pollTimer: Timer?

    private init() {
        refresh()
        startPollingIfNeeded()
        // Re-check when the user switches back from System Settings.
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil, queue: .main
        ) { _ in
            Task { @MainActor in PermissionsManager.shared.refresh() }
        }
    }

    func refresh() {
        accessibilityGranted = AXIsProcessTrusted()
        if accessibilityGranted {
            pollTimer?.invalidate()
            pollTimer = nil
        }
    }

    /// Trigger the native Accessibility permission popup.
    func openAccessibilitySettings() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true]
                      as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        startPollingIfNeeded()
    }

    func openInputMonitoringSettings() {
        let url = URL(string:
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!
        NSWorkspace.shared.open(url)
    }

    private func startPollingIfNeeded() {
        guard pollTimer == nil, !accessibilityGranted else { return }
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            Task { @MainActor in PermissionsManager.shared.refresh() }
        }
    }
}
