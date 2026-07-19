import SwiftUI

struct DashboardCustomizationView: View {
    @StateObject private var customization = DashboardCustomization.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        List {
            Section {
                ForEach(customization.sectionOrder) { section in
                    HStack {
                        Image(systemName: section.icon)
                            .foregroundStyle(Color.clarityPurple)
                            .frame(width: 24)
                        
                        Text(section.rawValue)
                            .foregroundStyle(.primary)
                        
                        Spacer()
                        
                        // Visibility Toggle
                        Button(action: {
                            withAnimation {
                                customization.toggleVisibility(for: section)
                            }
                        }) {
                            Image(systemName: customization.hiddenSections.contains(section) ? "eye.slash" : "eye")
                                .foregroundStyle(customization.hiddenSections.contains(section) ? Color.secondary : Color.clarityBlue)
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 8)
                    }
                    .opacity(customization.hiddenSections.contains(section) ? 0.5 : 1.0)
                }
                .onMove { source, destination in
                    customization.move(from: source, to: destination)
                }
            } header: {
                Text("Reorder & Visibility")
            } footer: {
                Text("Drag rows to reorder. Tap the eye icon to hide/show sections.")
            }
        }
        .navigationTitle("Customize Dashboard")
        .environment(\.editMode, .constant(.active)) // Always in edit mode to show drag handles
        .onDisappear {
            customization.saveSettings()
        }
    }
}

#Preview {
    NavigationStack {
        DashboardCustomizationView()
    }
}
