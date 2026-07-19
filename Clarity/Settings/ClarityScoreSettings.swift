import SwiftUI
import Combine

class ClarityScoreSettings: ObservableObject {
    static let shared = ClarityScoreSettings()
    
    // Persist weights directly
    @AppStorage("clarity_score_weight_tasks") var taskWeight: Double = 0.30
    @AppStorage("clarity_score_weight_habits") var habitWeight: Double = 0.25
    @AppStorage("clarity_score_weight_mood") var moodWeight: Double = 0.20
    @AppStorage("clarity_score_weight_moments") var momentWeight: Double = 0.15
    @AppStorage("clarity_score_weight_finance") var financeWeight: Double = 0.10
    
    // For backward compatibility / API consistency
    var currentWeights: [Double] {
        [taskWeight, habitWeight, moodWeight, momentWeight, financeWeight]
    }
    
    func weightFor(_ component: ScoreComponent) -> Double {
        switch component {
        case .task: return taskWeight
        case .habit: return habitWeight
        case .mood: return moodWeight
        case .moment: return momentWeight
        case .finance: return financeWeight
        }
    }
    
    /// Updates a weight and balances others to maintain 1.0 total
    func setWeight(for component: ScoreComponent, to newValue: Double) {
        // Clamp new value
        let clampedValue = min(1.0, max(0.0, newValue))
        
        // Identify which proeprty we are changing
        let oldWeight = weightFor(component)
        
        // Use a temporary array to calculate new values
        var weights = currentWeights
        let changeIndex: Int
        switch component {
        case .task: changeIndex = 0
        case .habit: changeIndex = 1
        case .mood: changeIndex = 2
        case .moment: changeIndex = 3
        case .finance: changeIndex = 4
        }
        
        // 1. Update the target
        weights[changeIndex] = clampedValue
        
        // 2. Distribute the remaining (1.0 - clampedValue) among others
        // based on their *original* relative proportions
        let remainingBudget = 1.0 - clampedValue
        let othersTotalOld = 1.0 - oldWeight
        
        for i in 0..<weights.count {
            if i == changeIndex { continue }
            
            if othersTotalOld > 0.001 {
                // Determine this component's share of the "others"
                let share = currentWeights[i] / othersTotalOld
                weights[i] = remainingBudget * share
            } else {
                // If the modified component was previously 100%, others were 0.
                // We now have some budget to give back to them.
                // Distribute equally among others?
                let otherCount = Double(weights.count - 1)
                weights[i] = remainingBudget / otherCount
            }
        }
        
        // 3. Round/Normalize to ensure strict 1.0 sum (fix floating point drift)
        let sum = weights.reduce(0, +)
        if sum > 0 {
            weights = weights.map { $0 / sum }
        }
        
        // 4. Apply back to properties
        taskWeight = weights[0]
        habitWeight = weights[1]
        moodWeight = weights[2]
        momentWeight = weights[3]
        financeWeight = weights[4]
    }
}

enum ScoreComponent: String, CaseIterable {
    case task = "Tasks"
    case habit = "Habits"
    case mood = "Mood"
    case moment = "Moments"
    case finance = "Finance"
}
