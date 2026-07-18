import SwiftUI
import SwiftData

// MARK: - Workout Type

enum WorkoutType: String, Codable, CaseIterable, Identifiable {
    case run, walk, cycle, strength, yoga, swim, hiit, other
    var id: String { rawValue }

    var label: String {
        switch self {
        case .run: return "Run"
        case .walk: return "Walk"
        case .cycle: return "Cycle"
        case .strength: return "Strength"
        case .yoga: return "Yoga"
        case .swim: return "Swim"
        case .hiit: return "HIIT"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .run: return "figure.run"
        case .walk: return "figure.walk"
        case .cycle: return "figure.outdoor.cycle"
        case .strength: return "dumbbell.fill"
        case .yoga: return "figure.mind.and.body"
        case .swim: return "figure.pool.swim"
        case .hiit: return "bolt.heart.fill"
        case .other: return "figure.mixed.cardio"
        }
    }

    var emoji: String {
        switch self {
        case .run: return "🏃"
        case .walk: return "🚶"
        case .cycle: return "🚴"
        case .strength: return "🏋️"
        case .yoga: return "🧘"
        case .swim: return "🏊"
        case .hiit: return "⚡️"
        case .other: return "💪"
        }
    }

    /// Rough MET-based calorie estimate per minute per kg of body weight,
    /// used as a manual-entry fallback when the user doesn't type calories.
    var metPerMinute: Double {
        switch self {
        case .run: return 0.175
        case .walk: return 0.06
        case .cycle: return 0.12
        case .strength: return 0.1
        case .yoga: return 0.04
        case .swim: return 0.14
        case .hiit: return 0.19
        case .other: return 0.09
        }
    }
}

// MARK: - Workout

@Model
final class Workout {
    @Attribute(.unique) var id: UUID
    var ownerEmail: String
    var typeRaw: String
    var date: Date
    var durationMinutes: Int
    var caloriesBurned: Double?
    var distanceMeters: Double?
    var notes: String?
    /// "manual" or "healthKit" — lets the UI badge auto-synced entries and
    /// lets HealthKitManager dedupe against what it has already imported.
    var source: String
    var healthKitUUID: String?

    var type: WorkoutType {
        get { WorkoutType(rawValue: typeRaw) ?? .other }
        set { typeRaw = newValue.rawValue }
    }

    var distanceMiles: Double? {
        get { distanceMeters.map { $0 / 1609.34 } }
        set { distanceMeters = newValue.map { $0 * 1609.34 } }
    }

    init(
        id: UUID = UUID(),
        ownerEmail: String = "",
        type: WorkoutType = .other,
        date: Date = Date(),
        durationMinutes: Int = 0,
        caloriesBurned: Double? = nil,
        distanceMeters: Double? = nil,
        notes: String? = nil,
        source: String = "manual",
        healthKitUUID: String? = nil
    ) {
        self.id = id
        self.ownerEmail = ownerEmail
        self.typeRaw = type.rawValue
        self.date = date
        self.durationMinutes = durationMinutes
        self.caloriesBurned = caloriesBurned
        self.distanceMeters = distanceMeters
        self.notes = notes
        self.source = source
        self.healthKitUUID = healthKitUUID
    }
}

// MARK: - Body Metric
// A daily snapshot of body/activity data — either typed in by hand or
// synced once per day from HealthKit.

@Model
final class BodyMetric {
    @Attribute(.unique) var id: UUID
    var ownerEmail: String
    var date: Date
    var steps: Int?
    var activeEnergyKcal: Double?
    var restingHeartRate: Int?
    var sleepHours: Double?
    var weightKg: Double?
    var source: String

    var weightLbs: Double? {
        get { weightKg.map { $0 * 2.20462 } }
        set { weightKg = newValue.map { $0 / 2.20462 } }
    }

    init(
        id: UUID = UUID(),
        ownerEmail: String = "",
        date: Date = Date(),
        steps: Int? = nil,
        activeEnergyKcal: Double? = nil,
        restingHeartRate: Int? = nil,
        sleepHours: Double? = nil,
        weightKg: Double? = nil,
        source: String = "manual"
    ) {
        self.id = id
        self.ownerEmail = ownerEmail
        self.date = date
        self.steps = steps
        self.activeEnergyKcal = activeEnergyKcal
        self.restingHeartRate = restingHeartRate
        self.sleepHours = sleepHours
        self.weightKg = weightKg
        self.source = source
    }
}
