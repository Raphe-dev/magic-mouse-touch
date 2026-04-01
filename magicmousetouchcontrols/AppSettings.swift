//  AppSettings.swift
//  Persistent user preferences backed by UserDefaults.

import Foundation
import Combine

enum RightClickMode: String, CaseIterable {
    case twoFinger = "twoFinger"
    case rightSide = "rightSide"
}

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var isEnabled: Bool              { didSet { save("isEnabled",            isEnabled) } }
    @Published var rightClickMode: RightClickMode { didSet { save("rightClickMode",     rightClickMode.rawValue) } }
    @Published var rightSideThreshold: Double   { didSet { save("rightSideThreshold",   rightSideThreshold) } }
    @Published var minTapPressure: Double       { didSet { save("minTapPressure",       minTapPressure) } }
    @Published var tapDurationThreshold: Double { didSet { save("tapDurationThreshold", tapDurationThreshold) } }
    @Published var doubleTapEnabled: Bool       { didSet { save("doubleTapEnabled",     doubleTapEnabled) } }
    @Published var doubleTapInterval: Double    { didSet { save("doubleTapInterval",    doubleTapInterval) } }
    @Published var tapAndHoldEnabled: Bool      { didSet { save("tapAndHoldEnabled",    tapAndHoldEnabled) } }
    @Published var tapAndHoldDelay: Double      { didSet { save("tapAndHoldDelay",      tapAndHoldDelay) } }
    @Published var edgeRejectMargin: Double     { didSet { save("edgeRejectMargin",     edgeRejectMargin) } }

    private init() {
        let d = UserDefaults.standard
        isEnabled            = d.object(forKey: "isEnabled")            as? Bool   ?? true
        // Migrate legacy twoFingerRightClick: if it was false, default to rightSide mode
        let legacyTwoFinger  = d.object(forKey: "twoFingerRightClick")  as? Bool   ?? true
        rightClickMode       = RightClickMode(rawValue: d.string(forKey: "rightClickMode") ?? "")
                               ?? (legacyTwoFinger ? .twoFinger : .rightSide)
        rightSideThreshold   = d.object(forKey: "rightSideThreshold")   as? Double ?? 0.55
        minTapPressure       = d.object(forKey: "minTapPressure")       as? Double ?? 1.0
        tapDurationThreshold = d.object(forKey: "tapDurationThreshold") as? Double ?? 0.20
        doubleTapEnabled     = d.object(forKey: "doubleTapEnabled")     as? Bool   ?? true
        doubleTapInterval    = d.object(forKey: "doubleTapInterval")    as? Double ?? 0.45
        tapAndHoldEnabled    = d.object(forKey: "tapAndHoldEnabled")    as? Bool   ?? true
        tapAndHoldDelay      = d.object(forKey: "tapAndHoldDelay")      as? Double ?? 0.32
        edgeRejectMargin     = d.object(forKey: "edgeRejectMargin")     as? Double ?? 0.06
    }

    private func save(_ key: String, _ value: some Any) {
        UserDefaults.standard.set(value, forKey: key)
    }
}
