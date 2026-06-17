//
//  RecordingView.swift
//  BehavioralCoach
//
//  The screen the user sees while answering a question: camera preview on
//  top, the question prompt in a card, and a record/stop button at the
//  bottom. Drives a RecordingViewModel; on .finished navigates to the
//  AnalysisView for replay.
//

import SwiftUI

struct RecordingView: View {
    let question: Question

    @State private var viewModel: RecordingViewModel

    init(question: Question) {
        self.question = question
        _viewModel = State(initialValue: RecordingViewModel(question: question))
    }

    var body: some View {
        VStack(spacing: 16) {
            CameraPreview(session: viewModel.recorder.session)
                .aspectRatio(9.0 / 16.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .frame(maxWidth: .infinity)

            promptCard

            Spacer(minLength: 0)

            controls
                .padding(.bottom, 24)
        }
        .padding(.horizontal)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: finishedURL) { url in
            AnalysisView(videoURL: url, question: question)
        }
        .task { await viewModel.start() }
    }

    // MARK: - Subviews

    private var promptCard: some View {
        Text(question.prompt)
            .font(.headline)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var controls: some View {
        switch viewModel.state {
        case .idle, .configuring:
            ProgressView()
                .frame(width: 72, height: 72)
        case .ready:
            RecordButton(isRecording: false) {
                viewModel.beginRecording()
            }
        case .recording(let start):
            VStack(spacing: 12) {
                ElapsedLabel(start: start)
                RecordButton(isRecording: true) {
                    Task { await viewModel.endRecording() }
                }
            }
        case .finishing:
            VStack(spacing: 12) {
                ProgressView()
                Text("Saving…")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(height: 72)
        case .finished:
            ProgressView()
                .frame(width: 72, height: 72)
        case .error(let message):
            VStack(spacing: 12) {
                Text(message)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button("Retry") {
                    Task { await viewModel.start() }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    /// Bridges the .finished state into a navigationDestination(item:) binding.
    private var finishedURL: Binding<URL?> {
        Binding(
            get: {
                if case .finished(let url) = viewModel.state { return url }
                return nil
            },
            set: { _ in }
        )
    }
}

// MARK: - Record button

private struct RecordButton: View {
    let isRecording: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .stroke(.white, lineWidth: 4)
                    .frame(width: 72, height: 72)
                RoundedRectangle(cornerRadius: isRecording ? 6 : 28)
                    .fill(.red)
                    .frame(
                        width: isRecording ? 32 : 56,
                        height: isRecording ? 32 : 56
                    )
            }
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isRecording)
        .accessibilityLabel(isRecording ? "Stop recording" : "Start recording")
    }
}

// MARK: - Elapsed counter

private struct ElapsedLabel: View {
    let start: Date

    var body: some View {
        TimelineView(.periodic(from: start, by: 0.5)) { context in
            Text(format(context.date.timeIntervalSince(start)))
                .font(.title3.monospacedDigit())
                .foregroundStyle(.red)
        }
    }

    private func format(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

#Preview {
    NavigationStack {
        RecordingView(
            question: Question(
                id: UUID(),
                prompt: "Tell me about a time you were wrong.",
                category: .failureOwnership,
                probeType: .direct
            )
        )
    }
}
