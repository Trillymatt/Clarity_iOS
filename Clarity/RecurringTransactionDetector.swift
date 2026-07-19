import Foundation

// MARK: - Recurring Transaction Detector
// Finds bills/subscriptions the user never explicitly flagged as recurring
// by looking for repeated same-category, same-note charges spaced roughly a
// month apart. Deterministic, local — no AI needed to notice "you pay this
// every month."

struct DetectedRecurringCharge: Identifiable {
    var id: String { "\(category.rawValue)-\(normalizedNote)" }
    let category: TransactionCategory
    let note: String
    let averageAmount: Double
    let occurrences: Int
    let lastDate: Date
    let nextExpectedDate: Date
    let transactionIDs: [UUID]

    fileprivate var normalizedNote: String { note.lowercased().trimmingCharacters(in: .whitespaces) }
}

enum RecurringTransactionDetector {
    /// Only considers transactions the user hasn't already flagged `isRecurring`,
    /// so this surfaces things to confirm rather than repeating what's already known.
    static func detect(transactions: [Transaction], lookbackDays: Int = 120) -> [DetectedRecurringCharge] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -lookbackDays, to: Date()) ?? Date.distantPast
        let candidates = transactions.filter { !$0.isRecurring && $0.date >= cutoff && ($0.note?.isEmpty == false) }

        let grouped = Dictionary(grouping: candidates) { txn -> String in
            let note = (txn.note ?? "").lowercased().trimmingCharacters(in: .whitespaces)
            return "\(txn.category.rawValue)-\(note)"
        }

        var results: [DetectedRecurringCharge] = []

        for (_, group) in grouped where group.count >= 2 {
            let sorted = group.sorted { $0.date < $1.date }
            let amounts = sorted.map(\.amount)
            let avgAmount = amounts.reduce(0, +) / Double(amounts.count)

            // Amounts should be consistent (within 15% of the average) — a real
            // subscription/bill charges roughly the same amount each time.
            let amountsConsistent = amounts.allSatisfy { abs($0 - avgAmount) <= avgAmount * 0.15 + 0.01 }
            guard amountsConsistent else { continue }

            // Gaps between charges should look monthly-ish (20-40 days).
            var gaps: [Int] = []
            for i in 1..<sorted.count {
                let days = Calendar.current.dateComponents([.day], from: sorted[i - 1].date, to: sorted[i].date).day ?? 0
                gaps.append(days)
            }
            let monthlyGaps = gaps.filter { $0 >= 20 && $0 <= 40 }
            guard Double(monthlyGaps.count) / Double(gaps.count) >= 0.5 else { continue }

            let last = sorted.last!
            let nextExpected = Calendar.current.date(byAdding: .day, value: 30, to: last.date) ?? last.date

            results.append(DetectedRecurringCharge(
                category: last.category,
                note: last.note ?? "",
                averageAmount: avgAmount,
                occurrences: sorted.count,
                lastDate: last.date,
                nextExpectedDate: nextExpected,
                transactionIDs: sorted.map(\.id)
            ))
        }

        return results.sorted { $0.averageAmount > $1.averageAmount }
    }

    static func monthlyTotal(_ charges: [DetectedRecurringCharge], alreadyRecurring: [Transaction]) -> Double {
        let detectedTotal = charges.reduce(0) { $0 + $1.averageAmount }
        // Rough monthly-equivalent for anything the user already flagged manually.
        let flaggedTotal = alreadyRecurring.filter(\.isRecurring).reduce(0) { $0 + $1.amount }
        return detectedTotal + flaggedTotal
    }
}
