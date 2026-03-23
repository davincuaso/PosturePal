//
//  SettingsView.swift
//  PosturePal
//
//  Settings screen for adjusting posture thresholds and preferences
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: PostureViewModel
    @EnvironmentObject var healthKitManager: HealthKitManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            // Posture Settings
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Angle Threshold")
                        Spacer()
                        Text("\(Int(viewModel.angleThreshold))")
                            .foregroundColor(.secondary)
                    }

                    Slider(value: $viewModel.angleThreshold, in: 15...45, step: 1)
                        .tint(.blue)

                    Text("Lower values are stricter. Default is 25.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Posture Sensitivity")
            }

            // Alerts Section
            Section {
                Toggle("Audio Alerts", isOn: $viewModel.audioAlertsEnabled)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Alert Delay: 5 seconds")
                        .foregroundColor(.primary)
                    Text("You'll be alerted after slouching for 5 seconds")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Notifications")
            }

            // HealthKit Section
            Section {
                HStack {
                    Text("Status")
                    Spacer()
                    if !healthKitManager.isAvailable {
                        Label("Unavailable", systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                    } else if healthKitManager.isAuthorized {
                        Label("Connected", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Label("Not Connected", systemImage: "xmark.circle.fill")
                            .foregroundColor(.red)
                    }
                }

                if healthKitManager.isAvailable && !healthKitManager.isAuthorized {
                    Button(action: {
                        healthKitManager.requestAuthorization()
                    }) {
                        HStack {
                            Image(systemName: "heart.text.square")
                            Text("Connect Apple Health")
                        }
                    }
                }

                if healthKitManager.isAvailable && healthKitManager.isAuthorized {
                    HStack {
                        Text("Today's Mindful Minutes")
                        Spacer()
                        Text(String(format: "%.0f min", healthKitManager.todayMindfulMinutes))
                            .foregroundColor(.secondary)
                    }
                }

                HStack {
                    Text("Session Good Posture")
                    Spacer()
                    Text(String(format: "%.1f min", healthKitManager.sessionGoodPostureMinutes))
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Apple Health")
            } footer: {
                if healthKitManager.isAvailable {
                    Text("Good posture time is logged as Mindful Minutes in Apple Health.")
                } else {
                    Text("HealthKit requires a paid Apple Developer account ($99/year). Session stats are tracked locally.")
                }
            }

            // About Section
            Section {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("How It Works")
                        .font(.headline)

                    Text("PosturePal uses your front camera and on-device machine learning to track your upper body position. It calculates the angle between your ears and shoulders to detect forward head posture (slouching).")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("No video is recorded or transmitted. All processing happens on your device.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
                .padding(.vertical, 4)
            } header: {
                Text("About")
            }

            // Tips Section
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    TipRow(
                        icon: "laptopcomputer",
                        title: "Position Your Device",
                        description: "Place your device at eye level, about arm's length away"
                    )

                    TipRow(
                        icon: "sun.max.fill",
                        title: "Good Lighting",
                        description: "Ensure your face and shoulders are well-lit for accurate detection"
                    )

                    TipRow(
                        icon: "figure.stand",
                        title: "Sit Properly",
                        description: "Keep your ears aligned above your shoulders"
                    )
                }
            } header: {
                Text("Tips for Best Results")
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct TipRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    NavigationView {
        SettingsView(viewModel: PostureViewModel())
            .environmentObject(HealthKitManager())
    }
}
