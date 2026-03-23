//
//  PostureViewModel.swift
//  PosturePal
//
//  Coordinates camera, pose detection, and posture analysis
//

import SwiftUI
import AVFoundation
import Combine

@MainActor
final class PostureViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var isMonitoring = false
    @Published private(set) var postureState: PostureState = .unknown
    @Published private(set) var currentAngle: Double = 0
    @Published private(set) var slouchDuration: TimeInterval = 0
    @Published private(set) var goodPostureDuration: TimeInterval = 0
    @Published private(set) var cameraPermissionGranted = false
    @Published var angleThreshold: Double = 25.0 {
        didSet { postureAnalyzer.angleThreshold = angleThreshold }
    }
    @Published var audioAlertsEnabled: Bool = true {
        didSet { postureAnalyzer.audioAlertsEnabled = audioAlertsEnabled }
    }

    // MARK: - Camera Properties
    private(set) var previewLayer: AVCaptureVideoPreviewLayer?

    // MARK: - Private Properties
    private let cameraManager = CameraManager()
    private let poseDetector = PoseDetector()
    private let postureAnalyzer = PostureAnalyzer()
    private var healthKitManager: HealthKitManager?
    private var cancellables = Set<AnyCancellable>()
    private var sessionTracker = HealthKitManager.PostureSessionTracker()
    private var healthKitSaveTimer: Timer?

    // MARK: - Initialization
    init() {
        setupBindings()
        setupDelegates()
    }

    // MARK: - Public Methods

    func setHealthKitManager(_ manager: HealthKitManager) {
        self.healthKitManager = manager
    }

    func requestCameraPermission() {
        cameraManager.checkPermission()
    }

    func toggleMonitoring() {
        if isMonitoring {
            stopMonitoring()
        } else {
            startMonitoring()
        }
    }

    func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60

        if minutes > 0 {
            return String(format: "%dm %ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }

    // MARK: - Private Methods

    private func setupBindings() {
        // Camera permission
        cameraManager.$permissionGranted
            .receive(on: DispatchQueue.main)
            .sink { [weak self] granted in
                self?.cameraPermissionGranted = granted
                if granted {
                    self?.previewLayer = self?.cameraManager.getPreviewLayer()
                }
            }
            .store(in: &cancellables)

        // Posture analyzer bindings
        postureAnalyzer.$currentPosture
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.postureState = state
                self?.handlePostureStateChange(state)
            }
            .store(in: &cancellables)

        postureAnalyzer.$currentAngle
            .receive(on: DispatchQueue.main)
            .assign(to: &$currentAngle)

        postureAnalyzer.$slouchDuration
            .receive(on: DispatchQueue.main)
            .assign(to: &$slouchDuration)

        postureAnalyzer.$goodPostureDuration
            .receive(on: DispatchQueue.main)
            .assign(to: &$goodPostureDuration)
    }

    private func setupDelegates() {
        cameraManager.delegate = self
        poseDetector.delegate = self
    }

    private func startMonitoring() {
        cameraManager.startSession()
        isMonitoring = true
        postureAnalyzer.reset()
        sessionTracker = HealthKitManager.PostureSessionTracker()

        // Start periodic HealthKit saves
        healthKitSaveTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.saveToHealthKit()
        }
    }

    private func stopMonitoring() {
        cameraManager.stopSession()
        isMonitoring = false
        healthKitSaveTimer?.invalidate()
        healthKitSaveTimer = nil

        // Save any remaining good posture time
        saveToHealthKit()
    }

    private func handlePostureStateChange(_ state: PostureState) {
        switch state {
        case .good:
            sessionTracker.startInterval()
        case .bad, .unknown:
            sessionTracker.endInterval()
        }
    }

    private func saveToHealthKit() {
        let intervals = sessionTracker.reset()

        for interval in intervals {
            let duration = interval.end.timeIntervalSince(interval.start)
            if duration >= 60 {
                healthKitManager?.accumulateGoodPostureTime(duration)
            }
        }

        healthKitManager?.saveAccumulatedTime()
    }
}

// MARK: - CameraManagerDelegate
extension PostureViewModel: CameraManagerDelegate {
    nonisolated func cameraManager(_ manager: CameraManager, didOutput sampleBuffer: CMSampleBuffer) {
        poseDetector.processFrame(sampleBuffer)
    }
}

// MARK: - PoseDetectorDelegate
extension PostureViewModel: PoseDetectorDelegate {
    nonisolated func poseDetector(_ detector: PoseDetector, didDetect landmarks: BodyLandmarks) {
        Task { @MainActor in
            postureAnalyzer.analyze(landmarks: landmarks)
        }
    }

    nonisolated func poseDetector(_ detector: PoseDetector, didFailWithError error: Error) {
        // Log error but continue processing
        print("Pose detection error: \(error.localizedDescription)")
    }
}
