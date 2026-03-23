//
//  HealthKitManager.swift
//  PosturePal
//
//  Manages HealthKit integration for logging good posture time as Mindful Minutes
//

import HealthKit
import Combine

final class HealthKitManager: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var isAuthorized = false
    @Published private(set) var authorizationStatus: HKAuthorizationStatus = .notDetermined
    @Published private(set) var todayMindfulMinutes: Double = 0
    @Published private(set) var error: HealthKitError?

    // MARK: - Private Properties
    private let healthStore = HKHealthStore()
    private var currentSessionStart: Date?
    private var accumulatedGoodPostureTime: TimeInterval = 0

    // Mindful minutes type
    private let mindfulType = HKObjectType.categoryType(forIdentifier: .mindfulSession)!

    enum HealthKitError: LocalizedError {
        case notAvailable
        case authorizationDenied
        case saveFailed(Error)

        var errorDescription: String? {
            switch self {
            case .notAvailable:
                return "HealthKit is not available on this device"
            case .authorizationDenied:
                return "HealthKit authorization was denied"
            case .saveFailed(let error):
                return "Failed to save health data: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Initialization
    init() {
        checkAvailability()
    }

    // MARK: - Public Methods

    /// Checks if HealthKit is available on this device
    func checkAvailability() {
        guard HKHealthStore.isHealthDataAvailable() else {
            error = .notAvailable
            return
        }
        checkAuthorizationStatus()
    }

    /// Requests authorization to read and write mindful minutes
    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else {
            error = .notAvailable
            return
        }

        let typesToShare: Set<HKSampleType> = [mindfulType]
        let typesToRead: Set<HKObjectType> = [mindfulType]

        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    self?.checkAuthorizationStatus()
                    self?.fetchTodayMindfulMinutes()
                } else if error != nil {
                    self?.error = .authorizationDenied
                }
            }
        }
    }

    /// Starts tracking a good posture session
    func startGoodPostureSession() {
        guard isAuthorized else { return }
        if currentSessionStart == nil {
            currentSessionStart = Date()
        }
    }

    /// Ends the current good posture session and logs to HealthKit
    func endGoodPostureSession() {
        guard isAuthorized,
              let startDate = currentSessionStart else {
            return
        }

        let endDate = Date()
        let duration = endDate.timeIntervalSince(startDate)

        // Only log if duration is at least 30 seconds
        guard duration >= 30 else {
            currentSessionStart = nil
            return
        }

        saveMindfulSession(start: startDate, end: endDate)
        currentSessionStart = nil
    }

    /// Accumulates good posture time without immediately saving
    func accumulateGoodPostureTime(_ seconds: TimeInterval) {
        accumulatedGoodPostureTime += seconds
    }

    /// Saves accumulated good posture time to HealthKit
    func saveAccumulatedTime() {
        guard isAuthorized, accumulatedGoodPostureTime >= 60 else { return }

        let endDate = Date()
        let startDate = endDate.addingTimeInterval(-accumulatedGoodPostureTime)

        saveMindfulSession(start: startDate, end: endDate)
        accumulatedGoodPostureTime = 0
    }

    /// Fetches today's total mindful minutes
    func fetchTodayMindfulMinutes() {
        guard isAuthorized else { return }

        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)

        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: now,
            options: .strictStartDate
        )

        let query = HKSampleQuery(
            sampleType: mindfulType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: nil
        ) { [weak self] _, samples, error in
            DispatchQueue.main.async {
                guard error == nil,
                      let samples = samples as? [HKCategorySample] else {
                    return
                }

                let totalSeconds = samples.reduce(0.0) { total, sample in
                    total + sample.endDate.timeIntervalSince(sample.startDate)
                }

                self?.todayMindfulMinutes = totalSeconds / 60.0
            }
        }

        healthStore.execute(query)
    }

    // MARK: - Private Methods

    private func checkAuthorizationStatus() {
        let status = healthStore.authorizationStatus(for: mindfulType)
        DispatchQueue.main.async {
            self.authorizationStatus = status
            self.isAuthorized = status == .sharingAuthorized
        }
    }

    private func saveMindfulSession(start: Date, end: Date) {
        let sample = HKCategorySample(
            type: mindfulType,
            value: HKCategoryValue.notApplicable.rawValue,
            start: start,
            end: end
        )

        healthStore.save(sample) { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    self?.fetchTodayMindfulMinutes()
                } else if let error = error {
                    self?.error = .saveFailed(error)
                }
            }
        }
    }
}

// MARK: - Session Tracking Extension
extension HealthKitManager {
    /// Tracks good posture intervals and batches them for HealthKit
    final class PostureSessionTracker {
        private var intervals: [(start: Date, end: Date)] = []
        private var currentStart: Date?

        func startInterval() {
            if currentStart == nil {
                currentStart = Date()
            }
        }

        func endInterval() {
            guard let start = currentStart else { return }
            let end = Date()

            // Only track intervals longer than 10 seconds
            if end.timeIntervalSince(start) >= 10 {
                intervals.append((start, end))
            }
            currentStart = nil
        }

        func getTotalDuration() -> TimeInterval {
            let completedDuration = intervals.reduce(0.0) { $0 + $1.end.timeIntervalSince($1.start) }
            let currentDuration = currentStart.map { Date().timeIntervalSince($0) } ?? 0
            return completedDuration + currentDuration
        }

        func reset() -> [(start: Date, end: Date)] {
            if let start = currentStart {
                intervals.append((start, Date()))
            }
            let result = intervals
            intervals = []
            currentStart = nil
            return result
        }
    }
}
