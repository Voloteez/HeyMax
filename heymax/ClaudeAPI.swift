//
//  ClaudeAPI.swift
//  heymax
//
//  Claude API client with smart routing, conversation memory,
//  retry logic, request cancellation, system context, and safety.

import Foundation
import AppKit

struct ClaudeResponse {
    let text: String
    let action: AppAction?
    let isTeaching: Bool
    let model: String
    let inputTokens: Int
    let outputTokens: Int
}

enum AppAction {
    case openURL(String)
    case openApp(String)
    case runAppleScript(String)
    case playSpotify(String)
    case searchYouTube(String)
    case setVolume(Int)
    case typeText(String)
}

class ClaudeAPI {
    static let shared = ClaudeAPI()

    // MARK: - Config

    private let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? ""
    private let fastModel = "claude-haiku-4-5-20251001"
    private let smartModel = "claude-sonnet-4-6-20250514"
    private let endpoint = "https://api.anthropic.com/v1/messages"
    private let apiVersion = "2023-06-01"

    // MARK: - State

    private var conversationHistory: [[String: Any]] = []
    private let maxHistory = 20
    private var currentTask: Task<ClaudeResponse, Never>?
    private let maxInputLength = 2000 // Safety: cap voice input length

    // MARK: - System Prompt

    private let systemPrompt = """
    You are Max, a helpful AI assistant that lives on the user's Mac. You can see their screen and hear their voice commands.

    You have TWO modes:

    ## ACTION MODE (default)
    When the user asks you to DO something, respond with a short message + action JSON.

    Action format — include at the END, on its own line:
    ###ACTION:{"type":"<type>","value":"<value>"}

    Available actions:
    - "open_url" — opens a URL. Value: full URL.
    - "open_app" — opens an app. Value: app name.
    - "applescript" — runs AppleScript. Value: script code.
    - "play_spotify" — searches Spotify. Value: search query.
    - "search_youtube" — plays on YouTube. Value: search query.
    - "set_volume" — sets volume 0-100. Value: number.
    - "type_text" — types text at cursor. Value: the text.

    In action mode: be concise, 1-2 sentences max.

    ## TEACH / HELP MODE
    When the user asks for help, wants to learn, is confused, or needs guidance with ANYTHING — switch to teach mode. This includes:

    - Code & programming ("explain this code", "what's wrong here", "how do I fix this")
    - Math & science ("solve this", "help me with this equation", "what's the answer")
    - Creative apps ("how do I do this in Lightroom", "help me edit this photo", "what tool should I use in Figma")
    - Terminal & DevOps ("help me set up my terminal", "what does this command do", "how do I SSH into a server")
    - School & homework ("help me with this problem", "explain this concept", "check my work")
    - Mac tips ("how do I do X on my Mac", "what's this setting", "help me configure this")
    - Any app on their screen ("I'm lost", "how does this work", "what should I click")
    - General knowledge ("teach me about X", "what is X", "explain X")

    In teach mode:
    - ALWAYS look at their screen if available — reference specific things you can see
    - Be specific. Don't give generic advice when you can see the actual situation.
    - If you see a math problem, solve it step by step
    - If you see code with a bug, point out the exact line and fix
    - If you see an app UI, tell them exactly what to click
    - Give clear, structured explanations
    - Keep it conversational — like a smart friend over their shoulder
    - 3-10 sentences depending on complexity
    - End with a follow-up like "Want me to go deeper?" or "Try it and tell me what happens"

    ## CONTEXT
    You receive system context with the current time, active app, and OS version. Use this to give better answers — e.g. if they're in Xcode, you know they're coding. If it's late at night, keep it brief.

    ## CONVERSATION
    You remember recent messages. Follow-ups work naturally.

    ## RULES
    - Be casual and friendly, like a buddy
    - If you can't do something, say so
    - Only include ###ACTION for actual actions, not teaching
    - For music: "on youtube" → search_youtube, "on spotify" or just "play" → play_spotify
    - For websites: use open_url with the correct URL
    - For Mac automation: use applescript
    - NEVER include sensitive info (passwords, keys) in responses
    - When you can see their screen, always reference specific things visible on it
    """

    // MARK: - Keyword Detection

    private let teachKeywords = [
        "teach", "explain", "learn", "how does", "how do", "what is", "what are",
        "walk me through", "help me understand", "show me how", "tutorial",
        "why does", "why is", "tell me about", "break down", "guide me",
        "what's the difference", "how to", "can you explain", "i don't understand",
        "confused about", "help me with", "what does this", "solve", "help me",
        "i'm lost", "i'm stuck", "i don't know", "what should i", "where do i",
        "fix this", "what's wrong", "debug", "check my", "review my",
        "how can i", "is this right", "is this correct", "what's the best way",
        "step by step", "tips for", "advice on", "struggling with"
    ]

    private let screenKeywords = [
        "screen", "see", "look", "looking at", "what's this", "what is this",
        "read", "showing", "display", "this code", "this file", "this page",
        "what's wrong", "debug this", "fix this", "this error", "this bug",
        "this photo", "this image", "this design", "this app", "right now",
        "currently", "i'm stuck", "i'm lost", "check my", "review my",
        "is this right", "is this correct"
    ]

    // MARK: - Public API

    func isTeachingCommand(_ command: String) -> Bool {
        let lower = command.lowercased()
        return teachKeywords.contains(where: { lower.contains($0) })
    }

    func needsScreenshot(command: String) -> Bool {
        let lower = command.lowercased()
        return isTeachingCommand(command) || screenKeywords.contains(where: { lower.contains($0) })
    }

    /// Cancel any in-flight request
    func cancelCurrentRequest() {
        currentTask?.cancel()
        currentTask = nil
    }

    /// Process a voice command with optional screenshot
    func process(command: String, screenshot: String?) async -> ClaudeResponse {
        // Cancel previous request if still running
        cancelCurrentRequest()

        // Safety: sanitize and cap input length
        let sanitized = sanitizeInput(command)

        let task = Task { () -> ClaudeResponse in
            await self.executeRequest(command: sanitized, screenshot: screenshot)
        }
        currentTask = task
        return await task.value
    }

    func clearHistory() {
        conversationHistory.removeAll()
    }

    // MARK: - Internal

    private func executeRequest(command: String, screenshot: String?, retryCount: Int = 0) async -> ClaudeResponse {
        let isTeaching = isTeachingCommand(command)
        let hasScreenshot = screenshot != nil
        let model = (isTeaching || hasScreenshot) ? smartModel : fastModel
        let maxTokens = isTeaching ? 1024 : 256

        // Build system prompt with live context
        let fullSystemPrompt = systemPrompt + "\n\n## CURRENT CONTEXT\n" + getSystemContext()

        // Build current message content
        var currentContent: [[String: Any]] = []

        if let base64 = screenshot {
            currentContent.append([
                "type": "image",
                "source": [
                    "type": "base64",
                    "media_type": "image/jpeg",
                    "data": base64
                ]
            ])
        }

        currentContent.append([
            "type": "text",
            "text": command
        ])

        var messages = conversationHistory
        messages.append(["role": "user", "content": currentContent])

        let body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "system": fullSystemPrompt,
            "messages": messages
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            return errorResponse("Failed to build request.")
        }

        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = isTeaching ? 30 : 15

        do {
            // Check for cancellation before network call
            try Task.checkCancellation()

            let (data, httpResponse) = try await URLSession.shared.data(for: request)

            // Handle HTTP errors with retry
            if let http = httpResponse as? HTTPURLResponse {
                if http.statusCode == 429 || http.statusCode >= 500 {
                    if retryCount < 2 {
                        let delay = Double(retryCount + 1) * 1.5
                        print("[ClaudeAPI] Retrying in \(delay)s (attempt \(retryCount + 1), status \(http.statusCode))")
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        return await executeRequest(command: command, screenshot: screenshot, retryCount: retryCount + 1)
                    }
                    return errorResponse("API is busy. Try again in a moment.")
                }

                if http.statusCode == 401 {
                    return errorResponse("Invalid API key. Check ANTHROPIC_API_KEY in Xcode scheme.")
                }
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let contentArr = json["content"] as? [[String: Any]],
                  let firstBlock = contentArr.first,
                  let responseText = firstBlock["text"] as? String else {

                // Try to extract error message
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = json["error"] as? [String: Any],
                   let message = error["message"] as? String {
                    print("[ClaudeAPI] API error: \(message)")
                    return errorResponse("API error: \(message)")
                }
                return errorResponse("Couldn't parse the response.")
            }

            // Extract usage stats
            let usage = json["usage"] as? [String: Any]
            let inputTokens = usage?["input_tokens"] as? Int ?? 0
            let outputTokens = usage?["output_tokens"] as? Int ?? 0

            let action = parseAction(from: responseText)
            let cleanText = sanitizeOutput(
                responseText.components(separatedBy: "###ACTION:").first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? responseText
            )

            // Save to history (text only, no images)
            conversationHistory.append(["role": "user", "content": command])
            conversationHistory.append(["role": "assistant", "content": responseText])
            while conversationHistory.count > maxHistory {
                conversationHistory.removeFirst(2)
            }

            print("[ClaudeAPI] \(model) | \(inputTokens)→\(outputTokens) tokens | teaching=\(isTeaching)")

            return ClaudeResponse(
                text: cleanText,
                action: action,
                isTeaching: isTeaching,
                model: model,
                inputTokens: inputTokens,
                outputTokens: outputTokens
            )

        } catch is CancellationError {
            print("[ClaudeAPI] Request cancelled")
            return errorResponse("Cancelled.")
        } catch {
            // Retry on network errors
            if retryCount < 2 {
                let delay = Double(retryCount + 1) * 1.0
                print("[ClaudeAPI] Network error, retrying in \(delay)s: \(error.localizedDescription)")
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                return await executeRequest(command: command, screenshot: screenshot, retryCount: retryCount + 1)
            }
            print("[ClaudeAPI] Error after retries: \(error)")
            return errorResponse("Network error. Check your connection.")
        }
    }

    // MARK: - System Context

    private func getSystemContext() -> String {
        let date = DateFormatter.localizedString(from: Date(), dateStyle: .full, timeStyle: .short)
        let frontApp = NSWorkspace.shared.frontmostApplication?.localizedName ?? "Unknown"
        let os = ProcessInfo.processInfo.operatingSystemVersionString
        return """
        - Current time: \(date)
        - Active app: \(frontApp)
        - macOS version: \(os)
        """
    }

    // MARK: - Safety

    private func sanitizeInput(_ input: String) -> String {
        var cleaned = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.count > maxInputLength {
            cleaned = String(cleaned.prefix(maxInputLength))
        }
        return cleaned
    }

    private func sanitizeOutput(_ output: String) -> String {
        // Strip any accidental markdown code fences that might confuse TTS
        var cleaned = output
        cleaned = cleaned.replacingOccurrences(of: "```", with: "")
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func errorResponse(_ message: String) -> ClaudeResponse {
        ClaudeResponse(text: message, action: nil, isTeaching: false, model: "", inputTokens: 0, outputTokens: 0)
    }

    // MARK: - Action Parsing

    private func parseAction(from text: String) -> AppAction? {
        guard let range = text.range(of: "###ACTION:") else { return nil }
        let jsonStr = String(text[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = jsonStr.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: String],
              let type = json["type"],
              let value = json["value"] else {
            return nil
        }

        switch type {
        case "open_url": return .openURL(value)
        case "open_app": return .openApp(value)
        case "applescript": return .runAppleScript(value)
        case "play_spotify": return .playSpotify(value)
        case "search_youtube": return .searchYouTube(value)
        case "set_volume": return .setVolume(Int(value) ?? 50)
        case "type_text": return .typeText(value)
        default: return nil
        }
    }
}
