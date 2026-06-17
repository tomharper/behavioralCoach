//
//  AnalysisView.swift
//  BehavioralCoach
//
//  Phase 1: shows "Recording saved" + a replay player for the captured video.
//  Phase 2: adds an on-device transcript section below the player.
//  Phase 3: adds metrics + critique sections (strengths, issues with excerpts).
//  Phase 4: results rendering extracted into AnalysisResultsView (shared with
//           SessionDetailView); analysis is persisted as a Session on .done.
//  Phase 5: metrics section shows speaking rate, pauses, codas from C++ analyzer.
//
//  Design principle: this screen is READ-ONLY. The user watches their video
//  and reads the critique. No editing, no re-recording from here. If they
//  want to try again, they go back to QuestionListView and pick the same
//  question again — history preserves the old session.
//

import SwiftUI
import AVKit

struct AnalysisView: View {
    let videoURL: URL
    let question: Question

    private let player: AVPlayer
    @State private var viewModel = AnalysisViewModel()
    @Environment(\.modelContext) private var modelContext

    init(videoURL: URL, question: Question) {
        self.videoURL = videoURL
        self.question = question
        self.player = AVPlayer(url: videoURL)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Label("Recording saved", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.green)

                VideoPlayer(player: player)
                    .aspectRatio(9.0 / 16.0, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                content
            }
            .padding()
        }
        .navigationTitle("Review")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.analyze(videoURL: videoURL, question: question, context: modelContext)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .transcribing:
            ProgressView("Transcribing…")
                .frame(maxWidth: .infinity, alignment: .center)
        case .computing:
            ProgressView("Analyzing delivery…")
                .frame(maxWidth: .infinity, alignment: .center)
        case .coaching:
            ProgressView("Coaching…")
                .frame(maxWidth: .infinity, alignment: .center)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .done:
            AnalysisResultsView(
                transcript: viewModel.transcript,
                metrics: viewModel.metrics,
                critique: viewModel.critique,
                coachingError: viewModel.coachingError
            )
        }
    }
}
