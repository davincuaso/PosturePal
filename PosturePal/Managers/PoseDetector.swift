//
//  PoseDetector.swift
//  PosturePal
//
//  Processes camera frames using Vision framework for body pose detection
//

import Vision
import CoreMedia
import simd

struct BodyLandmarks {
    let leftEar: CGPoint?
    let rightEar: CGPoint?
    let leftShoulder: CGPoint?
    let rightShoulder: CGPoint?
    let neck: CGPoint?

    var isValid: Bool {
        // Need at least one ear and one shoulder for posture analysis
        return (leftEar != nil || rightEar != nil) &&
               (leftShoulder != nil || rightShoulder != nil)
    }

    // Computed average ear position
    var earCenter: CGPoint? {
        switch (leftEar, rightEar) {
        case let (left?, right?):
            return CGPoint(x: (left.x + right.x) / 2, y: (left.y + right.y) / 2)
        case let (left?, nil):
            return left
        case let (nil, right?):
            return right
        case (nil, nil):
            return nil
        }
    }

    // Computed average shoulder position
    var shoulderCenter: CGPoint? {
        switch (leftShoulder, rightShoulder) {
        case let (left?, right?):
            return CGPoint(x: (left.x + right.x) / 2, y: (left.y + right.y) / 2)
        case let (left?, nil):
            return left
        case let (nil, right?):
            return right
        case (nil, nil):
            return nil
        }
    }
}

protocol PoseDetectorDelegate: AnyObject {
    func poseDetector(_ detector: PoseDetector, didDetect landmarks: BodyLandmarks)
    func poseDetector(_ detector: PoseDetector, didFailWithError error: Error)
}

final class PoseDetector {
    weak var delegate: PoseDetectorDelegate?

    private let requestHandler = VNSequenceRequestHandler()
    private var bodyPoseRequest: VNDetectHumanBodyPoseRequest?

    init() {
        setupRequest()
    }

    private func setupRequest() {
        bodyPoseRequest = VNDetectHumanBodyPoseRequest { [weak self] request, error in
            guard let self = self else { return }

            if let error = error {
                DispatchQueue.main.async {
                    self.delegate?.poseDetector(self, didFailWithError: error)
                }
                return
            }

            self.processResults(request.results)
        }
    }

    func processFrame(_ sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              let request = bodyPoseRequest else {
            return
        }

        do {
            try requestHandler.perform([request], on: pixelBuffer, orientation: .up)
        } catch {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.poseDetector(self, didFailWithError: error)
            }
        }
    }

    private func processResults(_ results: [Any]?) {
        guard let observations = results as? [VNHumanBodyPoseObservation],
              let observation = observations.first else {
            // No body detected - send empty landmarks
            let emptyLandmarks = BodyLandmarks(
                leftEar: nil,
                rightEar: nil,
                leftShoulder: nil,
                rightShoulder: nil,
                neck: nil
            )
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.poseDetector(self, didDetect: emptyLandmarks)
            }
            return
        }

        let landmarks = extractLandmarks(from: observation)

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.poseDetector(self, didDetect: landmarks)
        }
    }

    private func extractLandmarks(from observation: VNHumanBodyPoseObservation) -> BodyLandmarks {
        let leftEar = getPoint(for: .leftEar, from: observation)
        let rightEar = getPoint(for: .rightEar, from: observation)
        let leftShoulder = getPoint(for: .leftShoulder, from: observation)
        let rightShoulder = getPoint(for: .rightShoulder, from: observation)
        let neck = getPoint(for: .neck, from: observation)

        return BodyLandmarks(
            leftEar: leftEar,
            rightEar: rightEar,
            leftShoulder: leftShoulder,
            rightShoulder: rightShoulder,
            neck: neck
        )
    }

    private func getPoint(
        for jointName: VNHumanBodyPoseObservation.JointName,
        from observation: VNHumanBodyPoseObservation
    ) -> CGPoint? {
        guard let recognizedPoint = try? observation.recognizedPoint(jointName),
              recognizedPoint.confidence > 0.3 else {
            return nil
        }

        // Vision coordinates are normalized (0-1) with origin at bottom-left
        // Convert to standard UIKit coordinates (origin top-left)
        return CGPoint(
            x: recognizedPoint.location.x,
            y: 1 - recognizedPoint.location.y
        )
    }
}
