// Sources/RestackCore/Models.swift
import Foundation

public struct WindowSnapshot: Codable, Equatable {
    public var appBundleID: String
    public var appName: String
    public var title: String
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var displayID: String
    public var indexWithinApp: Int

    public init(appBundleID: String, appName: String, title: String,
                x: Double, y: Double, width: Double, height: Double,
                displayID: String, indexWithinApp: Int) {
        self.appBundleID = appBundleID; self.appName = appName; self.title = title
        self.x = x; self.y = y; self.width = width; self.height = height
        self.displayID = displayID; self.indexWithinApp = indexWithinApp
    }
}

public struct DisplaySnapshot: Codable, Equatable {
    public var stableID: String
    public var width: Double
    public var height: Double
    public var originX: Double
    public var originY: Double

    public init(stableID: String, width: Double, height: Double, originX: Double, originY: Double) {
        self.stableID = stableID; self.width = width; self.height = height
        self.originX = originX; self.originY = originY
    }
}

public struct Snapshot: Codable, Equatable, Identifiable {
    public var id: UUID
    public var name: String
    public var createdAt: Date
    public var displays: [DisplaySnapshot]
    public var windows: [WindowSnapshot]

    public init(id: UUID = UUID(), name: String, createdAt: Date,
                displays: [DisplaySnapshot], windows: [WindowSnapshot]) {
        self.id = id; self.name = name; self.createdAt = createdAt
        self.displays = displays; self.windows = windows
    }
}
