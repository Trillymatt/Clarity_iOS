//
//  DurationPickerSheet.swift
//  Clarity
//
//  A beautiful sheet for selecting task duration before starting focus mode
//

import SwiftUI

struct DurationPickerSheet: View {
    let taskTitle: String
    let onDurationSelected: (Int?) -> Void  // nil = no timer
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPreset: Int? = nil
    @State private var showCustomPicker = false
    @State private var customMinutes: Int = 30
    
    // Preset durations in minutes
    private let presets: [(minutes: Int, label: String, icon: String, color: Color)] = [
        (15, "15 min", "bolt.fill", .clarityOrange),
        (25, "25 min", "flame.fill", .clarityPink),
        (45, "45 min", "timer", .clarityPurple),
        (60, "1 hour", "clock.fill", .clarityBlue),
        (120, "2 hours", "hourglass", .clarityTeal)
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.clarityBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 12) {
                            Image(systemName: "timer")
                                .font(.system(size: 48, weight: .light))
                                .foregroundStyle(LinearGradient.clarityPrimary)
                            
                            Text("How long will this take?")
                                .font(.title2.bold())
                            
                            Text(taskTitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 20)
                        
                        // Quick Presets Grid
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            ForEach(presets, id: \.minutes) { preset in
                                DurationPresetButton(
                                    minutes: preset.minutes,
                                    label: preset.label,
                                    icon: preset.icon,
                                    color: preset.color,
                                    isSelected: selectedPreset == preset.minutes
                                ) {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        selectedPreset = preset.minutes
                                        showCustomPicker = false
                                    }
                                }
                            }
                            
                            // Custom option
                            DurationPresetButton(
                                minutes: customMinutes,
                                label: "Custom",
                                icon: "slider.horizontal.3",
                                color: .secondary,
                                isSelected: showCustomPicker
                            ) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedPreset = nil
                                    showCustomPicker = true
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        // Custom Duration Picker
                        if showCustomPicker {
                            VStack(spacing: 16) {
                                Text("Select Duration")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                                
                                HStack(spacing: 20) {
                                    // Minus button
                                    Button {
                                        withAnimation {
                                            customMinutes = max(5, customMinutes - 5)
                                        }
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .font(.title)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    // Duration display
                                    VStack(spacing: 4) {
                                        Text("\(customMinutes)")
                                            .font(.system(size: 48, weight: .bold, design: .rounded))
                                            .foregroundStyle(LinearGradient.clarityPrimary)
                                        Text("minutes")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .frame(width: 120)
                                    
                                    // Plus button
                                    Button {
                                        withAnimation {
                                            customMinutes = min(240, customMinutes + 5)
                                        }
                                    } label: {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.title)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                
                                // Quick adjust buttons
                                HStack(spacing: 8) {
                                    ForEach([5, 10, 15, 30], id: \.self) { mins in
                                        Button {
                                            withAnimation {
                                                customMinutes = mins
                                            }
                                        } label: {
                                            Text("\(mins)m")
                                                .font(.caption.bold())
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                                .background(customMinutes == mins ? Color.clarityBlue : Color.clarityCard)
                                                .foregroundStyle(customMinutes == mins ? .white : .primary)
                                                .cornerRadius(8)
                                        }
                                    }
                                }
                            }
                            .padding()
                            .background(Color.clarityCard)
                            .cornerRadius(16)
                            .padding(.horizontal)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.95).combined(with: .opacity),
                                removal: .opacity
                            ))
                        }
                        
                        // Action Buttons
                        VStack(spacing: 12) {
                            // Start with timer
                            Button {
                                let duration = showCustomPicker ? customMinutes : selectedPreset
                                onDurationSelected(duration)
                                dismiss()
                            } label: {
                                HStack {
                                    Image(systemName: "play.fill")
                                    Text(selectedPreset != nil || showCustomPicker ? "Start Timer" : "Select a Duration")
                                }
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    (selectedPreset != nil || showCustomPicker)
                                        ? AnyShapeStyle(LinearGradient.clarityPrimary)
                                        : AnyShapeStyle(Color.gray)
                                )
                                .cornerRadius(16)
                            }
                            .disabled(selectedPreset == nil && !showCustomPicker)
                            
                            // Start without timer
                            Button {
                                onDurationSelected(nil)
                                dismiss()
                            } label: {
                                Text("Start without timer")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.clarityCard)
                                    .cornerRadius(16)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                        
                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationTitle("Focus Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Duration Preset Button

struct DurationPresetButton: View {
    let minutes: Int
    let label: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isSelected ? color : color.opacity(0.15))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(isSelected ? .white : color)
                }
                
                Text(label)
                    .font(.subheadline.bold())
                    .foregroundStyle(isSelected ? color : .primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                isSelected
                    ? color.opacity(0.1)
                    : Color.clarityCard
            )
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? color : Color.clear, lineWidth: 2)
            )
            .shadow(color: isSelected ? color.opacity(0.2) : .clear, radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.02 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Preview

#Preview {
    DurationPickerSheet(taskTitle: "Review quarterly reports") { duration in
        print("Selected duration: \(duration ?? 0) minutes")
    }
}
