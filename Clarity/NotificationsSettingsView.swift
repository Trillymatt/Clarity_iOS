import SwiftUI

struct NotificationsSettingsView: View {
    @StateObject private var notificationSettings = NotificationSettings.shared
    @StateObject private var notificationManager = NotificationManager.shared
    
    var body: some View {
        List {
            // Permissions Section
            Section {
                HStack {
                    Image(systemName: notificationManager.isAuthorized ? "bell.badge.fill" : "bell.slash.fill")
                        .foregroundStyle(notificationManager.isAuthorized ? .green : .red)
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notification Permissions")
                            .font(.subheadline.bold())
                        Text(notificationManager.isAuthorized ? "Enabled" : "Disabled")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    if !notificationManager.isAuthorized {
                        Button("Enable") {
                            notificationManager.openSettings()
                        }
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.clarityBlue)
                        .cornerRadius(8)
                    }
                }
            } header: {
                Text("Permissions")
            }
            
            // Core Notifications
            Section {
                // Mood Check-in
                VStack(spacing: 12) {
                    Toggle(isOn: $notificationSettings.moodCheckInEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Daily Mood Check-in")
                                .font(.subheadline.bold())
                            Text("Track your emotional wellbeing")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tint(Color.clarityBlue)
                    
                    if notificationSettings.moodCheckInEnabled {
                        Divider()
                        HStack {
                            Text("Time")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            DatePicker("", selection: $notificationSettings.moodCheckInTime, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                        }
                    }
                }
                
                // Weekly Review
                Toggle(isOn: $notificationSettings.weeklyReviewEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Weekly Review Reminder")
                            .font(.subheadline.bold())
                        Text("Sunday at 6:00 PM")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(Color.clarityBlue)
            } header: {
                Text("Core Notifications")
            } footer: {
                Text("These help you stay connected with your wellbeing journey.")
            }
            .disabled(!notificationManager.isAuthorized)
            
            // Optional Notifications
            Section {
                // Morning Motivation
                VStack(spacing: 12) {
                    Toggle(isOn: $notificationSettings.morningMotivationEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text("Morning Motivation")
                                    .font(.subheadline.bold())
                                Text("☀️")
                            }
                            Text("Start your day with intention")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tint(Color.clarityOrange)
                    
                    if notificationSettings.morningMotivationEnabled {
                        Divider()
                        HStack {
                            Text("Time")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            DatePicker("", selection: $notificationSettings.morningMotivationTime, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                        }
                    }
                }
                
                // Afternoon Focus
                VStack(spacing: 12) {
                    Toggle(isOn: $notificationSettings.afternoonReminderEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text("Afternoon Focus")
                                    .font(.subheadline.bold())
                                Text("⚡")
                            }
                            Text("A gentle nudge to stay on track")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tint(Color.clarityTeal)
                    
                    if notificationSettings.afternoonReminderEnabled {
                        Divider()
                        HStack {
                            Text("Time")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            DatePicker("", selection: $notificationSettings.afternoonReminderTime, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                        }
                    }
                }
                
                // Gratitude Prompts
                VStack(spacing: 12) {
                    Toggle(isOn: $notificationSettings.gratitudePromptsEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text("Gratitude Prompts")
                                    .font(.subheadline.bold())
                                Text("🙏")
                            }
                            Text("End your day with gratitude")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tint(Color.clarityPurple)
                    
                    if notificationSettings.gratitudePromptsEnabled {
                        Divider()
                        HStack {
                            Text("Time")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            DatePicker("", selection: $notificationSettings.gratitudePromptsTime, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                        }
                    }
                }
            } header: {
                Text("Optional Reminders")
            } footer: {
                Text("Enable these for extra motivation throughout your day.")
            }
            .disabled(!notificationManager.isAuthorized)
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        NotificationsSettingsView()
    }
}
