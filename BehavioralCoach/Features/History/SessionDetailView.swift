//
//  SessionDetailView.swift
//  BehavioralCoach
//
//  Read-only view of a past session: video replay, prompt, and the shared
//  AnalysisResultsView (transcript + metrics + critique). Same presentational
//  view as the live AnalysisView so they cannot visually diverge.
//
//  The stored videoFileURL is re-resolved against the current Documents/
//  Recordings directory before playback — the app-sandbox container path can
//  change between launches.
//

import SwiftUI
import AVKit

struct SessionDetailView: View {
    let session: Session

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let url = session.videoFileURL {
                    VideoPlayer(player: AVPlayer(url: RecordingStore.resolve(url)))
                        .aspectRatio(9.0 / 16.0, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                Text(session.questionPrompt)
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.secondarySystemBackground),
                                in: RoundedRectangle(cornerRadius: 12))

                AnalysisResultsView(
                    transcript: session.transcript,
                    metrics: session.metrics,
                    critique: session.critique,
                    coachingError: nil
                )
            }
            .padding()
        }
        .navigationTitle(session.startedAt.formatted(date: .abbreviated, time: .shortened))
        .navigationBarTitleDisplayMode(.inline)
    }
}
