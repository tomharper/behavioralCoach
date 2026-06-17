//
//  RecordingViewModel.swift
//  BehavioralCoach
//
//  State machine for a single recording session. Owns the VideoRecorder
//  and exposes enough state for RecordingView to render and drive the UI.
//  Phase 1 stops at .finished(videoURL:); the elapsed-time display lives
//  in the view, not here.
//

import Foundation
import Observation

@Observable
@MainActor
final class RecordingViewModel {
    enum State {
        case idle
        case configuring
        case ready
        case recording(start: Date)
        case finishing
        case finished(videoURL: URL)
        case error(String)
    }

    let question: Question
    private(set) var state: State = .idle
    let recorder = VideoRecorder()

    init(question: Question) {
        self.question = question
    }

    func start() async {
        state = .configuring
        do {
            try await recorder.configure()
            state = .ready
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func beginRecording() {
        recorder.startRecording()
        state = .recording(start: .now)
    }

    func endRecording() async {
        state = .finishing
        let url = await recorder.stopRecording()
        state = .finished(videoURL: url)
    }
}
