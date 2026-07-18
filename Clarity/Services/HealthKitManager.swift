import Foundation
import Combine
import SwiftData
#if canImport(HealthKit) && os(iOS)
import HealthKit
#endif

/// A single workout as reported by HealthKit, before it's merged into SwiftData.
struct HealthKitWorkoutSummary {
    let uuid: String
    let type: WorkoutType
    let start: Date
    let durationMinutes: Int
    let calories: Double?
    let distanceMeters: Double?
}

/// Reads step count, active energy, heart rate, sleep, and workouts from Apple
/// Health. Every read is additive — Clarity always works from manual entry
/// alone; this manager just fills in what a device already knows, on
/// platforms where HealthKit exists and the user has granted access.
@MainActor
final class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()

    @Published var isAuthorized = false

    private init() {}

    var isAvailable: Bool {
        #if canImport(HealthKit) && os(iOS)
        return HKHealthStore.isHealthDataAvailable()
        #else
        return false
        #endif
    }

    #if canImport(HealthKit) && os(iOS)

    private let store = HKHealthStore()

    func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }
        guard
            let steps = HKObjectType.quantityType(forIdentifier: .stepCount),
            let energy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned),
            let restingHeartRate = HKObjectType.quantityType(forIdentifier: .restingHeartRate),
            let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis),
            let weight = HKObjectType.quantityType(forIdentifier: .bodyMass)
        else { return false }

        let readTypes: Set<HKObjectType> = [steps, energy, restingHeartRate, sleep, weight, HKObjectType.workoutType()]

        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            isAuthorized = true
            return true
        } catch {
            print("HealthKit authorization failed: \(error)")
            isAuthorized = false
            return false
        }
    }

    // MARK: - Point reads

    func fetchTodaySteps() async -> Int? {
        guard isAvailable else { return nil }
        let start = Calendar.current.startOfDay(for: Date())
        let value = await sumQuantity(identifier: .stepCount, unit: .count(), start: start, end: Date())
        return value.map { Int($0) }
    }

    func fetchTodayActiveEnergy() async -> Double? {
        guard isAvailable else { return nil }
        let start = Calendar.current.startOfDay(for: Date())
        return await sumQuantity(identifier: .activeEnergyBurned, unit: .kilocalorie(), start: start, end: Date())
    }

    func fetchRestingHeartRate() async -> Int? {
        guard isAvailable else { return nil }
        let start = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        let value = await averageQuantity(identifier: .restingHeartRate, unit: HKUnit(from: "count/min"), start: start, end: Date())
        return value.map { Int($0.rounded()) }
    }

    func fetchLastNightSleepHours() async -> Double? {
        guard isAvailable else { return nil }
        // Look back ~20 hours to catch a typical overnight sleep window
        let start = Calendar.current.date(byAdding: .hour, value: -20, to: Date()) ?? Date()
        return await fetchSleepHours(start: start, end: Date())
    }

    func fetchLatestWeightKg() async -> Double? {
        guard isAvailable else { return nil }
        guard let weightType = HKObjectType.quantityType(forIdentifier: .bodyMass) else { return nil }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: weightType, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                let value = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: .gramUnit(with: .kilo))
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    func fetchRecentWorkouts(limit: Int = 20) async -> [HealthKitWorkoutSummary] {
        guard isAvailable else { return [] }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: HKObjectType.workoutType(), predicate: nil, limit: limit, sortDescriptors: [sort]) { _, samples, _ in
                let summaries = (samples as? [HKWorkout] ?? []).map { workout in
                    HealthKitWorkoutSummary(
                        uuid: workout.uuid.uuidString,
                        type: Self.workoutType(for: workout.workoutActivityType),
                        start: workout.startDate,
                        durationMinutes: max(1, Int(workout.duration / 60)),
                        calories: workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()),
                        distanceMeters: workout.totalDistance?.doubleValue(for: .meter())
                    )
                }
                continuation.resume(returning: summaries)
            }
            store.execute(query)
        }
    }

    // MARK: - Sync into SwiftData

    /// Pulls today's activity + recent workouts and merges them into
    /// BodyMetric/Workout, tagging everything `source == "healthKit"` so the
    /// UI can badge it and so re-syncing doesn't create duplicates.
    func syncToday(context: ModelContext, userEmail: String) async {
        guard isAvailable, isAuthorized else { return }

        async let stepsTask = fetchTodaySteps()
        async let energyTask = fetchTodayActiveEnergy()
        async let heartRateTask = fetchRestingHeartRate()
        async let sleepTask = fetchLastNightSleepHours()
        async let weightTask = fetchLatestWeightKg()
        async let workoutsTask = fetchRecentWorkouts(limit: 15)

        let stepsValue = await stepsTask
        let energyValue = await energyTask
        let heartRateValue = await heartRateTask
        let sleepValue = await sleepTask
        let weightValue = await weightTask
        let workoutSummaries = await workoutsTask

        let today = Calendar.current.startOfDay(for: Date())
        let metricDescriptor = FetchDescriptor<BodyMetric>(
            predicate: #Predicate<BodyMetric> { $0.ownerEmail == userEmail && $0.date >= today }
        )

        if let existing = try? context.fetch(metricDescriptor).first {
            existing.steps = stepsValue
            existing.activeEnergyKcal = energyValue
            existing.restingHeartRate = heartRateValue
            existing.sleepHours = sleepValue
            if let weightValue { existing.weightKg = weightValue }
            existing.source = "healthKit"
        } else {
            let metric = BodyMetric(
                ownerEmail: userEmail,
                date: Date(),
                steps: stepsValue,
                activeEnergyKcal: energyValue,
                restingHeartRate: heartRateValue,
                sleepHours: sleepValue,
                weightKg: weightValue,
                source: "healthKit"
            )
            context.insert(metric)
        }

        let workoutDescriptor = FetchDescriptor<Workout>(
            predicate: #Predicate<Workout> { $0.ownerEmail == userEmail && $0.source == "healthKit" }
        )
        let existingUUIDs = Set(((try? context.fetch(workoutDescriptor)) ?? []).compactMap { $0.healthKitUUID })

        for summary in workoutSummaries where !existingUUIDs.contains(summary.uuid) {
            let workout = Workout(
                ownerEmail: userEmail,
                type: summary.type,
                date: summary.start,
                durationMinutes: summary.durationMinutes,
                caloriesBurned: summary.calories,
                distanceMeters: summary.distanceMeters,
                source: "healthKit",
                healthKitUUID: summary.uuid
            )
            context.insert(workout)
        }

        try? context.save()
    }

    // MARK: - Private helpers

    private func sumQuantity(identifier: HKQuantityTypeIdentifier, unit: HKUnit, start: Date, end: Date) async -> Double? {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                continuation.resume(returning: result?.sumQuantity()?.doubleValue(for: unit))
            }
            store.execute(query)
        }
    }

    private func averageQuantity(identifier: HKQuantityTypeIdentifier, unit: HKUnit, start: Date, end: Date) async -> Double? {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .discreteAverage) { _, result, _ in
                continuation.resume(returning: result?.averageQuantity()?.doubleValue(for: unit))
            }
            store.execute(query)
        }
    }

    private func fetchSleepHours(start: Date, end: Date) async -> Double? {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                guard let categorySamples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: nil)
                    return
                }
                let asleepValues: Set<Int> = [
                    HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue
                ]
                let totalSeconds = categorySamples
                    .filter { asleepValues.contains($0.value) }
                    .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
                continuation.resume(returning: totalSeconds > 0 ? totalSeconds / 3600.0 : nil)
            }
            store.execute(query)
        }
    }

    private static func workoutType(for activityType: HKWorkoutActivityType) -> WorkoutType {
        switch activityType {
        case .running: return .run
        case .walking, .hiking: return .walk
        case .cycling: return .cycle
        case .traditionalStrengthTraining, .functionalStrengthTraining, .coreTraining: return .strength
        case .yoga, .mindAndBody, .pilates: return .yoga
        case .swimming: return .swim
        case .highIntensityIntervalTraining: return .hiit
        default: return .other
        }
    }

    #else

    // MARK: - Fallback (HealthKit unavailable on this platform/SDK)

    func requestAuthorization() async -> Bool { false }
    func fetchTodaySteps() async -> Int? { nil }
    func fetchTodayActiveEnergy() async -> Double? { nil }
    func fetchRestingHeartRate() async -> Int? { nil }
    func fetchLastNightSleepHours() async -> Double? { nil }
    func fetchLatestWeightKg() async -> Double? { nil }
    func fetchRecentWorkouts(limit: Int = 20) async -> [HealthKitWorkoutSummary] { [] }
    func syncToday(context: ModelContext, userEmail: String) async {}

    #endif
}
