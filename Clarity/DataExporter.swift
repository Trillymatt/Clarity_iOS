import Foundation
import SwiftData

// MARK: - Data Exporter
// Plain CSV, one section per domain — the "coming soon" export the privacy
// policy already promised, now real.
enum DataExporter {
    static func exportCSV(context: ModelContext, userEmail: String) -> URL? {
        var csv = ""

        let tasks = (try? context.fetch(FetchDescriptor<TaskItem>(predicate: #Predicate<TaskItem> { $0.ownerEmail == userEmail }))) ?? []
        csv += "TASKS\ntitle,category,due_date,completed,completed_date\n"
        for task in tasks {
            csv += "\(field(task.title)),\(task.category.rawValue),\(dateField(task.dueDate)),\(task.isCompleted),\(dateField(task.completedDate))\n"
        }
        csv += "\n"

        let habits = (try? context.fetch(FetchDescriptor<Habit>(predicate: #Predicate<Habit> { $0.ownerEmail == userEmail }))) ?? []
        csv += "HABITS\nname,goal_per_day,active\n"
        for habit in habits {
            csv += "\(field(habit.name)),\(habit.goalPerDay ?? 1),\(habit.isActive)\n"
        }
        csv += "\n"

        let moments = (try? context.fetch(FetchDescriptor<LifeMoment>(predicate: #Predicate<LifeMoment> { $0.ownerEmail == userEmail }))) ?? []
        csv += "MOMENTS\ndate,title,type,note\n"
        for moment in moments {
            csv += "\(dateField(moment.date)),\(field(moment.title)),\(moment.type.rawValue),\(field(moment.note ?? ""))\n"
        }
        csv += "\n"

        let transactions = (try? context.fetch(FetchDescriptor<Transaction>(predicate: #Predicate<Transaction> { $0.ownerEmail == userEmail }))) ?? []
        csv += "TRANSACTIONS\ndate,amount,category,note,recurring\n"
        for txn in transactions {
            csv += "\(dateField(txn.date)),\(txn.amount),\(txn.category.rawValue),\(field(txn.note ?? "")),\(txn.isRecurring)\n"
        }
        csv += "\n"

        let workouts = (try? context.fetch(FetchDescriptor<Workout>(predicate: #Predicate<Workout> { $0.ownerEmail == userEmail }))) ?? []
        csv += "WORKOUTS\ndate,type,duration_min,calories,distance_mi\n"
        for workout in workouts {
            let calories = workout.caloriesBurned.map { String($0) } ?? ""
            let distance = workout.distanceMiles.map { String($0) } ?? ""
            csv += "\(dateField(workout.date)),\(workout.type.rawValue),\(workout.durationMinutes),\(calories),\(distance)\n"
        }

        let fileName = "Clarity-Export-\(Int(Date().timeIntervalSince1970)).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            print("Failed to export CSV: \(error)")
            return nil
        }
    }

    private static func field(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }

    private static func dateField(_ date: Date?) -> String {
        guard let date else { return "" }
        return ISO8601DateFormatter().string(from: date)
    }
}
