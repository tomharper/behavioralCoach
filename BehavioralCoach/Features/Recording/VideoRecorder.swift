//
//  VideoRecorder.swift
//  BehavioralCoach
//
//  Phase 1: thin AVFoundation wrapper. Owns the AVCaptureSession (front camera
//  + mic), writes recordings to a unique temp .mov, and exposes async
//  record/stop. The ViewModel owns all UI state; this class just talks to
//  AVFoundation. All session mutation happens on a private serial queue.
//

@preconcurrency import AVFoundation

final class VideoRecorder: NSObject, @unchecked Sendable {

    enum RecorderError: LocalizedError {
        case cameraAccessDenied
        case micAccessDenied
        case deviceUnavailable
        case cannotAddInput
        case cannotAddOutput

        var errorDescription: String? {
            switch self {
            case .cameraAccessDenied: return "Camera access was denied. Enable it in Settings to record."
            case .micAccessDenied:    return "Microphone access was denied. Enable it in Settings to record."
            case .deviceUnavailable:  return "The front camera or microphone is unavailable."
            case .cannotAddInput:     return "Unable to configure the camera input."
            case .cannotAddOutput:    return "Unable to configure the recording output."
            }
        }
    }

    let session = AVCaptureSession()
    private let movieOutput = AVCaptureMovieFileOutput()
    private let sessionQueue = DispatchQueue(label: "VideoRecorder.session")
    private var stopContinuation: CheckedContinuation<URL, Never>?

    // MARK: - Configuration

    func configure() async throws {
        guard try await Self.requestAccess(for: .video) else { throw RecorderError.cameraAccessDenied }
        guard try await Self.requestAccess(for: .audio) else { throw RecorderError.micAccessDenied }

        guard
            let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
            let mic = AVCaptureDevice.default(for: .audio)
        else { throw RecorderError.deviceUnavailable }

        let videoInput = try AVCaptureDeviceInput(device: camera)
        let audioInput = try AVCaptureDeviceInput(device: mic)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            sessionQueue.async {
                do {
                    self.session.beginConfiguration()
                    if self.session.canSetSessionPreset(.high) {
                        self.session.sessionPreset = .high
                    }

                    guard self.session.canAddInput(videoInput) else { throw RecorderError.cannotAddInput }
                    self.session.addInput(videoInput)

                    guard self.session.canAddInput(audioInput) else { throw RecorderError.cannotAddInput }
                    self.session.addInput(audioInput)

                    guard self.session.canAddOutput(self.movieOutput) else { throw RecorderError.cannotAddOutput }
                    self.session.addOutput(self.movieOutput)

                    // Portrait selfie orientation.
                    if let connection = self.movieOutput.connection(with: .video) {
                        if connection.isVideoRotationAngleSupported(90) {
                            connection.videoRotationAngle = 90
                        }
                        if connection.isVideoMirroringSupported {
                            connection.automaticallyAdjustsVideoMirroring = false
                            connection.isVideoMirrored = true
                        }
                    }

                    self.session.commitConfiguration()
                    self.session.startRunning()
                    continuation.resume()
                } catch {
                    self.session.commitConfiguration()
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Recording

    func startRecording() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")
        sessionQueue.async {
            self.movieOutput.startRecording(to: url, recordingDelegate: self)
        }
    }

    func stopRecording() async -> URL {
        await withCheckedContinuation { continuation in
            self.stopContinuation = continuation
            sessionQueue.async {
                self.movieOutput.stopRecording()
            }
        }
    }

    // MARK: - Helpers

    private static func requestAccess(for mediaType: AVMediaType) async throws -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: mediaType) {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: mediaType)
        default: return false
        }
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate

extension VideoRecorder: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput,
                    didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection],
                    error: Error?) {
        let continuation = stopContinuation
        stopContinuation = nil
        continuation?.resume(returning: outputFileURL)
    }
}
