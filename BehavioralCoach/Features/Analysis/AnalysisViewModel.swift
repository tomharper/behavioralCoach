//
//  AnalysisViewModel.swift
//  BehavioralCoach
//
//  Orchestrates the post-recording analysis pipeline. Phase 4 scope:
//  transcription → Swift metrics → on-device LLM critique → persist a
//  Session (once). The critique step is best-effort: transcript + metrics
//  still display when Apple Intelligence is unavailable.
//
//      videoURL  →  Transcriber  →  transcript
//                →  MetricsAnalyzer  →  metrics
//                →  LLMAnalyzer  →  critique (non-fatal)
//                →  Session (persisted once, video moved to stable storage)
//

import AVFoundation
import Foundation
import Observation
import SwiftData

@Observable
@MainActor
final class AnalysisViewModel {
    enum Phase {
        case transcribing
        case computing
        case coaching
        case done
        case failed(String)
    }

    private(set) var phase: Phase = .transcribing
    private(set) var transcript: String = ""
    private(set) var metrics: SpeechMetrics?
    private(set) var critique: Critique?
    private(set) var coachingError: String?   // set when the LLM step fails but the pipeline still completes

    let transcriber = Transcriber()
    let llm = LLMAnalyzer()

    private var hasSaved = false   // guard: persist exactly once even if .task re-fires

    func analyze(videoURL: URL, question: Question, context: ModelContext) async {
        // 1. Transcription — REQUIRED. Failure aborts the pipeline.
        phase = .transcribing
        do {
            transcript = try await transcriber.transcribe(videoURL: videoURL)
        } catch {
            phase = .failed(humanMessage(error))
            return
        }

        // 2. Metrics — pure Swift, always succeeds.
        phase = .computing
        let duration = (try? await AVURLAsset(url: videoURL).load(.duration).seconds) ?? 0
        let computed = MetricsAnalyzer.compute(transcript: transcript, durationSeconds: duration)
        metrics = computed

        // 3. Critique — NON-FATAL. Records an error but still finishes.
        phase = .coaching
        do {
            critique = try await llm.critique(transcript: transcript, question: question, metrics: computed)
        } catch {
            coachingError = humanMessage(error)
        }

        phase = .done

        // 4. Persist — exactly once. Move the recording to stable storage so
        // a replay still works after the temp dir is purged.
        if !hasSaved {
            hasSaved = true
            let stableURL = (try? RecordingStore.persist(tempURL: videoURL)) ?? videoURL
            let session = Session(
                question: question,
                durationSeconds: duration,
                videoFileURL: stableURL,
                transcript: transcript
            )
            session.metrics = metrics
            session.critique = critique
            context.insert(session)
            try? context.save()
        }
    }

    private func humanMessage(_ error: Swift.Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}
