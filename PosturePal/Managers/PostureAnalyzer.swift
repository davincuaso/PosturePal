//
//  PostureAnalyzer.swift
//  PosturePal
//
//  Analyzes body landmarks to determine posture quality using geometric calculations
//

import Foundation
import AudioToolbox
import Combine

enum PostureState: Equatable {
    case unknown
    case good
    case bad(angle: Double)

    var isGood: Bool {
        if case .good = self { return true }
        return false
    }
}

final class PostureAnalyzer: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var currentPosture: PostureState = .unknown
    @Published private(set) var currentAngle: Double = 0
    @Published private(set) var slouchDuration: TimeInterval = 0
    @Published private(set) var goodPostureDuration: TimeInterval = 0

    // MARK: - Configuration
    /// Angle threshold in degrees. If ear-to-shoulder angle exceeds this, posture is bad.
    /// A perfectly vertical line is 0 degrees. Forward head posture increases this angle.
    var angleThreshold: Double = 25.0

    /// Duration in seconds before triggering slouch alert
    var slouchAlertThreshold: TimeInterval = 5.0

    /// Enable/disable audio alerts
    var audioAlertsEnabled: Bool = true

    // MARK: - Private Properties
    private var slouchStartTime: Date?
    private var goodPostureStartTime: Date?
    private var lastAlertTime: Date?
    private var hasPlayedAlertForCurrentSlouch = false

    // Minimum time between alerts to avoid annoyance
    private let minimumAlertInterval: TimeInterval = 10.0

    // MARK: - Public Methods

    /// Analyzes the provided body landmarks and updates posture state
    func analyze(landmarks: BodyLandmarks) {
        guard landmarks.isValid,
              let earCenter = landmarks.earCenter,
              let shoulderCenter = landmarks.shoulderCenter else {
            currentPosture = .unknown
            resetSlouchTracking()
            return
        }

        // Calculate the angle between ear and shoulder
        let angle = calculatePostureAngle(ear: earCenter, shoulder: shoulderCenter)
        currentAngle = angle

        // Determine posture state based on angle
        if angle <= angleThreshold {
            handleGoodPosture()
        } else {
            handleBadPosture(angle: angle)
        }
    }

    /// Resets all tracking state
    func reset() {
        currentPosture = .unknown
        currentAngle = 0
        slouchDuration = 0
        goodPostureDuration = 0
        slouchStartTime = nil
        goodPostureStartTime = nil
        hasPlayedAlertForCurrentSlouch = false
    }

    // MARK: - Private Methods

    /// Calculates the forward head posture angle
    /// Returns angle in degrees from vertical (0 = perfect, higher = more forward lean)
    private func calculatePostureAngle(ear: CGPoint, shoulder: CGPoint) -> Double {
        // Calculate the horizontal offset (how far forward the ear is relative to shoulder)
        let deltaX = ear.x - shoulder.x
        // Calculate the vertical distance
        let deltaY = shoulder.y - ear.y // Positive when ear is above shoulder

        // Guard against division by zero
        guard abs(deltaY) > 0.001 else {
            return abs(deltaX) > 0.1 ? 90.0 : 0.0
        }

        // Calculate angle from vertical using arctangent
        // When ear is directly above shoulder, angle is 0
        // When ear moves forward (in screen space), angle increases
        let angleRadians = atan2(abs(deltaX), abs(deltaY))
        let angleDegrees = angleRadians * 180.0 / .pi

        return angleDegrees
    }

    private func handleGoodPosture() {
        currentPosture = .good
        resetSlouchTracking()

        // Track good posture duration
        if goodPostureStartTime == nil {
            goodPostureStartTime = Date()
        } else if let startTime = goodPostureStartTime {
            goodPostureDuration = Date().timeIntervalSince(startTime)
        }
    }

    private func handleBadPosture(angle: Double) {
        currentPosture = .bad(angle: angle)

        // Reset good posture tracking
        goodPostureStartTime = nil
        goodPostureDuration = 0

        // Track slouch duration
        if slouchStartTime == nil {
            slouchStartTime = Date()
            hasPlayedAlertForCurrentSlouch = false
        }

        if let startTime = slouchStartTime {
            slouchDuration = Date().timeIntervalSince(startTime)

            // Check if we should play alert
            if slouchDuration >= slouchAlertThreshold && !hasPlayedAlertForCurrentSlouch {
                playSlouchAlert()
                hasPlayedAlertForCurrentSlouch = true
            }
        }
    }

    private func resetSlouchTracking() {
        slouchStartTime = nil
        slouchDuration = 0
        hasPlayedAlertForCurrentSlouch = false
    }

    private func playSlouchAlert() {
        guard audioAlertsEnabled else { return }

        // Check minimum interval between alerts
        if let lastAlert = lastAlertTime,
           Date().timeIntervalSince(lastAlert) < minimumAlertInterval {
            return
        }

        lastAlertTime = Date()

        // Play subtle system sound (soft notification)
        AudioServicesPlaySystemSound(1519) // Subtle tap/notification sound
    }
}

// MARK: - Angle Calculation Extension
extension PostureAnalyzer {
    /// Alternative method using neck as reference point
    func analyzeWithNeck(landmarks: BodyLandmarks) -> Double? {
        guard let earCenter = landmarks.earCenter,
              let neck = landmarks.neck,
              let shoulderCenter = landmarks.shoulderCenter else {
            return nil
        }

        // Calculate angle using three points: ear, neck, shoulder
        // This gives a more accurate representation of cervical spine angle
        let angle = calculateAngleBetweenThreePoints(
            point1: earCenter,
            vertex: neck,
            point2: shoulderCenter
        )

        return angle
    }

    /// Calculates angle at vertex between two lines
    private func calculateAngleBetweenThreePoints(
        point1: CGPoint,
        vertex: CGPoint,
        point2: CGPoint
    ) -> Double {
        let vector1 = CGPoint(x: point1.x - vertex.x, y: point1.y - vertex.y)
        let vector2 = CGPoint(x: point2.x - vertex.x, y: point2.y - vertex.y)

        let dot = vector1.x * vector2.x + vector1.y * vector2.y
        let mag1 = sqrt(vector1.x * vector1.x + vector1.y * vector1.y)
        let mag2 = sqrt(vector2.x * vector2.x + vector2.y * vector2.y)

        guard mag1 > 0 && mag2 > 0 else { return 0 }

        let cosAngle = dot / (mag1 * mag2)
        let clampedCos = max(-1, min(1, cosAngle))
        let angleRadians = acos(clampedCos)

        return angleRadians * 180.0 / .pi
    }
}
