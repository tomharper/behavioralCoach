# Behavioral Coach

A native iOS app for practicing behavioral and system-design interview answers. Records you on camera, transcribes what you said, and uses on-device Apple Intelligence to critique both **how you present** and **what you actually said**.

It analyzes two layers:

- **Presentation / delivery** — vocal tone (pace, energy, monotone vs. varied), eye contact (are you looking at the camera or away), and tempo (speaking rate, filler words, pauses). The things you can't feel in the moment but that an interviewer reads instantly.
- **Content** — the substance of the answer: structure, whether you own the mistake, whether you state what you learned, and the reflexes that tank senior interviews (reframe/vindication codas, hedging, deflection, missing specifics).

Everything runs on-device. Nothing leaves the phone. Failure stories are sensitive; they don't belong in anyone's cloud logs.

> **Scope note:** content + tempo/filler analysis is modeled in the current scaffold (`Critique`, `SpeechMetrics`). **Vocal tone** (audio prosody) and **eye contact** (Vision face/gaze tracking) are intended dimensions that aren't modeled yet — they'll need new metric fields and a dedicated analysis phase. See [Roadmap](#roadmap-presentation-analysis).

## Why this exists

Principal/Staff behavioral interviews probe for EQ and self-awareness with a specific question shape — "tell me about a time you were confidently wrong." The failure mode is usually not lack of stories, it's reflexive reframing: stories that end with a vindication beat ("...go figure") that quietly undoes the failure. You can't catch the reflex in the moment; you have to see it on playback.

This tool is that playback, with annotations.

## Requirements

- **iOS 18.1+** for the core loop: record → replay → on-device transcription → speech metrics.
- **iOS 26+** for the LLM coaching critique — the **Foundation Models framework** (`LanguageModelSession`) is an iOS 26 API, *not* iOS 18.1. The app gates it behind `if #available(iOS 26.0, *)`; on 18.1–18.x you still get transcript + metrics, but the critique section shows "coaching unavailable."
- Device with Apple Intelligence support (iPhone 15 Pro and later, or A17 Pro / M-series iPad).
- **Xcode 26+** (iOS 26 SDK) to build the coaching path. Built and verified against `iphonesimulator26.2`.

## Current status

**Phases 1–4 implemented and building** (verified via `xcodebuild`, iOS Simulator). End-to-end today: pick a question → record → replay → on-device transcript → speech metrics → LLM coaching critique (requires iOS 26 — see Requirements) → saved session → History tab → reopen any past session.

- ✅ **Phase 1 — record → replay:** `QuestionListView`, `RecordingView`, `RecordingViewModel`, `VideoRecorder`, `CameraPreview`, `AnalysisView` player.
- ✅ **Phase 2 — transcription:** `Transcriber` (on-device `SFSpeechRecognizer`, `requiresOnDeviceRecognition = true`, no cloud fallback).
- ✅ **Phase 3 — metrics + critique:** `MetricsAnalyzer` (Swift), `LLMAnalyzer` (Foundation Models, manual JSON decode, availability-gated), full pipeline in `AnalysisViewModel`, metrics + critique UI in `AnalysisView`.
- ✅ **Phase 4 — persistence + History:** `Session` saved to SwiftData after analysis; `RecordingStore` moves videos to stable `Documents/Recordings` (re-resolved across launches); `HistoryView` (list + swipe-delete) and `SessionDetailView` (read-only replay) share `AnalysisResultsView` with the live screen.
- ⬜ **Phase 5 (next):** `BehavioralCoachCpp/` — move `MetricsAnalyzer.compute` into a C++ module (the clean interop boundary; the Swift signature stays identical). Note: new C++ sources + the bridging header must be wired into `project.pbxproj`.
- ⬜ **Roadmap:** vocal-tone (audio prosody) and eye-contact (Vision gaze) presentation analysis — see [Roadmap](#roadmap-presentation-analysis).

> ⚠️ **Not yet smoke-tested on a physical device.** Recording needs a real camera (the Simulator has none). The build is green but the record → replay → analyze loop hasn't been exercised on-device yet.

## Build phases

The project is designed so there's always a working app after each phase. Do not skip ahead — each phase builds on the previous, and Phase 1 alone is already useful for practice (you can record and replay without any analysis).

| Phase | Goal | Est. |
|---|---|---|
| 1 | App shell: questions list → video recording → replay. No transcription, no LLM, no persistence. | 1–2 evenings |
| 2 | Transcription via `SFSpeechRecognizer` at end of recording. | 1 evening |
| 3 | LLM critique via Foundation Models framework. | 1–2 evenings |
| 4 | SwiftData persistence + History tab. | 1 evening |
| 5 | **First Swift/C++ interop boundary.** Metrics computation moves into a C++ module. | 1 evening |
| 6+ | Optional: C++ DSP audio features, whisper.cpp, custom questions, export. | — |

## Roadmap: presentation analysis

The reflex/content analysis is the core, but the full vision scores delivery too. These slot in after the Phase 1–4 loop works end-to-end:

| Dimension | Source | How | Where it lands |
|---|---|---|---|
| **Vocal tone** | recorded audio track | extract pitch/energy contour (pace, loudness variance, monotone detection) via audio analysis — candidate for the Phase 5 C++ module | new fields on `SpeechMetrics` (e.g. `pitchVariance`, `energyVariance`, `monotoneScore`) |
| **Eye contact** | recorded video frames | Vision framework face landmarks + gaze direction sampled per frame; % of time looking at lens, longest look-away | new `PresenceMetrics` type (gaze on-camera %, look-away count) |

Both feed the LLM critique as additional context so the coach can comment on delivery, not just words ("you looked away every time you hit the hard part of the story").

## Directory layout

```
ios-behavioral-coach/
├── BehavioralCoach.xcodeproj/              (you create this in Xcode)
├── BehavioralCoach/
│   ├── BehavioralCoachApp.swift            @main entry, SwiftData container
│   ├── ContentView.swift                   root, TabView: Practice | History
│   │
│   ├── Models/                             data types (no UI, no I/O)
│   │   ├── Question.swift
│   │   ├── Session.swift                   @Model (SwiftData)
│   │   ├── SpeechMetrics.swift             Swift mirror of C++ struct (Phase 5)
│   │   └── Critique.swift
│   │
│   ├── Features/                           one folder per screen/feature
│   │   ├── Questions/
│   │   │   ├── QuestionListView.swift
│   │   │   └── QuestionsStore.swift        loads questions.json
│   │   ├── Recording/
│   │   │   ├── RecordingView.swift         camera preview + controls
│   │   │   ├── RecordingViewModel.swift    @Observable, state machine
│   │   │   ├── VideoRecorder.swift         wraps AVCaptureSession
│   │   │   └── CameraPreview.swift         UIViewRepresentable
│   │   ├── Analysis/
│   │   │   ├── AnalysisView.swift          transcript + metrics + critique
│   │   │   ├── AnalysisViewModel.swift     orchestrates the pipeline
│   │   │   ├── Transcriber.swift           SFSpeechRecognizer on the video's audio track
│   │   │   ├── MetricsAnalyzer.swift       Swift wrapper; calls C++ in Phase 5
│   │   │   └── LLMAnalyzer.swift           Foundation Models framework
│   │   └── History/
│   │       ├── HistoryView.swift
│   │       └── SessionDetailView.swift     AVPlayer replay + results
│   │
│   ├── Services/
│   │   └── PromptLibrary.swift             LLM system prompt for the coach
│   │
│   └── Resources/
│       └── questions.json                  bundled behavioral prompts
│
├── BehavioralCoachCpp/                     (added in Phase 5)
│   ├── include/SpeechMetrics.hpp
│   └── src/SpeechMetrics.cpp
│
└── README.md
```

## Phase 1 setup (do this first)

### Create the Xcode project

1. Xcode → File → New → Project → iOS → App
2. Product name: `BehavioralCoach`
3. Interface: SwiftUI
4. Storage: SwiftData
5. Testing system: Swift Testing (optional but recommended)
6. Minimum deployment: **iOS 18.1**
7. Save the `.xcodeproj` at `ios-behavioral-coach/BehavioralCoach.xcodeproj/` — overwriting is fine, the scaffold files will drop into `BehavioralCoach/` next to it.
8. After project creation, drag the pre-scaffolded `BehavioralCoach/Models`, `BehavioralCoach/Features`, `BehavioralCoach/Services`, and `BehavioralCoach/Resources` folders into the Xcode file navigator. Choose *"Create groups"*, not *"Create folder references"*.

### Info.plist permissions (REQUIRED — app will crash without these)

Project settings → Info tab → add these three keys:

| Key | Value |
|---|---|
| `NSCameraUsageDescription` | *We record you answering so you can watch your own delivery and catch reflexes you can't feel in the moment.* |
| `NSMicrophoneUsageDescription` | *We record audio alongside the video to analyze your speech.* |
| `NSSpeechRecognitionUsageDescription` | *We transcribe your recorded answers on-device so nothing leaves your phone.* |

### Scaffold files

The Swift files in `Models/`, `Features/`, `Services/`, and `Resources/` are pre-written with:

- Data model types fully implemented
- View files as stubs with doc comments describing what each should do
- `questions.json` with 20 real behavioral prompts covering the question types you're most likely to get

Your job in Phase 1 is to fill in the View and ViewModel files. The Models, Services, and Resources are done — don't rewrite them.

## Privacy note

This app does not send anything to the network. No telemetry, no crash reporting, no cloud sync, no account system. Everything — audio, video, transcripts, critiques — lives on the device. Delete the app to delete the data.

The reason this matters: failure stories are sensitive. A story you practice here may reference real people, real projects, real companies. That kind of content does not belong in anyone's server logs, training data, or backup system. On-device is the only safe choice for this category of tool.
