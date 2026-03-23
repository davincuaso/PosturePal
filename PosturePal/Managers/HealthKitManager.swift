//
//  HealthKitManager.swift
//  PosturePal
//
//  Manages HealthKit integration for logging good posture time as Mindful Minutes
//  HealthKit is OPTIONAL - requires paid Apple Developer account
//

import Foundation
import Combine

// Conditional HealthKit import
#if canImport(HealthKit)
import HealthKit
#endif

final class HealthKitManager: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var isAuthorized = false
    @Published private(set) var isAvailable = false
    @Published private(set) var todayMindfulMinutes: Double = 0
    @Published private(set) var error: HealthKitError?

    // Local tracking when HealthKit unavailable
    @Published private(set) var sessionGoodPostureMinutes: Double = 0

    // MARK: - Private Properties
    #if canImport(HealthKit)
    private var healthStore: HKHealthStore?
    private var mindfulType: HKCategoryType?
    #endif
    private var currentSessionStart: Date?
    private var accumulatedGoodPostureTime: TimeInterval = 0

    enum HealthKitError: LocalizedError {
        case notAvailable
        case notEntitled
        case authorizationDenied
        case saveFailed(Error)

        var errorDescription: String? {
            switch self {
            case .notAvailable:
                return "HealthKit is not available on this device"
            case .notEntitled:
                return "HealthKit requires a paid Apple Developer account"
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
        #if canImport(HealthKit)
        guard HKHealthStore.isHealthDataAvailable() else {
            isAvailable = false
            error = .notAvailable
            return
        }

        // Try to create the health store - this will fail without entitlement
        healthStore = HKHealthStore()
        mindfulType = HKObjectType.categoryType(forIdentifier: .mindfulSession)
        isAvailable = true
        #else
        isAvailable = false
        error = .notAvailable
        #endif
    }

    /// Requests authorization to read and write mindful minutes
    func requestAuthorization() {
        #if canImport(HealthKit)
        guard isAvailable,
              let healthStore = healthStore,
              let mindfulType = mindfulType else {
            error = .notAvailable
            return
        }

        let typesToShare: Set<HKSampleType> = [mindfulType]
        let typesToRead: Set<HKObjectType> = [mindfulType]

        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { [weak self] success, authError in
            DispatchQueue.main.async {
                if success {
                    self?.checkAuthorizationStatus()
                    self?.fetchTodayMindfulMinutes()
                } else if let authError = authError {
                    // Check if it's an entitlement error
                    if authError.localizedDescription.contains("entitlement") ||
                       authError.localizedDescription.contains("Missing") {
                        self?.isAvailable = false
                        self?.error = .notEntitled
                    } else {
                        self?.error = .authorizationDenied
                    }
                }
            }
        }
        #else
        error = .notAvailable
        #endif
    }

    /// Starts tracking a good posture session
    func startGoodPostureSession() {
        if currentSessionStart == nil {
            currentSessionStart = Date()
        }
    }

    /// Ends the current good posture session and logs to HealthKit
    func endGoodPostureSession() {
        guard let startDate = currentSessionStart else { return }

        let endDate = Date()
        let duration = endDate.timeIntervalSince(startDate)

        // Only log if duration is at least 30 seconds
        guard duration >= 30 else {
            currentSessionStart = nil
            return
        }

        if isAuthorized {
            saveMindfulSession(start: startDate, end: endDate)
        }
        currentSessionStart = nil
    }

    /// Accumulates good posture time without immediately saving
    func accumulateGoodPostureTime(_ seconds: TimeInterval) {
        accumulatedGoodPostureTime += seconds
        sessionGoodPostureMinutes = accumulatedGoodPostureTime / 60.0
    }

    /// Saves accumulated good posture time to HealthKit
    func saveAccumulatedTime() {
        guard accumulatedGoodPostureTime >= 60 else { return }

        if isAuthorized {
            let endDate = Date()
            let startDate = endDate.addingTimeInterval(-accumulatedGoodPostureTime)
            saveMindfulSession(start: startDate, end: endDate)
        }
        accumulatedGoodPostureTime = 0
    }

    /// Resets session tracking
    func resetSession() {
        accumulatedGoodPostureTime = 0
        sessionGoodPostureMinutes = 0
    }

    /// Fetches today's total mindful minutes
    func fetchTodayMindfulMinutes() {
        #if canImport(HealthKit)
        guard isAuthorized,
              let healthStore = healthStore,
              let mindfulType = mindfulType else { return }

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
        ) { [weak self] _, samples, queryError in
            DispatchQueue.main.async {
                guard queryError == nil,
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
        #endif
    }

    // MARK: - Private Methods

    private func checkAuthorizationStatus() {
        #if canImport(HealthKit)
        guard let healthStore = healthStore,
              let mindfulType = mindfulType else {
            isAuthorized = false
            return
        }

        let status = healthStore.authorizationStatus(for: mindfulType)
        DispatchQueue.main.async {
            self.isAuthorized = status == .sharingAuthorized
        }
        #endif
    }

    private func saveMindfulSession(start: Date, end: Date) {
        #if canImport(HealthKit)
        guard let healthStore = healthStore,
              let mindfulType = mindfulType else { return }

        let sample = HKCategorySample(
            type: mindfulType,
            value: HKCategoryValue.notApplicable.rawValue,
            start: start,
            end: end
        )

        healthStore.save(sample) { [weak self] success, saveError in
            DispatchQueue.main.async {
                if success {
                    self?.fetchTodayMindfulMinutes()
                } else if let saveError = saveError {
                    self?.error = .saveFailed(saveError)
                }
            }
        }
        #endif
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
