//
//  AnalysisResultsView.swift
//  BehavioralCoach
//
//  Shared presentational view that renders an analysis result: transcript,
//  delivery metrics, and coaching critique. Takes plain data (no view model,
//  no live phase) so it can be used by BOTH the live AnalysisView and the
//  read-only SessionDetailView, keeping their rendering from diverging.
//

import SwiftUI

struct AnalysisResultsView: View {
    let transcript: String
    let metrics: SpeechMetrics?
    let critique: Critique?
    let coachingError: String?

    var body: some View {
        VStack(spacing: 16) {
            transcriptSection
            metricsSection
            critiqueSection
            coachingUnavailableNote
        }
    }

    // MARK: - Transcript

    private var transcriptSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Transcript")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            if transcript.isEmpty {
                Text("No speech detected")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(transcript)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Metrics

    @ViewBuilder
    private var metricsSection: some View {
        if let metrics {
            VStack(alignment: .leading, spacing: 8) {
                Text("Delivery")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                statRow("Speaking rate", "\(Int(metrics.wordsPerMinute.rounded())) WPM")
                statRow("Sentences", "\(metrics.sentenceCount)")
                statRow("Avg sentence length",
                        String(format: "%.1f words", metrics.avgSentenceWords))
                statRow("Filler words", "\(metrics.fillerCount)")

                if !metrics.detectedCodas.isEmpty {
                    Text("Detected codas")
                        .font(.subheadline.weight(.semibold))
                        .padding(.top, 4)
                    ForEach(metrics.detectedCodas) { coda in
                        HStack {
                            Text("“\(coda.phrase)”")
                                .font(.callout)
                            Spacer()
                            Text(coda.kind.rawValue)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func statRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.callout.weight(.medium))
        }
    }

    // MARK: - Critique

    @ViewBuilder
    private var critiqueSection: some View {
        if let critique {
            VStack(alignment: .leading, spacing: 12) {
                Text("Coaching")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(critique.overallNote)
                    .font(.body.weight(.medium))
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !critique.strengths.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(critique.strengths, id: \.self) { strength in
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text(strength)
                            }
                        }
                    }
                }

                ForEach(critique.issues) { issue in
                    issueCard(issue)
                }

                if let reframe = critique.suggestedReframe {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Suggested reframe")
                            .font(.subheadline.weight(.semibold))
                        Text(reframe)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func issueCard(_ issue: Critique.Issue) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(issue.kind.rawValue)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.orange.opacity(0.2), in: Capsule())

            Text("“\(issue.excerpt)”")
                .font(.callout)
                .italic()

            Text(issue.explanation)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Coaching unavailable

    @ViewBuilder
    private var coachingUnavailableNote: some View {
        if critique == nil, let reason = coachingError {
            VStack(alignment: .leading, spacing: 4) {
                Label("Coaching unavailable", systemImage: "info.circle")
                    .font(.subheadline.weight(.semibold))
                Text(reason)
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
