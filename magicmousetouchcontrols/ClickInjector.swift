//  ClickInjector.swift
//  Posts synthetic mouse CGEvents into the system event stream.
//  Requires Accessibility access in System Settings.

import AppKit
import CoreGraphics

enum MouseButton { case left, right }

@MainActor
final class ClickInjector {
    static let shared = ClickInjector()
    private init() {}

    // MARK: - Public API

    /// Full click (down + up). clickCount 1 = single, 2 = double.
    func performClick(button: MouseButton = .left, clickCount: Int = 1) {
        let pos = cgPosition()
        post(type: button == .left ? .leftMouseDown  : .rightMouseDown,
             button: button, pos: pos, clickCount: clickCount)
        post(type: button == .left ? .leftMouseUp    : .rightMouseUp,
             button: button, pos: pos, clickCount: clickCount)
    }

    /// Only the down event — used for tap-and-hold.
    func performMouseDown(button: MouseButton = .left) {
        post(type: button == .left ? .leftMouseDown : .rightMouseDown,
             button: button, pos: cgPosition(), clickCount: 1)
    }

    /// Only the up event — paired with performMouseDown.
    func performMouseUp(button: MouseButton = .left) {
        post(type: button == .left ? .leftMouseUp : .rightMouseUp,
             button: button, pos: cgPosition(), clickCount: 1)
    }

    // MARK: - Private

    private func post(type: CGEventType, button: MouseButton,
                      pos: CGPoint, clickCount: Int) {
        let cgBtn: CGMouseButton = button == .left ? .left : .right
        guard let e = CGEvent(mouseEventSource: nil, mouseType: type,
                              mouseCursorPosition: pos, mouseButton: cgBtn)
        else { return }
        e.setIntegerValueField(.mouseEventClickState, value: Int64(clickCount))
        e.post(tap: .cghidEventTap)
    }

    private func cgPosition() -> CGPoint {
        let p = NSEvent.mouseLocation
        let h = NSScreen.screens.first(where: { $0.frame.origin == .zero })?.frame.height
                ?? NSScreen.main?.frame.height ?? 0
        return CGPoint(x: p.x, y: h - p.y)
    }
}
