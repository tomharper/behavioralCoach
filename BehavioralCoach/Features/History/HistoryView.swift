//
//  HistoryView.swift
//  BehavioralCoach
//
//  Lists past Session objects from SwiftData, newest first. Tap a row to
//  open the read-only SessionDetailView; swipe to delete (also removes the
//  stable video file). No thumbnails by design.
//

import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(sort: \Session.startedAt, order: .reverse) private var sessions: [Session]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    ContentUnavailableView(
                        "No sessions yet",
                        systemImage: "clock",
                        description: Text("Record an answer to a practice question and your reviewed sessions will show up here.")
                    )
                } else {
                    List {
                        ForEach(sessions) { session in
                            NavigationLink(value: session) {
                                HistoryRow(session: session)
                            }
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationDestination(for: Session.self) { SessionDetailView(session: $0) }
            .navigationTitle("History")
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            let session = sessions[index]
            if let url = session.videoFileURL {
                RecordingStore.delete(url)
            }
            modelContext.delete(session)
        }
        try? modelContext.save()
    }
}

private struct HistoryRow: View {
    let session: Session

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(durationLabel)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Text(session.questionPrompt)
                .font(.subheadline)
                .lineLimit(2)

            if let note = session.critique?.overallNote {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }

    private var durationLabel: String {
        let total = Int(session.durationSeconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
