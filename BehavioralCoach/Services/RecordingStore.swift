//
//  RecordingStore.swift
//  BehavioralCoach
//
//  File-management helper for persisted recordings. VideoRecorder writes to
//  the system temp directory, which can be purged; when a Session is saved we
//  MOVE the .mov into Documents/Recordings so it survives. The app-sandbox
//  container path can change between launches, so a stored url must always be
//  RE-RESOLVED against the current Documents/Recordings dir before playback.
//

import Foundation

enum RecordingStore {

    /// Documents/Recordings, creating intermediate dirs as needed.
    private static func recordingsDir() throws -> URL {
        let docs = try FileManager.default.url(
            for: .documentDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true)
        let dir = docs.appendingPathComponent("Recordings", isDirectory: true)
        try FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Move `tempURL` into Documents/Recordings keeping its last path
    /// component (or a fresh UUID .mov name); return the destination url.
    static func persist(tempURL: URL) throws -> URL {
        let dir = try recordingsDir()
        let name = tempURL.lastPathComponent.isEmpty
            ? "\(UUID().uuidString).mov" : tempURL.lastPathComponent
        let dest = dir.appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: dest.path) {
            try? FileManager.default.removeItem(at: dest)
        }
        try FileManager.default.moveItem(at: tempURL, to: dest)
        return dest
    }

    /// Rebase `stored.lastPathComponent` onto the CURRENT Recordings dir to
    /// handle a changed sandbox container path. On any oddity return `stored`.
    static func resolve(_ stored: URL) -> URL {
        guard let dir = try? recordingsDir() else { return stored }
        let name = stored.lastPathComponent
        guard !name.isEmpty else { return stored }
        return dir.appendingPathComponent(name)
    }

    /// Best-effort removal of the resolved file; errors ignored.
    static func delete(_ stored: URL) {
        try? FileManager.default.removeItem(at: resolve(stored))
    }
}
