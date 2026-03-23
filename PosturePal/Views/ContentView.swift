//
//  ContentView.swift
//  PosturePal
//
//  Main view coordinating camera, pose detection, and UI feedback
//

import SwiftUI
import AVFoundation

struct ContentView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @StateObject private var viewModel = PostureViewModel()

    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Camera preview area
                    if viewModel.cameraPermissionGranted {
                        cameraPreviewSection
                    } else {
                        permissionRequestSection
                    }

                    // Control panel
                    controlPanelSection
                }
            }
            .navigationTitle("PosturePal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: SettingsView(viewModel: viewModel)) {
                        Image(systemName: "gear")
                    }
                }
            }
        }
        .onAppear {
            viewModel.setHealthKitManager(healthKitManager)
        }
    }

    // MARK: - Camera Preview Section
    private var cameraPreviewSection: some View {
        ZStack {
            // Camera feed
            if let previewLayer = viewModel.previewLayer {
                CameraPreviewView(previewLayer: previewLayer)
                    .aspectRatio(3/4, contentMode: .fit)
                    .cornerRadius(20)
                    .padding()
            }

            // Overlay with posture indicator
            VStack {
                Spacer()

                PostureIndicatorView(
                    postureState: viewModel.postureState,
                    angle: viewModel.currentAngle,
                    slouchDuration: viewModel.slouchDuration
                )
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.black.opacity(0.7))
                )
                .padding(.bottom, 20)
            }
        }
    }

    // MARK: - Permission Request Section
    private var permissionRequestSection: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "camera.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("Camera Access Required")
                .font(.title2)
                .fontWeight(.semibold)

            Text("PosturePal needs camera access to monitor your posture. No video is recorded or stored.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button(action: {
                viewModel.requestCameraPermission()
            }) {
                Text("Enable Camera")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)

            Spacer()
        }
        .foregroundColor(.white)
    }

    // MARK: - Control Panel Section
    private var controlPanelSection: some View {
        VStack(spacing: 16) {
            // Stats row
            HStack(spacing: 30) {
                StatView(
                    title: "Good Posture",
                    value: viewModel.formatDuration(viewModel.goodPostureDuration),
                    icon: "checkmark.circle.fill",
                    color: .green
                )

                if healthKitManager.isAvailable && healthKitManager.isAuthorized {
                    StatView(
                        title: "Mindful Today",
                        value: String(format: "%.0f min", healthKitManager.todayMindfulMinutes),
                        icon: "heart.fill",
                        color: .pink
                    )
                } else {
                    StatView(
                        title: "Session Total",
                        value: String(format: "%.1f min", healthKitManager.sessionGoodPostureMinutes),
                        icon: "clock.fill",
                        color: .blue
                    )
                }
            }
            .padding(.top, 16)

            // Start/Stop button
            Button(action: {
                viewModel.toggleMonitoring()
            }) {
                HStack {
                    Image(systemName: viewModel.isMonitoring ? "stop.fill" : "play.fill")
                    Text(viewModel.isMonitoring ? "Stop Monitoring" : "Start Monitoring")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(viewModel.isMonitoring ? Color.red : Color.green)
                .cornerRadius(12)
            }
            .padding(.horizontal, 20)
            .disabled(!viewModel.cameraPermissionGranted)
            .opacity(viewModel.cameraPermissionGranted ? 1 : 0.5)

            // HealthKit status/button
            if healthKitManager.isAvailable {
                if !healthKitManager.isAuthorized {
                    Button(action: {
                        healthKitManager.requestAuthorization()
                    }) {
                        HStack {
                            Image(systemName: "heart.text.square")
                            Text("Connect Apple Health")
                        }
                        .font(.subheadline)
                        .foregroundColor(.pink)
                    }
                    .padding(.bottom, 8)
                }
            } else {
                Text("HealthKit unavailable (requires paid developer account)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 8)
            }
        }
        .padding(.bottom, 20)
        .background(Color(.systemBackground))
    }
}

// MARK: - Stat View
struct StatView: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.title3)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(HealthKitManager())
}
