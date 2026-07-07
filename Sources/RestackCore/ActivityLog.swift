// Sources/RestackCore/ActivityLog.swift
import Foundation

/// One logged Restack action — a restore (manual/login/monitor-change/undo) or a
/// layout-change autosave. The receipt that lets a user verify what Restack actually
/// did (vs. what macOS did on its own).
public struct ActivityEvent: Codable, Equatable, Identifiable {
    public enum Trigger: String, Codable {
        case manual
        case login
        case monitorChange = "monitor-change"
        case undo
        case autosave
    }

    public let id: UUID
    public let timestamp: Date
    public let trigger: Trigger
    public let configID: String?
    public let snapshotName: String?
    public let placed: Int
    public let total: Int
    public let skips: [String]          // "com.app: reason" strings

    public init(id: UUID = UUID(), timestamp: Date, trigger: Trigger,
                configID: String? = nil, snapshotName: String? = nil,
                placed: Int, total: Int, skips: [String] = []) {
        self.id = id
        self.timestamp = timestamp
        self.trigger = trigger
        self.configID = configID
        self.snapshotName = snapshotName
        self.placed = placed
        self.total = total
        self.skips = skips
    }
}

/// Append-only JSONL activity log, capped to the most recent `cap` events.
public final class ActivityLog {
    private let fileURL: URL
    private let cap: Int
    private let fm = FileManager.default

    public init(directory: URL, cap: Int = 200) {
        try? fm.createDirectory(at: directory, withIntermediateDirectories: true)
        self.fileURL = directory.appendingPathComponent("activity.jsonl")
        self.cap = cap
    }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.sortedKeys]
        return e
    }()
    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    public func append(_ event: ActivityEvent) throws {
        var lines = readLines()
        let data = try Self.encoder.encode(event)
        lines.append(String(decoding: data, as: UTF8.self))
        if lines.count > cap { lines.removeFirst(lines.count - cap) }
        try lines.joined(separator: "\n").appending("\n")
            .write(to: fileURL, atomically: true, encoding: .utf8)
    }

    /// Newest first. Corrupt lines are skipped.
    public func recent(limit: Int = 20) -> [ActivityEvent] {
        readLines().reversed().prefix(limit).compactMap { line in
            try? Self.decoder.decode(ActivityEvent.self, from: Data(line.utf8))
        }
    }

    private func readLines() -> [String] {
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { return [] }
        return content.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
    }
}
