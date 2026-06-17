//
//  AnalysisView.swift
//  BehavioralCoach
//
//  Phase 1: shows "Recording saved" + a replay player for the captured video.
//  Phase 2: adds an on-device transcript section below the player.
//  Phase 3: adds critique section (strengths, issues with excerpts).
//  Phase 4: this screen is also reached from History via SessionDetailView.
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
    // In Phase 4 this takes a Session so it can be reopened from history.
    let videoURL: URL
    let question: Question

    private let player: AVPlayer
    @State private var viewModel = AnalysisViewModel()

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

                transcriptSection
            }
            .padding()
        }
        .navigationTitle("Review")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.analyze(videoURL: videoURL, question: question)
        }
    }

    @ViewBuilder
    private var transcriptSection: some View {
        switch viewModel.phase {
        case .transcribing:
            ProgressView("Transcribing…")
                .frame(maxWidth: .infinity, alignment: .center)

        case .done:
            VStack(alignment: .leading, spacing: 8) {
                Text("Transcript")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if viewModel.transcript.isEmpty {
                    Text("No speech detected")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(viewModel.transcript)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
