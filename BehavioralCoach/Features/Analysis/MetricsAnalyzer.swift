//
//  MetricsAnalyzer.swift
//  BehavioralCoach
//
//  Phase 3: a pure-Swift implementation that computes SpeechMetrics from
//  a transcript string + total duration.
//
//  Phase 5: the body of `compute` is replaced by a call into the C++
//  coach::compute_metrics() function. The public API stays identical
//  so nothing else in the app needs to change when you flip the
//  implementation.
//
//  This is the clean interop boundary: one function, one input type,
//  one output type. Everything above it in the stack treats it as a
//  black box.
//

import Foundation

enum MetricsAnalyzer {
    /// Compute quantitative metrics from a finished transcript.
    ///
    /// - Parameters:
    ///   - transcript: The full transcribed text of the answer.
    ///   - durationSeconds: Total length of the audio/video in seconds.
    /// - Returns: A `SpeechMetrics` value with all fields populated.
    static func compute(transcript: String, durationSeconds: Double) -> SpeechMetrics {
        let words = transcript.split { !$0.isLetter && !$0.isNumber && $0 != "'" }
        let wordCount = words.count

        let wordsPerMinute = durationSeconds > 0
            ? Double(wordCount) / (durationSeconds / 60.0)
            : 0

        let fillerPhrases = ["um", "uh", "like", "you know", "basically",
                             "actually", "kind of", "sort of"]
        let fillerCount = fillerPhrases.reduce(0) { $0 + countMatches(of: $1, in: transcript) }

        let sentenceCount = transcript.reduce(0) { count, ch in
            (ch == "." || ch == "!" || ch == "?") ? count + 1 : count
        }
        let avgSentenceWords = Double(wordCount) / Double(max(sentenceCount, 1))

        var codas: [DetectedCoda] = []
        codas += detect(["go figure", "turns out", "little did i know",
                          "in hindsight i was right", "the data vindicated"],
                         kind: .vindication, in: transcript)
        codas += detect(["kind of", "sort of", "i guess", "probably",
                          "maybe", "sometimes"],
                         kind: .hedge, in: transcript)
        codas += detect(["they ended up", "it just happened", "the team failed",
                          "things fell apart", "the project died"],
                         kind: .deflection, in: transcript)
        codas.sort { $0.charOffset < $1.charOffset }

        return SpeechMetrics(
            wordsPerMinute: wordsPerMinute,
            avgPauseSeconds: 0,
            longestPauseSeconds: 0,
            fillerCount: fillerCount,
            sentenceCount: sentenceCount,
            avgSentenceWords: avgSentenceWords,
            detectedCodas: codas
        )
    }

    // MARK: - Helpers

    /// Case-insensitive, word-boundary count of `phrase` occurrences in `text`.
    private static func countMatches(of phrase: String, in text: String) -> Int {
        guard let regex = boundaryRegex(for: phrase) else { return 0 }
        let range = NSRange(text.startIndex..., in: text)
        return regex.numberOfMatches(in: text, range: range)
    }

    /// Build a `[DetectedCoda]` for every word-boundary match of any phrase.
    private static func detect(_ phrases: [String], kind: DetectedCoda.Kind, in text: String) -> [DetectedCoda] {
        var found: [DetectedCoda] = []
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        for phrase in phrases {
            guard let regex = boundaryRegex(for: phrase) else { continue }
            regex.enumerateMatches(in: text, range: fullRange) { match, _, _ in
                guard let match else { return }
                // Convert UTF-16 match start to a Swift Character index.
                let offset: Int
                if let r = Range(match.range, in: text) {
                    offset = text.distance(from: text.startIndex, to: r.lowerBound)
                } else {
                    offset = match.range.location
                }
                found.append(DetectedCoda(phrase: phrase, charOffset: offset, kind: kind))
            }
        }
        return found
    }

    private static func boundaryRegex(for phrase: String) -> NSRegularExpression? {
        let pattern = "\\b" + NSRegularExpression.escapedPattern(for: phrase) + "\\b"
        return try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }
}
