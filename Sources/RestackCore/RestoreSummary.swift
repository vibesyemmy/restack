// Sources/RestackCore/RestoreSummary.swift
import Foundation

public struct RestoreSummary: Equatable {
    public struct Skip: Equatable { public let app: String; public let reason: String }
    public let totalWindows: Int
    public private(set) var placedCount: Int = 0
    public private(set) var skipped: [Skip] = []

    public init(totalWindows: Int) { self.totalWindows = totalWindows }
    public mutating func recordPlaced() { placedCount += 1 }
    public mutating func recordSkipped(app: String, reason: String) {
        skipped.append(Skip(app: app, reason: reason))
    }
    public var headline: String { "\(placedCount) of \(totalWindows) windows restored" }
}
