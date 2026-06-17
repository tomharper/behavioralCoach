//
//  Transcriber.swift
//  BehavioralCoach
//
//  Takes a recorded video URL and returns its transcript using
//  SFSpeechRecognizer running strictly on-device.
//
//  PRIVACY: transcription must never leave the phone. We require
//  on-device recognition and fail loudly if it isn't available —
//  no cloud/server fallback. SFSpeechURLRecognitionRequest reads the
//  .mov audio track directly, so no manual AVAssetReader extraction.
//

import Foundation
import Speech

final class Transcriber: Sendable {
    enum Error: Swift.Error, LocalizedError {
        case notAvailable
        case notAuthorized
        case recognitionFailed(String)

        var errorDescription: String? {
            switch self {
            case .notAvailable:
                return "On-device speech recognition isn't available on this device."
            case .notAuthorized:
                return "Speech recognition permission was denied."
            case .recognitionFailed(let message):
                return message
            }
        }
    }

    func transcribe(videoURL: URL) async throws -> String {
        let status: SFSpeechRecognizerAuthorizationStatus = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
        }
        guard status == .authorized else { throw Error.notAuthorized }

        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")),
              recognizer.isAvailable,
              recognizer.supportsOnDeviceRecognition
        else { throw Error.notAvailable }

        let request = SFSpeechURLRecognitionRequest(url: videoURL)
        request.requiresOnDeviceRecognition = true  // non-negotiable: stays on device
        request.shouldReportPartialResults = false

        return try await withCheckedThrowingContinuation { cont in
            var didResume = false
            recognizer.recognitionTask(with: request) { result, error in
                guard !didResume else { return }
                if let error {
                    didResume = true
                    cont.resume(throwing: Error.recognitionFailed(error.localizedDescription))
                    return
                }
                if let result, result.isFinal {
                    didResume = true
                    cont.resume(returning: result.bestTranscription.formattedString)
                }
            }
        }
    }
}
