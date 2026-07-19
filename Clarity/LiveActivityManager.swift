//
//  LiveActivityManager.swift
//  Clarity
//
//  Manages starting, updating, and stopping Live Activities for tasks
//

import ActivityKit
import Foundation
import SwiftUI

@MainActor
class LiveActivityManager {
    static let shared = LiveActivityManager()
    
    private var currentActivity: Activity<TaskActivityAttributes>?
    
    private init() {}
    
    // MARK: - Start Activity
    
    /// Start a Live Activity for a task
    /// - Parameters:
    ///   - taskId: Unique identifier for the task
    ///   - title: Task title to display
    ///   - category: Task category
    ///   - durationMinutes: Optional duration in minutes for countdown timer
    func startTaskActivity(taskId: String, title: String, category: String, durationMinutes: Int? = nil) {
        // Check if Live Activities are supported
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("Live Activities not enabled")
            return
        }
        
        // Stop any existing activity first
        stopTaskActivity()
        
        let attributes = TaskActivityAttributes(
            taskId: taskId,
            startTime: Date()
        )
        
        // Calculate timer end time if duration is provided
        let timerEndTime: Date? = durationMinutes != nil
            ? Calendar.current.date(byAdding: .minute, value: durationMinutes!, to: Date())
            : nil
        
        let initialState = TaskActivityAttributes.ContentState(
            taskTitle: title,
            category: category,
            elapsedSeconds: 0,
            timerEndTime: timerEndTime
        )
        
        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil
            )
            currentActivity = activity
            print("Live Activity started: \(activity.id), timer: \(durationMinutes ?? 0) minutes")
        } catch {
            print("Failed to start Live Activity: \(error)")
        }
    }
    
    // MARK: - Update Activity
    
    /// Update the Live Activity with new information
    func updateTaskActivity(title: String, category: String, elapsedSeconds: Int, timerEndTime: Date? = nil) {
        guard let activity = currentActivity else { return }
        
        let updatedState = TaskActivityAttributes.ContentState(
            taskTitle: title,
            category: category,
            elapsedSeconds: elapsedSeconds,
            timerEndTime: timerEndTime
        )
        
        Task {
            await activity.update(
                ActivityContent(state: updatedState, staleDate: nil)
            )
        }
    }
    
    // MARK: - Stop Activity
    
    /// Stop the current Live Activity
    func stopTaskActivity() {
        guard let activity = currentActivity else { return }
        
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
            print("Live Activity stopped: \(activity.id)")
        }
        
        currentActivity = nil
    }
    
    // MARK: - Check Status
    
    /// Check if there's an active Live Activity
    var hasActiveActivity: Bool {
        currentActivity != nil
    }
    
    /// Get the task ID of the current activity
    var activeTaskId: String? {
        currentActivity?.attributes.taskId
    }
}
