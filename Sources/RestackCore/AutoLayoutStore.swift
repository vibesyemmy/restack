// Sources/RestackCore/AutoLayoutStore.swift
import Foundation
import CryptoKit

/// Persists one auto-layout Snapshot per monitor-configuration key.
public protocol AutoLayoutStoring {
    func save(_ snapshot: Snapshot, forConfig key: String) throws
    func load(forConfig key: String) throws -> Snapshot?
    func exists(forConfig key: String) -> Bool
    func delete(forConfig key: String) throws
}

public final class AutoLayoutStore: AutoLayoutStoring {
    private let directory: URL
    private let fm = FileManager.default

    public init(directory: URL) {
        self.directory = directory
        try? fm.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    /// Config keys can contain '|' and other characters; hash to a filesystem-safe name.
    private func url(forConfig key: String) -> URL {
        let digest = SHA256.hash(data: Data(key.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent("\(hex).json")
    }

    public func save(_ snapshot: Snapshot, forConfig key: String) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(snapshot).write(to: url(forConfig: key), options: .atomic)
    }

    public func load(forConfig key: String) throws -> Snapshot? {
        let fileURL = url(forConfig: key)
        guard fm.fileExists(atPath: fileURL.path) else { return nil }
        return try JSONDecoder().decode(Snapshot.self, from: Data(contentsOf: fileURL))
    }

    public func exists(forConfig key: String) -> Bool {
        fm.fileExists(atPath: url(forConfig: key).path)
    }

    public func delete(forConfig key: String) throws {
        let fileURL = url(forConfig: key)
        guard fm.fileExists(atPath: fileURL.path) else { return }
        try fm.removeItem(at: fileURL)
    }
}
