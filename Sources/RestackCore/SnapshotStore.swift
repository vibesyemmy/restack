// Sources/RestackCore/SnapshotStore.swift
import Foundation

public enum SnapshotStoreError: Error, Equatable {
    case notFound(UUID)
}

public final class SnapshotStore {
    private let directory: URL
    private let fm = FileManager.default

    public init(directory: URL) {
        self.directory = directory
        try? fm.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func url(for id: UUID) -> URL {
        directory.appendingPathComponent("\(id.uuidString).json")
    }

    public func save(_ snapshot: Snapshot) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(snapshot)
        try data.write(to: url(for: snapshot.id), options: .atomic)
    }

    public func load(id: UUID) throws -> Snapshot {
        let fileURL = url(for: id)
        guard fm.fileExists(atPath: fileURL.path) else { throw SnapshotStoreError.notFound(id) }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(Snapshot.self, from: data)
    }

    public func list() throws -> [Snapshot] {
        let files = (try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        let snaps = files.filter { $0.pathExtension == "json" }.compactMap { url -> Snapshot? in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? JSONDecoder().decode(Snapshot.self, from: data)
        }
        return snaps.sorted { $0.createdAt > $1.createdAt }
    }

    public func delete(id: UUID) throws {
        let fileURL = url(for: id)
        guard fm.fileExists(atPath: fileURL.path) else { throw SnapshotStoreError.notFound(id) }
        try fm.removeItem(at: fileURL)
    }
}
