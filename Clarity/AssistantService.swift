import Foundation
import SwiftData

enum AssistantError: Error {
    case invalidURL
    case noData
    case decodingError
    case apiError(String)
}

struct AssistantToolCall {
    let id: String
    let name: String
    let argumentsJSON: String
}

struct AssistantTurnResult {
    let reply: String
    let actionSummaries: [String]
}

/// Jarvis's brain: OpenAI chat completions with function calling, so the
/// assistant can act on the user's real Clarity data instead of just
/// describing what it would do. Hand-rolled URLSession/JSONSerialization to
/// match AIService.swift's existing style rather than introducing an SDK.
final class AssistantService {
    static let shared = AssistantService()

    private let apiKey: String = Secrets.openAIKey
    private let endpoint = "https://api.openai.com/v1/chat/completions"
    private let model = "gpt-4o-mini"
    private let maxToolIterations = 4

    private init() {}

    // MARK: - Daily brief (single-shot, no tools — powers the dashboard card)

    func generateDailyBrief(userName: String, userContext: UserContext, summary: String) async throws -> String {
        let prompt = """
        You are Jarvis, \(userName)'s personal AI assistant inside Clarity, an all-in-one life and fitness app.
        Write ONE short, warm sentence (max ~200 characters) summarizing how their day/week is going across
        tasks, habits, mood, fitness, and money, using the data below. Be specific — mention a real number or
        fact from the data, not something generic. No greeting, no sign-off, just the insight itself.

        USER CONTEXT: \(userContext.contextDescription)

        DATA SNAPSHOT:
        \(summary)
        """

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": "You are a concise, insightful personal assistant. Reply with plain text only, one sentence."],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.6,
            "max_tokens": 120
        ]

        let (content, _) = try await performChatRequest(body: body)
        guard let content else { throw AssistantError.noData }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Full tool-calling conversation turn

    @MainActor
    func sendMessage(
        _ userMessage: String,
        history: [AssistantMessage],
        userName: String,
        userContext: UserContext,
        userEmail: String,
        context: ModelContext
    ) async throws -> AssistantTurnResult {
        var apiMessages: [[String: Any]] = [
            ["role": "system", "content": systemPrompt(userName: userName, userContext: userContext)]
        ]
        for message in history.suffix(20) {
            apiMessages.append(["role": message.role, "content": message.content])
        }
        apiMessages.append(["role": "user", "content": userMessage])

        var actionSummaries: [String] = []
        let executor = ClarityToolExecutor(context: context, userEmail: userEmail)

        for _ in 0..<maxToolIterations {
            let body: [String: Any] = [
                "model": model,
                "messages": apiMessages,
                "tools": toolDefinitions,
                "tool_choice": "auto",
                "temperature": 0.4
            ]

            let (content, toolCalls) = try await performChatRequest(body: body)

            if toolCalls.isEmpty {
                return AssistantTurnResult(reply: content ?? "I'm not sure how to help with that yet.", actionSummaries: actionSummaries)
            }

            apiMessages.append([
                "role": "assistant",
                "content": content == nil ? NSNull() : content!,
                "tool_calls": toolCalls.map { call in
                    [
                        "id": call.id,
                        "type": "function",
                        "function": ["name": call.name, "arguments": call.argumentsJSON]
                    ] as [String: Any]
                }
            ])

            for call in toolCalls {
                let result = executor.execute(name: call.name, argumentsJSON: call.argumentsJSON)
                if let summary = result.actionSummary {
                    actionSummaries.append(summary)
                }
                apiMessages.append([
                    "role": "tool",
                    "tool_call_id": call.id,
                    "content": result.message
                ])
            }
        }

        return AssistantTurnResult(
            reply: "I made a few updates, but want to double check something before I say more — could you rephrase that?",
            actionSummaries: actionSummaries
        )
    }

    // MARK: - System prompt

    private func systemPrompt(userName: String, userContext: UserContext) -> String {
        """
        You are Jarvis, the personal AI assistant built into Clarity, \(userName)'s all-in-one life and fitness app.
        You have direct access to \(userName)'s real data through tools — call get_summary before answering any
        question about their tasks, habits, mood, fitness, or finances so you never guess.
        When they ask you to log or create something (a workout, a task, a mood, a transaction, a moment, a habit
        check-in), call the matching tool immediately rather than just describing what you'd do.
        Be warm but concise — a few sentences, not an essay. No markdown headers or bullet lists unless the user
        is explicitly asking for a structured breakdown.

        USER CONTEXT: \(userContext.contextDescription)
        """
    }

    // MARK: - Tool schema

    private var toolDefinitions: [[String: Any]] {
        [
            tool("create_task", "Create a new to-do task for the user.", [
                "title": param("string", "Short task title"),
                "due_in_days": param("integer", "Days from today it's due. 0 = today. Omit for no due date, which defaults to today."),
                "category": paramEnum(["work", "school", "personal", "other"], "Task category")
            ], required: ["title"]),

            tool("complete_task", "Mark an existing open task as completed by matching its title.", [
                "title_match": param("string", "Text to match against existing task titles")
            ], required: ["title_match"]),

            tool("create_habit", "Create a new recurring habit to track.", [
                "name": param("string", "Habit name, e.g. 'Drink Water'"),
                "goal_per_day": param("integer", "Target count per day, default 1")
            ], required: ["name"]),

            tool("log_habit_checkin", "Log a check-in / completion for an existing habit today.", [
                "habit_name": param("string", "Text to match against existing habit names"),
                "value": param("integer", "How much to log, default 1")
            ], required: ["habit_name"]),

            tool("log_mood", "Log the user's mood for today.", [
                "score": param("integer", "Mood from 1 (rough) to 5 (great)"),
                "emotion": param("string", "One-word emotion label, e.g. 'grateful'"),
                "note": param("string", "Optional short note")
            ], required: ["score"]),

            tool("log_moment", "Capture a meaningful life moment — a win, gratitude, connection, or challenge.", [
                "title": param("string", "Short title for the moment"),
                "type": paramEnum(["win", "gratitude", "connection", "challenge", "other"], "Moment type"),
                "note": param("string", "Optional detail")
            ], required: ["title"]),

            tool("add_transaction", "Log a spending transaction.", [
                "amount": param("number", "Dollar amount spent"),
                "category": paramEnum(["food", "shopping", "bills", "transport", "entertainment", "other"], "Spending category"),
                "note": param("string", "What it was for")
            ], required: ["amount"]),

            tool("log_workout", "Log a completed workout.", [
                "type": paramEnum(["run", "walk", "cycle", "strength", "yoga", "swim", "hiit", "other"], "Workout type"),
                "duration_minutes": param("integer", "How long the workout lasted, in minutes"),
                "calories": param("number", "Estimated calories burned, optional"),
                "distance_miles": param("number", "Distance in miles, optional")
            ], required: ["type", "duration_minutes"]),

            tool("set_goal", "Update one of the user's coaching goals.", [
                "goal": paramEnum(["daily_steps", "weekly_workouts", "daily_tasks", "weekly_spend_limit"], "Which goal to update"),
                "value": param("number", "The new target value")
            ], required: ["goal", "value"]),

            tool("get_summary", "Get a snapshot of the user's tasks, habits, mood, fitness, finances, current goals, and Clarity Score for today and this week. Always call this before answering questions about the user's data.", [:], required: [])
        ]
    }

    private func tool(_ name: String, _ description: String, _ properties: [String: Any], required: [String]) -> [String: Any] {
        [
            "type": "function",
            "function": [
                "name": name,
                "description": description,
                "parameters": [
                    "type": "object",
                    "properties": properties,
                    "required": required
                ]
            ]
        ]
    }

    private func param(_ type: String, _ description: String) -> [String: Any] {
        ["type": type, "description": description]
    }

    private func paramEnum(_ values: [String], _ description: String) -> [String: Any] {
        ["type": "string", "description": description, "enum": values]
    }

    // MARK: - Networking

    private func performChatRequest(body: [String: Any]) async throws -> (String?, [AssistantToolCall]) {
        guard let url = URL(string: endpoint) else { throw AssistantError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw AssistantError.noData }

        guard httpResponse.statusCode == 200 else {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorJson["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw AssistantError.apiError(message)
            }
            throw AssistantError.apiError("Status code: \(httpResponse.statusCode)")
        }

        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let first = choices.first,
            let messageDict = first["message"] as? [String: Any]
        else {
            throw AssistantError.decodingError
        }

        let content = messageDict["content"] as? String
        var toolCalls: [AssistantToolCall] = []
        if let rawToolCalls = messageDict["tool_calls"] as? [[String: Any]] {
            for raw in rawToolCalls {
                guard
                    let id = raw["id"] as? String,
                    let function = raw["function"] as? [String: Any],
                    let name = function["name"] as? String,
                    let arguments = function["arguments"] as? String
                else { continue }
                toolCalls.append(AssistantToolCall(id: id, name: name, argumentsJSON: arguments))
            }
        }

        return (content, toolCalls)
    }
}
