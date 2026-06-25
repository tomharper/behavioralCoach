# Project agent memory

This file is the project's committed home for project-intrinsic agent knowledge: build, test, release, architecture, and sharp-edge notes that should travel with the code.

- Add durable project-specific notes here as they are discovered through real work.

## C++ speech-metric core (`BehavioralCoachCpp`)

- Pure C++17, no deps. Build + run its regression harness standalone (no Xcode needed):
  ```
  clang++ -std=c++17 -IBehavioralCoachCpp/include \
    BehavioralCoachCpp/test/sentence_metrics_test.cpp \
    BehavioralCoachCpp/src/SpeechMetrics.cpp -o /tmp/sentence_metrics_test \
    && /tmp/sentence_metrics_test
  ```
  Exit 0 = all checks pass; non-zero on any failure (CI-gate friendly).
- Gotcha: `compute_metrics`' word splitter treats `.` as a word separator, so a
  decimal like `3.5s` counts as two words (`3`, `5s`). Sentence counting was
  fixed to ignore digit-flanked dots and collapse terminator runs, but the word
  splitter still splits decimals — keep that in mind when reasoning about
  `avgSentenceWords`.

## LLM critique decoding (`Critique.Kind`)

- `Critique.Kind` has a custom `init(from:)` that falls back to `.other` for any
  unrecognized `kind` string, so one unexpected value degrades a single issue
  instead of throwing out the whole critique. When adding a new kind to the coach
  prompt (`PromptLibrary.swift`), add the matching enum case too — the prompt must
  only emit kinds the decoder knows.
