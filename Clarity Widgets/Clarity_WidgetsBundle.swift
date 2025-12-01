//
//  Clarity_WidgetsBundle.swift
//  Clarity Widgets
//
//  Created by Matthew Norman on 11/29/25.
//

import WidgetKit
import SwiftUI

@main
struct Clarity_WidgetsBundle: WidgetBundle {
    var body: some Widget {
        ClarityWidget()
        TasksWidget()
        HabitsWidget()
    }
}
