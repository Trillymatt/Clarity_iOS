import SwiftUI
import Combine

// MARK: - Dashboard Section Enum
enum DashboardSection: String, CaseIterable, Codable, Identifiable {
    case pillars = "Daily Vitals"
    case score = "Clarity Score"
    case focus = "Today's Focus"
    case pulse = "Life Pulse"
    case habits = "Habits"
    case social = "Social"
    case moments = "Moments"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .score: return "sparkles"
        case .focus: return "target"
        case .pillars: return "square.grid.3x1.below.line.grid.1x2"
        case .pulse: return "waveform.path.ecg"
        case .habits: return "repeat.circle"
        case .social: return "person.2.fill"
        case .moments: return "camera.macro"
        }
    }
}

// MARK: - Dashboard Customization Settings
class DashboardCustomization: ObservableObject {
    @AppStorage("dashboardSectionOrder") private var savedOrderData: Data?
    @AppStorage("dashboardHiddenSections") private var savedHiddenData: Data?
    
    @Published var sectionOrder: [DashboardSection] = []
    @Published var hiddenSections: Set<DashboardSection> = []
    
    static let shared = DashboardCustomization()
    
    private static let defaultOrder: [DashboardSection] = [
        .pillars,
        .social,
        .score,
        .focus,
        .pulse,
        .habits,
        .moments
    ]
    
    init() {
        loadSettings()
    }
    
    func loadSettings() {
        // Load Order
        if let data = savedOrderData,
           let decoded = try? JSONDecoder().decode([DashboardSection].self, from: data) {
            // Ensure all current cases are present (handle enum updates)
            let currentCases = Set(DashboardSection.allCases)
            let loadedCases = Set(decoded)
            
            // Start with loaded order
            var finalOrder = decoded.filter { currentCases.contains($0) }
            
            // Append any new sections that weren't in saved data
            let newSections = currentCases.subtracting(loadedCases)
            
            // If .pillars is new, put it at the top, others append
            if newSections.contains(.pillars) {
                finalOrder.insert(.pillars, at: 0)
                let otherNew = newSections.subtracting([.pillars])
                finalOrder.append(contentsOf: otherNew.sorted(by: { $0.rawValue < $1.rawValue }))
            } else {
                finalOrder.append(contentsOf: newSections.sorted(by: { $0.rawValue < $1.rawValue }))
            }
            
            self.sectionOrder = finalOrder
        } else {
            // Default Order
            self.sectionOrder = DashboardCustomization.defaultOrder
        }
        
        // Load Visibility
        if let data = savedHiddenData,
           let decoded = try? JSONDecoder().decode(Set<DashboardSection>.self, from: data) {
            self.hiddenSections = decoded
        } else {
            self.hiddenSections = []
        }
    }
    
    func saveSettings() {
        if let encodedOrder = try? JSONEncoder().encode(sectionOrder) {
            savedOrderData = encodedOrder
        }
        
        if let encodedHidden = try? JSONEncoder().encode(hiddenSections) {
            savedHiddenData = encodedHidden
        }
    }
    
    func toggleVisibility(for section: DashboardSection) {
        if hiddenSections.contains(section) {
            hiddenSections.remove(section)
        } else {
            hiddenSections.insert(section)
        }
        saveSettings()
    }
    
    func move(from source: IndexSet, to destination: Int) {
        sectionOrder.move(fromOffsets: source, toOffset: destination)
        saveSettings()
    }
}
