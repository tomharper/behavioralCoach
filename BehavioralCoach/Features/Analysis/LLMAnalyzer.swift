//
//  LLMAnalyzer.swift
//  BehavioralCoach
//
//  Phase 3: generates a Critique from a transcript + question context using
//  Apple's Foundation Models framework, entirely on-device. The model is
//  asked for JSON TEXT (PromptLibrary instructs the shape); we strip any
//  wrapping markdown fence and JSONDecode into Critique. Best-effort: if
//  Apple Intelligence is unavailable, throws .unavailable and the pipeline
//  still shows transcript + metrics.
//

import Foundation
import FoundationModels

final class LLMAnalyzer: Sendable {

    enum Error: Swift.Error, LocalizedError {
        case unavailable(String)
        case generationFailed(String)

        var errorDescription: String? {
            switch self {
            case .unavailable(let reason): return reason
            case .generationFailed(let reason): return reason
            }
        }
    }

    func critique(
        transcript: String,
        question: Question,
        metrics: SpeechMetrics
    ) async throws -> Critique {
        guard #available(iOS 26.0, *) else {
            throw Error.unavailable("On-device coaching needs a newer iOS version.")
        }

        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            break
        case .unavailable(let reason):
            throw Error.unavailable(Self.message(for: reason))
        @unknown default:
            throw Error.unavailable("On-device coaching is unavailable on this device.")
        }

        let system = PromptLibrary.coachSystemPrompt(for: question)
        let user = PromptLibrary.coachUserPrompt(transcript: transcript, metrics: metrics)

        let raw: String
        do {
            let session = LanguageModelSession(instructions: system)
            let response = try await session.respond(to: user)
            raw = response.content
        } catch {
            throw Error.generationFailed(
                (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            )
        }

        let json = Self.stripFence(raw)
        guard let data = json.data(using: .utf8) else {
            throw Error.generationFailed("Coach returned an undecodable response.")
        }
        do {
            return try JSONDecoder().decode(Critique.self, from: data)
        } catch {
            throw Error.generationFailed("Coach returned malformed JSON: \(error.localizedDescription)")
        }
    }

    /// Strip surrounding whitespace and any wrapping ```...``` markdown fence
    /// the model may add around the JSON object.
    private static func stripFence(_ text: String) -> String {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard s.hasPrefix("```") else { return s }
        // Drop opening fence line (handles ```json etc.).
        if let firstNewline = s.firstIndex(of: "\n") {
            s = String(s[s.index(after: firstNewline)...])
        } else {
            s = String(s.dropFirst(3))
        }
        // Drop closing fence.
        if let range = s.range(of: "```", options: .backwards) {
            s = String(s[..<range.lowerBound])
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @available(iOS 26.0, *)
    private static func message(for reason: SystemLanguageModel.Availability.UnavailableReason) -> String {
        switch reason {
        case .deviceNotEligible:
            return "This device doesn't support Apple Intelligence, so coaching is unavailable."
        case .appleIntelligenceNotEnabled:
            return "Turn on Apple Intelligence in Settings to get coaching feedback."
        case .modelNotReady:
            return "The on-device model is still downloading. Try again shortly."
        @unknown default:
            return "On-device coaching is unavailable on this device."
        }
    }
}
