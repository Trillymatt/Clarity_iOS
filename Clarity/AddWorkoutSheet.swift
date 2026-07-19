import SwiftUI
import SwiftData

// MARK: - Add / Edit Workout Sheet

struct AddWorkoutSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let userEmail: String
    let workoutToEdit: Workout?

    @State private var type: WorkoutType = .run
    @State private var date: Date = Date()
    @State private var durationText: String = "30"
    @State private var caloriesText: String = ""
    @State private var distanceText: String = ""
    @State private var notes: String = ""
    @State private var showDeleteConfirmation = false

    init(userEmail: String, workoutToEdit: Workout? = nil) {
        self.userEmail = userEmail
        self.workoutToEdit = workoutToEdit

        if let workout = workoutToEdit {
            _type = State(initialValue: workout.type)
            _date = State(initialValue: workout.date)
            _durationText = State(initialValue: String(workout.durationMinutes))
            _caloriesText = State(initialValue: workout.caloriesBurned.map { String(Int($0)) } ?? "")
            _distanceText = State(initialValue: workout.distanceMiles.map { String(format: "%.2f", $0) } ?? "")
            _notes = State(initialValue: workout.notes ?? "")
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.clarityBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Type")
                                .font(.headline)
                                .padding(.horizontal, 4)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(WorkoutType.allCases) { workoutType in
                                        SelectionChip(title: "\(workoutType.emoji) \(workoutType.label)", isSelected: type == workoutType) {
                                            withAnimation { type = workoutType }
                                        }
                                    }
                                }
                                .padding(.horizontal, 4)
                                .padding(.vertical, 4)
                            }
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text("When")
                                .font(.headline)
                                .padding(.horizontal, 4)

                            DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
                                .padding()
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }

                        HStack(spacing: 16) {
                            statField(title: "Minutes", icon: "clock.fill", text: $durationText, keyboard: .numberPad)
                            statField(title: "Calories", icon: "flame.fill", text: $caloriesText, keyboard: .numberPad)
                        }

                        statField(title: "Distance (mi, optional)", icon: "location.fill", text: $distanceText, keyboard: .decimalPad)

                        CustomTextEditor(title: "Notes (Optional)", text: $notes)

                        Spacer(minLength: 20)

                        Button(action: saveWorkout) {
                            Text(workoutToEdit == nil ? "Log Workout" : "Save Changes")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled((Int(durationText) ?? 0) <= 0)

                        if workoutToEdit != nil {
                            Button(action: { showDeleteConfirmation = true }) {
                                Text("Delete Workout")
                                    .font(.body.bold())
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.red)
                                    .cornerRadius(16)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle(workoutToEdit == nil ? "Log Workout" : "Edit Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Delete Workout?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) { deleteWorkout() }
            } message: {
                Text("This action cannot be undone.")
            }
        }
    }

    @ViewBuilder
    private func statField(title: String, icon: String, text: Binding<String>, keyboard: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Image(systemName: icon).foregroundStyle(.secondary)
                TextField("0", text: text)
                    .keyboardType(keyboard)
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func saveWorkout() {
        let duration = Int(durationText) ?? 0
        let calories = Double(caloriesText)
        let distanceMiles = Double(distanceText)

        if let existing = workoutToEdit {
            existing.type = type
            existing.date = date
            existing.durationMinutes = duration
            existing.caloriesBurned = calories
            existing.distanceMiles = distanceMiles
            existing.notes = notes.isEmpty ? nil : notes
        } else {
            let workout = Workout(
                ownerEmail: userEmail,
                type: type,
                date: date,
                durationMinutes: duration,
                caloriesBurned: calories,
                notes: notes.isEmpty ? nil : notes,
                source: "manual"
            )
            workout.distanceMiles = distanceMiles
            context.insert(workout)
        }

        try? context.save()
        WidgetDataUpdater.updateWidgetData(context: context, userEmail: userEmail)
        dismiss()
    }

    private func deleteWorkout() {
        guard let existing = workoutToEdit else { return }
        context.delete(existing)
        try? context.save()
        WidgetDataUpdater.updateWidgetData(context: context, userEmail: userEmail)
        dismiss()
    }
}

// MARK: - Add / Edit Body Metric Sheet

struct AddBodyMetricSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let userEmail: String
    let metricToEdit: BodyMetric?

    @State private var date: Date = Date()
    @State private var weightText: String = ""
    @State private var stepsText: String = ""
    @State private var sleepText: String = ""

    init(userEmail: String, metricToEdit: BodyMetric? = nil) {
        self.userEmail = userEmail
        self.metricToEdit = metricToEdit

        if let metric = metricToEdit {
            _date = State(initialValue: metric.date)
            _weightText = State(initialValue: metric.weightLbs.map { String(format: "%.1f", $0) } ?? "")
            _stepsText = State(initialValue: metric.steps.map { String($0) } ?? "")
            _sleepText = State(initialValue: metric.sleepHours.map { String(format: "%.1f", $0) } ?? "")
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.clarityBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        DatePicker("Date", selection: $date, displayedComponents: [.date])
                            .padding()
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                        metricField(title: "Weight (lbs)", icon: "scalemass.fill", text: $weightText, keyboard: .decimalPad)
                        metricField(title: "Steps", icon: "figure.walk", text: $stepsText, keyboard: .numberPad)
                        metricField(title: "Sleep (hours)", icon: "bed.double.fill", text: $sleepText, keyboard: .decimalPad)

                        Spacer(minLength: 20)

                        Button(action: save) {
                            Text("Save")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(weightText.isEmpty && stepsText.isEmpty && sleepText.isEmpty)
                    }
                    .padding()
                }
            }
            .navigationTitle("Log Body Metrics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }

    @ViewBuilder
    private func metricField(title: String, icon: String, text: Binding<String>, keyboard: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption.bold()).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Image(systemName: icon).foregroundStyle(.secondary)
                TextField("0", text: text).keyboardType(keyboard)
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func save() {
        let dayStart = Calendar.current.startOfDay(for: date)
        let weight = Double(weightText)
        let steps = Int(stepsText)
        let sleep = Double(sleepText)

        if let existing = metricToEdit {
            existing.date = date
            if let weight { existing.weightLbs = weight }
            if let steps { existing.steps = steps }
            if let sleep { existing.sleepHours = sleep }
        } else {
            let descriptor = FetchDescriptor<BodyMetric>(
                predicate: #Predicate<BodyMetric> { $0.ownerEmail == userEmail && $0.date >= dayStart }
            )
            if let existingToday = try? context.fetch(descriptor).first {
                existingToday.date = date
                if let weight { existingToday.weightLbs = weight }
                if let steps { existingToday.steps = steps }
                if let sleep { existingToday.sleepHours = sleep }
            } else {
                let metric = BodyMetric(ownerEmail: userEmail, date: date, steps: steps, sleepHours: sleep, source: "manual")
                if let weight { metric.weightLbs = weight }
                context.insert(metric)
            }
        }

        try? context.save()
        WidgetDataUpdater.updateWidgetData(context: context, userEmail: userEmail)
        dismiss()
    }
}
