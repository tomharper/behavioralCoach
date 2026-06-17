//
//  QuestionListView.swift
//  BehavioralCoach
//
//  A list of behavioral prompts, grouped by Question.Category. Tapping a
//  row navigates to RecordingView with the chosen question. If the question
//  bank fails to load, shows a ContentUnavailableView with the error.
//

import SwiftUI

struct QuestionListView: View {
    @State private var store = QuestionsStore()

    var body: some View {
        NavigationStack {
            Group {
                if let error = store.loadError {
                    ContentUnavailableView(
                        "Couldn't load questions",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                } else {
                    List {
                        ForEach(Question.Category.allCases, id: \.self) { category in
                            let prompts = store.questions(in: category)
                            if !prompts.isEmpty {
                                Section(label(for: category)) {
                                    ForEach(prompts) { question in
                                        NavigationLink {
                                            RecordingView(question: question)
                                        } label: {
                                            Text(question.prompt)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Practice")
        }
    }

    private func label(for category: Question.Category) -> String {
        switch category {
        case .failureOwnership: "Failure & Ownership"
        case .conflict:         "Conflict"
        case .leadership:       "Leadership"
        case .ambiguity:        "Ambiguity"
        case .influence:        "Influence"
        case .judgment:         "Judgment"
        }
    }
}

#Preview {
    QuestionListView()
}
