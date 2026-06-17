//
//  AnalysisViewModel.swift
//  BehavioralCoach
//
//  Orchestrates the post-recording analysis pipeline. Phase 2 scope:
//  on-device transcription only. Metrics/critique/persistence land in
//  Phase 3/4 (the Phase enum will grow `computing`/`coaching` cases then).
//
//      videoURL  →  Transcriber  →  transcript  →  AnalysisView
//

import Foundation
import Observation

@Observable
@MainActor
final class AnalysisViewModel {
    enum Phase {
        case transcribing
        case done
        case failed(String)
    }

    private(set) var phase: Phase = .transcribing
    private(set) var transcript: String = ""

    let transcriber = Transcriber()

    func analyze(videoURL: URL, question: Question) async {
        phase = .transcribing
        do {
            transcript = try await transcriber.transcribe(videoURL: videoURL)
            phase = .done
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            phase = .failed(message)
        }
    }
}
