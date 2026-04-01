//  SettingsView.swift
//  Menu-bar popover UI for Magic Mouse Controls.

import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings    = AppSettings.shared
    @ObservedObject private var permissions = PermissionsManager.shared
    @ObservedObject private var touch       = TouchManager.shared

    /// Polled from TouchManager only while this view is visible — zero overhead when popover is closed.
    @State private var livePressure = Float(0)
    @State private var pressureTimer: Timer? = nil

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            gesturesSection
            sensitivitySection
            permissionsSection
            Divider()
            footer
        }
        .frame(width: 320)
        .onAppear {
            pressureTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                MainActor.assumeIsolated {
                    livePressure = TouchManager.shared.lastPeakPressure
                }
            }
        }
        .onDisappear {
            pressureTimer?.invalidate()
            pressureTimer = nil
        }
    }

    // MARK: – Header

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "cursorarrow.click.2")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text("magic-mouse-touch").font(.headline)
                Text("Tap-to-click for Magic Mouse")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: $settings.isEnabled)
                .toggleStyle(.switch).labelsHidden()
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    // MARK: – Gestures

    private var gesturesSection: some View {
        VStack(spacing: 0) {
            sectionHeader("Gestures")

            row {
                settingsIcon("cursorarrow", color: .blue)
                Text("1-finger tap")
                Spacer()
                Text("Left click").foregroundStyle(.secondary).font(.callout)
            }
            Divider().padding(.leading, 48)

            row {
                settingsIcon("computermouse.fill", color: .purple)
                Text("Right click")
                Spacer()
                Picker("", selection: $settings.rightClickMode) {
                    Text("2-finger").tag(RightClickMode.twoFinger)
                    Text("Right side").tag(RightClickMode.rightSide)
                }
                .pickerStyle(.segmented)
                .frame(width: 148)
                .disabled(!settings.isEnabled)
            }
            if settings.rightClickMode == .rightSide && settings.isEnabled {
                Divider().padding(.leading, 48)
                row {
                    Spacer().frame(width: 32)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Split point").font(.callout).foregroundStyle(.secondary)
                            Spacer()
                            Text("\(Int(settings.rightSideThreshold * 100))%")
                                .monospacedDigit().foregroundStyle(.secondary).font(.caption)
                        }
                        Slider(value: $settings.rightSideThreshold, in: 0.30...0.70, step: 0.05)
                        HStack {
                            Text("← Left click").font(.caption2).foregroundStyle(.tertiary)
                            Spacer()
                            Text("Right click →").font(.caption2).foregroundStyle(.tertiary)
                        }
                    }
                }
            }
            Divider().padding(.leading, 48)

            row {
                settingsIcon("cursorarrow.click.2", color: .orange)
                Toggle("Double tap → Double click", isOn: $settings.doubleTapEnabled)
                    .toggleStyle(.switch)
                    .disabled(!settings.isEnabled)
            }
            if settings.doubleTapEnabled && settings.isEnabled {
                Divider().padding(.leading, 48)
                subSliderRow(label: "Window",
                             value: $settings.doubleTapInterval,
                             range: 0.15...0.60,
                             display: "\(Int(settings.doubleTapInterval * 1000)) ms")
            }
            Divider().padding(.leading, 48)

            row {
                settingsIcon("hand.draw.fill", color: .green)
                Toggle("Tap and hold → Drag", isOn: $settings.tapAndHoldEnabled)
                    .toggleStyle(.switch)
                    .disabled(!settings.isEnabled)
            }
            if settings.tapAndHoldEnabled && settings.isEnabled {
                Divider().padding(.leading, 48)
                subSliderRow(label: "Delay",
                             value: $settings.tapAndHoldDelay,
                             range: 0.20...0.80,
                             display: "\(Int(settings.tapAndHoldDelay * 1000)) ms")
            }
        }
    }

    // MARK: – Sensitivity

    private var sensitivitySection: some View {
        VStack(spacing: 0) {
            sectionHeader("Tap Sensitivity")

            row {
                settingsIcon("hand.tap.fill", color: .pink)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Tap pressure")
                        Spacer()
                        Text(settings.minTapPressure == 0
                             ? "Off"
                             : String(format: "%.3f", settings.minTapPressure))
                            .monospacedDigit().foregroundStyle(.secondary).font(.caption)
                    }
                    Slider(value: $settings.minTapPressure, in: 0.0...1.5, step: 0.025)
                        .disabled(!settings.isEnabled)
                    HStack {
                        Text("Off").font(.caption2).foregroundStyle(.tertiary)
                        Spacer()
                        Text("Firm only").font(.caption2).foregroundStyle(.tertiary)
                    }
                    // Live readout — tap the mouse to see your real peak values.
                    HStack(spacing: 6) {
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .font(.caption2).foregroundStyle(.tertiary)
                        Text("Last tap peak:")
                            .font(.caption2).foregroundStyle(.tertiary)
                        Text(String(format: "%.3f", livePressure))
                            .monospacedDigit().font(.caption2)
                            .foregroundStyle(
                                livePressure >= Float(settings.minTapPressure) && livePressure > 0
                                    ? Color.green : Color.secondary)
                        Spacer()
                        Text("tap mouse to calibrate")
                            .font(.caption2).foregroundStyle(.tertiary).italic()
                    }
                }
            }
            Divider().padding(.leading, 48)

            row {
                settingsIcon("timer", color: .blue)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Tap duration limit")
                        Spacer()
                        Text("\(Int(settings.tapDurationThreshold * 1000)) ms")
                            .monospacedDigit().foregroundStyle(.secondary).font(.caption)
                    }
                    Slider(value: $settings.tapDurationThreshold, in: 0.08...0.30, step: 0.01)
                        .disabled(!settings.isEnabled)
                    HStack {
                        Text("Fast").font(.caption2).foregroundStyle(.tertiary)
                        Spacer()
                        Text("Relaxed").font(.caption2).foregroundStyle(.tertiary)
                    }
                }
            }
            Divider().padding(.leading, 48)

            row {
                settingsIcon("arrow.left.and.right.square.fill", color: .gray)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Edge rejection")
                        Spacer()
                        Text("\(Int(settings.edgeRejectMargin * 50)) mm")
                            .monospacedDigit().foregroundStyle(.secondary).font(.caption)
                    }
                    Slider(value: $settings.edgeRejectMargin, in: 0.0...0.12, step: 0.01)
                        .disabled(!settings.isEnabled)
                    HStack {
                        Text("Off").font(.caption2).foregroundStyle(.tertiary)
                        Spacer()
                        Text("6 mm").font(.caption2).foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    // MARK: – Permissions

    private var permissionsSection: some View {
        VStack(spacing: 0) {
            sectionHeader("Permissions")
            permissionRow(iconName: "accessibility",
                          iconColor: .blue,
                          title: "Accessibility",
                          detail: permissions.accessibilityGranted
                              ? "Granted"
                              : "Click to allow this app to post click events",
                          granted: permissions.accessibilityGranted,
                          action: { permissions.openAccessibilitySettings() })
            Divider().padding(.leading, 48)
            permissionRow(iconName: "eye.fill",
                          iconColor: .orange,
                          title: "Input Monitoring",
                          detail: "Required for touch detection",
                          granted: touch.isRunning,
                          action: { permissions.openInputMonitoringSettings() })
        }
    }

    // MARK: – Footer

    private var footer: some View {
        HStack {
            Circle()
                .fill(touch.isRunning ? Color.green : Color.gray.opacity(0.5))
                .frame(width: 6, height: 6)
            Text(touch.isRunning ? "Mouse connected" : "No mouse detected")
                .font(.caption2)
                .foregroundStyle(touch.isRunning ? Color.green : Color.secondary)
            Spacer()
            Button("Quit") { NSApp.terminate(nil) }
                .buttonStyle(.plain).font(.caption).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    // MARK: – Helpers

    /// iOS-Settings-style icon: coloured rounded square with white SF Symbol.
    private func settingsIcon(_ name: String, color: Color) -> some View {
        Image(systemName: name)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 22, height: 22)
            .background(color.gradient)
            .clipShape(RoundedRectangle(cornerRadius: 5))
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title).font(.caption).fontWeight(.semibold)
                .foregroundStyle(.secondary).textCase(.uppercase)
            Spacer()
        }
        .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 2)
    }

    private func row<C: View>(@ViewBuilder content: () -> C) -> some View {
        HStack(spacing: 10) { content() }
            .padding(.horizontal, 16).padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor))
    }

    /// Indented slider row used as a sub-item under a toggle.
    private func subSliderRow(label: String, value: Binding<Double>,
                              range: ClosedRange<Double>, display: String) -> some View {
        row {
            Spacer().frame(width: 32)   // aligns with parent row's label (icon 22 + spacing 10)
            Text(label).font(.callout).foregroundStyle(.secondary)
            Slider(value: value, in: range, step: 0.01)
            Text(display)
                .monospacedDigit().foregroundStyle(.secondary).font(.caption)
                .frame(width: 46, alignment: .trailing)
        }
    }

    private func permissionRow(iconName: String, iconColor: Color,
                               title: String, detail: String,
                               granted: Bool,
                               action: @escaping () -> Void) -> some View {
        row {
            settingsIcon(iconName, color: granted ? .green : iconColor)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.callout)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if !granted {
                Button("Enable", action: action).buttonStyle(.bordered).controlSize(.small)
            }
        }
    }
}

#Preview { SettingsView() }
