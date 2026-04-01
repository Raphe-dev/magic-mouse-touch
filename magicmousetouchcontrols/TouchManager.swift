//  TouchManager.swift
//  Processes raw multitouch frames and detects single tap, double tap, tap-and-hold.

import AppKit
import Combine

@MainActor
final class TouchManager: ObservableObject {
    static let shared = TouchManager()

    @Published private(set) var isRunning = false
    /// Last completed tap's peak zTotal. Plain var — SettingsView polls this only while open.
    private(set) var lastPeakPressure = Float(0)

    // MARK: - Tracking state

    private var tracking      = false
    private var trackingStart = 0.0
    private var maxFingers    = 0
    private var maxPressure   = Float(0)      // peak zTotal seen during this touch
    private var initialPos: [Int32: (x: Float, y: Float)] = [:]

    // Double-tap (no latency: second tap sends clickCount=2)
    private var lastTapTime        = 0.0
    private var lastTapFingerCount = 0

    // Tap-and-hold
    private var isHolding = false
    private var holdTask: Task<Void, Never>?

    // MARK: - Constants

    private let minTapDuration: Double = 0.01
    private let debounce:       Double = 0.05   // short — only blocks ghost re-fires
    private let maxMovement:    Float  = 0.12   // Magic Mouse glass is slippery; fingers drift more than on a trackpad

    // MARK: - Lifecycle

    func start() {
        let ok = MultitouchBridge.shared().start(callback: { [weak self] touches, count, timestamp in
            self?.processFrame(touches: touches, count: Int(count), timestamp: timestamp)
        })
        isRunning = ok
    }

    func stop() {
        MultitouchBridge.shared().stop()
        cancelHold()
        if isHolding { ClickInjector.shared.performMouseUp(); isHolding = false }
        isRunning = false
        resetTracking()
    }

    // MARK: - Frame processing

    private func processFrame(touches: UnsafePointer<MTTouch>?,
                              count: Int,
                              timestamp: Double) {
        guard AppSettings.shared.isEnabled else { return }

        struct TInfo { let id: Int32; let x: Float; let y: Float; let pressure: Float }
        let active: [TInfo] = count > 0 && touches != nil
            ? (0 ..< count).map { i in
                let t = touches![i]
                return TInfo(id: t.fingerID,
                             x: t.normalizedVector.position.x,
                             y: t.normalizedVector.position.y,
                             pressure: t.zTotal)
              }
            : []

        if isHolding {
            if active.isEmpty {
                ClickInjector.shared.performMouseUp()
                isHolding = false
                resetTracking()
            }
            return
        }

        if !tracking && !active.isEmpty {
            // Reject touches that start too close to the left or right edge.
            let margin = Float(AppSettings.shared.edgeRejectMargin)
            if active.contains(where: { $0.x < margin || $0.x > 1.0 - margin }) { return }

            tracking      = true
            trackingStart = timestamp
            maxFingers    = active.count
            maxPressure   = active.map(\.pressure).max() ?? 0
            initialPos    = [:]
            for t in active { initialPos[t.id] = (t.x, t.y) }
            scheduleHold()
            return
        }

        guard tracking else { return }

        // Keep updating peak pressure every frame while the finger is down.
        let framePeak = active.map(\.pressure).max() ?? 0
        if framePeak > maxPressure { maxPressure = framePeak }

        if active.count > maxFingers {
            maxFingers = active.count
            for t in active where initialPos[t.id] == nil {
                initialPos[t.id] = (t.x, t.y)
            }
        }

        if active.isEmpty {
            cancelHold()
            let duration    = timestamp - trackingStart
            let fingers     = maxFingers
            let peakPressure = maxPressure
            let avgX: Float = initialPos.isEmpty
                ? 0.5
                : initialPos.values.map(\.x).reduce(0, +) / Float(initialPos.count)
            resetTracking()

            let s = AppSettings.shared
            // Bypass debounce when this could be the second tap of a double-tap,
            // so the debounce never silently eats double-click events.
            let isDoubleTapCandidate = s.doubleTapEnabled
                && lastTapFingerCount == fingers
                && (timestamp - lastTapTime) < s.doubleTapInterval

            // Always record the peak so the settings UI can show the live readout,
            // even when the tap is rejected by the pressure threshold.
            lastPeakPressure = peakPressure

            guard duration >= minTapDuration,
                  duration <= s.tapDurationThreshold,
                  isDoubleTapCandidate || (timestamp - lastTapTime >= debounce),
                  peakPressure >= Float(s.minTapPressure)
            else { return }

            fireTap(fingerCount: fingers, tapTime: timestamp, avgX: avgX)
            return
        }

        for t in active {
            guard let init0 = initialPos[t.id] else { continue }
            let dx = t.x - init0.x, dy = t.y - init0.y
            if (dx * dx + dy * dy).squareRoot() > maxMovement {
                cancelHold()
                resetTracking()
                return
            }
        }
    }

    // MARK: - Tap

    private func fireTap(fingerCount: Int, tapTime: Double, avgX: Float) {
        let s = AppSettings.shared
        let clickCount: Int = s.doubleTapEnabled
            && lastTapFingerCount == fingerCount
            && (tapTime - lastTapTime) < s.doubleTapInterval ? 2 : 1

        lastTapTime        = tapTime
        lastTapFingerCount = fingerCount

        switch (fingerCount, s.rightClickMode) {
        case (1, .twoFinger):
            ClickInjector.shared.performClick(button: .left, clickCount: clickCount)
        case (2, .twoFinger):
            ClickInjector.shared.performClick(button: .right, clickCount: clickCount)
        case (1, .rightSide):
            let button: MouseButton = avgX >= Float(s.rightSideThreshold) ? .right : .left
            ClickInjector.shared.performClick(button: button, clickCount: clickCount)
        default:
            break
        }
    }

    // MARK: - Hold

    private func scheduleHold() {
        guard AppSettings.shared.tapAndHoldEnabled else { return }
        let delay = AppSettings.shared.tapAndHoldDelay
        holdTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard let self, !Task.isCancelled, self.tracking else { return }
            self.cancelHold()
            self.isHolding = true
            self.resetTracking()
            ClickInjector.shared.performMouseDown()
        }
    }

    private func cancelHold() { holdTask?.cancel(); holdTask = nil }
    private func resetTracking() { tracking = false; maxFingers = 0; maxPressure = 0; initialPos = [:] }
}
