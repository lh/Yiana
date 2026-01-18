//
//  DevModeManager.swift
//  Yiana
//
//  Manages developer mode state. Unlocked by tapping/clicking
//  the version number 7 times in Settings.
//

import SwiftUI

@MainActor
final class DevModeManager: ObservableObject {
    static let shared = DevModeManager()

    private let requiredTaps = 7
    private let tapTimeout: TimeInterval = 2.0 // Reset if no tap within 2 seconds

    /// Dev mode is always OFF on app launch - must tap 7 times each session
    @Published private(set) var isEnabled: Bool = false

    @Published private(set) var tapCount: Int = 0
    private var lastTapTime: Date = .distantPast

    private init() {
        // Always starts disabled - no persistence across sessions
    }

    /// Call this when the version label is tapped/clicked
    func registerTap() {
        let now = Date()

        // Reset count if too much time has passed
        if now.timeIntervalSince(lastTapTime) > tapTimeout {
            tapCount = 0
        }

        tapCount += 1
        lastTapTime = now

        if tapCount >= requiredTaps {
            if !isEnabled {
                isEnabled = true
                tapCount = 0
            }
        }
    }

    /// Disable dev mode
    func disable() {
        isEnabled = false
        tapCount = 0
    }

    /// Message to show based on tap progress
    var progressMessage: String? {
        guard tapCount >= 3 && !isEnabled else { return nil }
        let remaining = requiredTaps - tapCount
        if remaining == 1 {
            return "1 more tap to enable developer mode"
        } else {
            return "\(remaining) more taps to enable developer mode"
        }
    }
}

// MARK: - View Modifier for tap-to-unlock

struct DevModeTapModifier: ViewModifier {
    @ObservedObject private var devMode = DevModeManager.shared
    @State private var showingToast = false

    func body(content: Content) -> some View {
        content
            .onTapGesture {
                devMode.registerTap()
                if devMode.progressMessage != nil {
                    showingToast = true
                }
                if devMode.isEnabled && devMode.tapCount == 0 {
                    // Just enabled
                    showingToast = true
                }
            }
            .overlay(alignment: .bottom) {
                if showingToast {
                    toastView
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                withAnimation {
                                    showingToast = false
                                }
                            }
                        }
                }
            }
            .animation(.easeInOut(duration: 0.2), value: showingToast)
    }

    @ViewBuilder
    private var toastView: some View {
        if devMode.isEnabled && devMode.tapCount == 0 {
            Text("Developer mode enabled")
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.9))
                .foregroundColor(.white)
                .cornerRadius(8)
                .padding(.bottom, 8)
        } else if let message = devMode.progressMessage {
            Text(message)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.secondary.opacity(0.9))
                .foregroundColor(.white)
                .cornerRadius(8)
                .padding(.bottom, 8)
        }
    }
}

extension View {
    /// Makes this view tappable to unlock developer mode (7 taps)
    func devModeTapTarget() -> some View {
        modifier(DevModeTapModifier())
    }
}
