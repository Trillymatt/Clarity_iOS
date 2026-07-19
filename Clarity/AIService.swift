import Foundation

enum AIError: Error {
    case invalidURL
    case noData
    case decodingError
    case apiError(String)
}

// MARK: - User Context for Personalization
struct UserContext {
    let biggestPriority: String?
    let idealDay: String?
    let desiredHabit: String?
    
    var contextDescription: String {
        var parts: [String] = []
        if let priority = biggestPriority, !priority.isEmpty {
            parts.append("Their biggest priority: \(priority)")
        }
        if let ideal = idealDay, !ideal.isEmpty {
            parts.append("Their ideal day: \(ideal)")
        }
        if let habit = desiredHabit, !habit.isEmpty {
            parts.append("They want to build this habit: \(habit)")
        }
        return parts.isEmpty ? "No additional context provided." : parts.joined(separator: ". ")
    }
}

class AIService {
    static let shared = AIService()
    
    private var apiKey: String = Secrets.openAIKey
    private let openAIURL = "https://api.openai.com/v1/chat/completions"
    
    func setApiKey(_ key: String) {
        self.apiKey = key
    }
    
    struct Subtask: Decodable {
        let title: String
        let suggestedOffset: Int // 0 = Today, 1 = Tomorrow, etc.
    }
    
    struct TaskBreakdown: Decodable {
        let title: String
        let subtasks: [Subtask]
    }
    
    func generateSubtasks(for task: String, userContext: UserContext? = nil) async throws -> (title: String, subtasks: [Subtask]) {
        guard let url = URL(string: openAIURL) else { throw AIError.invalidURL }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30 // Explicit 30s timeout
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let contextInfo = userContext?.contextDescription ?? "No additional context provided."
        
        let prompt = """
        You are an expert productivity coach helping a user with Clarity, a life management app.
        
        USER CONTEXT: \(contextInfo)
        
        The user has entered a task: "\(task)".
        
        Using their context to inform your suggestions:
        1. Create a concise, "overarching" project title for this task (e.g., "Plan Japan Trip").
        2. Break it down into 3-5 specific, actionable subtasks that align with their priorities and daily rhythm.
        3. **Schedule them intelligently**: Assign a `suggestedOffset` (integer) representing days from today (0 = Today, 1 = Tomorrow, 2 = Day After). Spread them out logically if they can't all be done today.
        
        Return JSON ONLY with this format:
        {
            "title": "Refined Title",
            "subtasks": [
                { "title": "Subtask 1", "suggestedOffset": 0 },
                { "title": "Subtask 2", "suggestedOffset": 1 }
            ]
        }
        """
        
        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "system", "content": "You are a helpful productivity assistant. Return only JSON."],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.7,
            "response_format": ["type": "json_object"]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else { throw AIError.noData }
        
        if httpResponse.statusCode != 200 {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorJson["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw AIError.apiError(message)
            }
            throw AIError.apiError("Status code: \(httpResponse.statusCode)")
        }
        
        struct OpenAIResponse: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable {
                    let content: String
                }
                let message: Message
            }
            let choices: [Choice]
        }
        
        let decodedResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        guard let content = decodedResponse.choices.first?.message.content else { throw AIError.noData }
        
        guard let jsonData = content.data(using: .utf8),
              let breakdown = try? JSONDecoder().decode(TaskBreakdown.self, from: jsonData) else {
            throw AIError.decodingError
        }
        
        return (breakdown.title, breakdown.subtasks)
    }
    
    // MARK: - Habit Generation
    
    struct HabitSuggestion: Decodable {
        let name: String
        let iconName: String
        let goalPerDay: Int
        let daysOfWeek: [Int] // 1 = Sunday, 2 = Monday, etc.
    }
    
    func generateHabit(for goal: String, userContext: UserContext? = nil) async throws -> HabitSuggestion {
        guard let url = URL(string: openAIURL) else { throw AIError.invalidURL }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let contextInfo = userContext?.contextDescription ?? "No additional context provided."
        
        let prompt = """
        You are an expert behavior scientist helping a user with Clarity, a life management app.
        
        USER CONTEXT: \(contextInfo)
        
        The user wants to build a habit related to: "\(goal)".
        
        Using their context, priorities, and ideal day to inform your suggestion:
        1. Create a specific, actionable habit name (e.g., "Morning Run" instead of "Exercise more").
        2. Choose a relevant SF Symbol name for the icon (e.g., "book.fill", "figure.run", "heart.fill", "dumbbell.fill").
        3. goalPerDay is NOT minutes/duration - it's the number of times they need to check in per day. This should almost always be 1 (one check-in per day). Only use 2-3 for habits like "drink water" where multiple check-ins make sense.
        4. daysOfWeek uses Calendar weekday integers: 1=Sunday, 2=Monday, 3=Tuesday, 4=Wednesday, 5=Thursday, 6=Friday, 7=Saturday. Use empty array [] for daily habits.
        
        Return JSON ONLY:
        {
            "name": "Habit Name",
            "iconName": "star.fill",
            "goalPerDay": 1,
            "daysOfWeek": []
        }
        """
        
        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "system", "content": "You are a helpful habit coach. Return only JSON. Remember: goalPerDay is check-ins NOT minutes."],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.7,
            "response_format": ["type": "json_object"]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else { throw AIError.noData }
        
        if httpResponse.statusCode != 200 {
            throw AIError.apiError("Status code: \(httpResponse.statusCode)")
        }
        
        struct OpenAIResponse: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable {
                    let content: String
                }
                let message: Message
            }
            let choices: [Choice]
        }
        
        let decodedResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        guard let content = decodedResponse.choices.first?.message.content else { throw AIError.noData }
        
        guard let jsonData = content.data(using: .utf8),
              let suggestion = try? JSONDecoder().decode(HabitSuggestion.self, from: jsonData) else {
            throw AIError.decodingError
        }
        
        // Validate and clamp goalPerDay to reasonable range (1-5)
        let clampedGoal = max(1, min(5, suggestion.goalPerDay))
        
        // Validate daysOfWeek (should be 1-7 or empty)
        let validDays = suggestion.daysOfWeek.filter { $0 >= 1 && $0 <= 7 }
        
        return HabitSuggestion(
            name: suggestion.name,
            iconName: suggestion.iconName,
            goalPerDay: clampedGoal,
            daysOfWeek: validDays
        )
    }
    
    /// Generate personalized details for a habit with a fixed name
    /// This is used for pre-defined suggestions where we keep the name but personalize icon/schedule
    func generateHabitDetails(forHabitNamed habitName: String, userContext: UserContext? = nil) async throws -> HabitSuggestion {
        guard let url = URL(string: openAIURL) else { throw AIError.invalidURL }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let contextInfo = userContext?.contextDescription ?? "No additional context provided."
        
        let prompt = """
        You are an expert behavior scientist helping a user with Clarity, a life management app.
        
        USER CONTEXT: \(contextInfo)
        
        The user wants to add this exact habit: "\(habitName)"
        
        IMPORTANT: The habit name is FIXED - do NOT change or modify the name. It MUST be exactly "\(habitName)".
        
        Your job is to personalize the other details based on the user's context:
        1. Choose a relevant SF Symbol name for the icon (e.g., "book.fill", "figure.run", "heart.fill", "dumbbell.fill", "clock.fill")
        2. Suggest the best days using Calendar weekday integers: 1=Sunday, 2=Monday, 3=Tuesday, 4=Wednesday, 5=Thursday, 6=Friday, 7=Saturday.
           Common patterns:
           - Daily: [] (empty array)
           - Weekdays (Mon-Fri): [2, 3, 4, 5, 6]
           - Weekends (Sat-Sun): [1, 7]
           - Every other day: [2, 4, 6]
        3. goalPerDay should almost always be 1 (one check-in per day).
        
        Return JSON ONLY:
        {
            "name": "\(habitName)",
            "iconName": "star.fill",
            "goalPerDay": 1,
            "daysOfWeek": [2, 3, 4, 5, 6]
        }
        """
        
        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "system", "content": "You are a helpful habit coach. Return only JSON. NEVER change the habit name - use it exactly as given."],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.5, // Lower temperature for more consistent icon/schedule choices
            "response_format": ["type": "json_object"]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else { throw AIError.noData }
        
        if httpResponse.statusCode != 200 {
            throw AIError.apiError("Status code: \(httpResponse.statusCode)")
        }
        
        struct OpenAIResponse: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable {
                    let content: String
                }
                let message: Message
            }
            let choices: [Choice]
        }
        
        let decodedResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        guard let content = decodedResponse.choices.first?.message.content else { throw AIError.noData }
        
        guard let jsonData = content.data(using: .utf8),
              let suggestion = try? JSONDecoder().decode(HabitSuggestion.self, from: jsonData) else {
            throw AIError.decodingError
        }
        
        // Validate and ensure original name is preserved
        let clampedGoal = max(1, min(5, suggestion.goalPerDay))
        let validDays = suggestion.daysOfWeek.filter { $0 >= 1 && $0 <= 7 }
        
        return HabitSuggestion(
            name: habitName, // Always use the original name, ignore AI's returned name
            iconName: suggestion.iconName,
            goalPerDay: clampedGoal,
            daysOfWeek: validDays
        )
    }

    // MARK: - Extract Action Items from Weekly Review
    
    func extractActionItems(from reflection: String) async throws -> ExtractedItems {
        let url = URL(string: openAIURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let prompt = """
        Analyze this weekly reflection and extract actionable items.
        
        Reflection: "\(reflection)"
        
        Extract up to:
        - 3 meaningful moments (accomplishments, wins, or memorable events)
        - 2 habits to build (based on patterns mentioned or areas to improve)
        - 5 specific action tasks (concrete next steps mentioned)
        
        For moments, determine if they are: "win", "gratitude", "connection", "challenge", or "other"
        For habits, suggest a reasonable goalPerDay (usually 1)
        For tasks, categorize as: "work", "school", "personal", or "other"
        
        Return ONLY valid JSON with NO markdown formatting, in this exact structure:
        {
          "moments": [{" title": "Brief title", "type": "win", "note": "Optional detail"}],
          "habits": [{"name": "Habit name", "goalPerDay": 1}],
          "tasks": [{"title": "Task description", "category": "personal"}]
        }
        
        If no items found in a category, return empty array. Be selective - only extract clear, actionable items.
        """
        
        let requestBody: [String: Any] = [
            "model": "gpt-4",
            "messages": [
                ["role": "system", "content": "You are a helpful assistant that extracts actionable items from personal reflections. Return only valid JSON."],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.7,
            "max_tokens": 800
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.noData
        }
        
        guard httpResponse.statusCode == 200 else {
            let error = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AIError.apiError("HTTP \(httpResponse.statusCode): \(error)")
        }
        
        struct ChatResponse: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable {
                    let content: String
                }
                let message: Message
            }
            let choices: [Choice]
        }
        
        let chatResponse = try JSONDecoder().decode(ChatResponse.self, from: data)
        guard let content = chatResponse.choices.first?.message.content else {
            throw AIError.noData
        }
        
        // Clean up the response (remove markdown if present)
        let cleanedContent = content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let jsonData = cleanedContent.data(using: .utf8) else {
            throw AIError.decodingError
        }
        
        do {
            let extractedItems = try JSONDecoder().decode(ExtractedItems.self, from: jsonData)
            return extractedItems
        } catch {
            print("JSON Decode Error: \(error)")
            print("Content: \(cleanedContent)")
            throw AIError.decodingError
        }
    }
}
