//
//  PostureIndicatorView.swift
//  PosturePal
//
//  Visual feedback indicator for posture state (green/red circle)
//

import SwiftUI

struct PostureIndicatorView: View {
    let postureState: PostureState
    let angle: Double
    let slouchDuration: TimeInterval

    private var indicatorColor: Color {
        switch postureState {
        case .unknown:
            return .gray
        case .good:
            return .green
        case .bad:
            return slouchDuration >= 5 ? .red : .orange
        }
    }

    private var statusText: String {
        switch postureState {
        case .unknown:
            return "Detecting..."
        case .good:
            return "Good Posture"
        case .bad:
            return "Adjust Posture"
        }
    }

    private var pulseAnimation: Bool {
        if case .bad = postureState, slouchDuration >= 5 {
            return true
        }
        return false
    }

    var body: some View {
        VStack(spacing: 16) {
            // Main indicator circle
            ZStack {
                // Outer glow
                Circle()
                    .fill(indicatorColor.opacity(0.3))
                    .frame(width: 120, height: 120)
                    .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                    .animation(
                        pulseAnimation ?
                            .easeInOut(duration: 0.8).repeatForever(autoreverses: true) :
                            .default,
                        value: pulseAnimation
                    )

                // Inner circle
                Circle()
                    .fill(indicatorColor)
                    .frame(width: 80, height: 80)
                    .shadow(color: indicatorColor.opacity(0.5), radius: 10)

                // Icon
                Image(systemName: iconName)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
            }

            // Status text
            Text(statusText)
                .font(.headline)
                .foregroundColor(indicatorColor)

            // Angle display
            if postureState != .unknown {
                Text(String(format: "Angle: %.1f", angle))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Slouch timer (only show when slouching)
            if case .bad = postureState, slouchDuration > 0 {
                HStack {
                    Image(systemName: "timer")
                    Text(formatDuration(slouchDuration))
                }
                .font(.caption)
                .foregroundColor(.orange)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.2))
                .cornerRadius(12)
            }
        }
    }

    private var iconName: String {
        switch postureState {
        case .unknown:
            return "figure.stand"
        case .good:
            return "checkmark"
        case .bad:
            return "exclamationmark"
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let seconds = Int(duration)
        if seconds < 60 {
            return "\(seconds)s"
        } else {
            let minutes = seconds / 60
            let remainingSeconds = seconds % 60
            return "\(minutes)m \(remainingSeconds)s"
        }
    }
}

#Preview {
    VStack(spacing: 40) {
        PostureIndicatorView(postureState: .good, angle: 15.0, slouchDuration: 0)
        PostureIndicatorView(postureState: .bad(angle: 35.0), angle: 35.0, slouchDuration: 3)
        PostureIndicatorView(postureState: .bad(angle: 40.0), angle: 40.0, slouchDuration: 8)
        PostureIndicatorView(postureState: .unknown, angle: 0, slouchDuration: 0)
    }
    .padding()
}
