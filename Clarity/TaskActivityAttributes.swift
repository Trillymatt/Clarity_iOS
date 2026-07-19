//
//  TaskActivityAttributes.swift
//  Clarity
//
//  Shared ActivityAttributes for Task Live Activity
//  This file is included in both the main app and widget extension targets
//

import ActivityKit
import Foundation

struct TaskActivityAttributes: ActivityAttributes {
    // Static data that doesn't change during the activity
    public struct ContentState: Codable, Hashable {
        var taskTitle: String
        var category: String
        var elapsedSeconds: Int
        var timerEndTime: Date?  // When the timer should end (nil = no timer, show elapsed time)
    }
    
    // Static properties set when activity starts
    var taskId: String
    var startTime: Date
}
