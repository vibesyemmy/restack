// Sources/RestackCore/LiveWindow.swift
import Foundation

/// A window currently on screen, as reported by an OS adapter. Pure value type.
public struct LiveWindow: Equatable {
    public let handleID: Int          // opaque adapter handle (e.g. AX window index/id)
    public let title: String
    public let indexWithinApp: Int    // order among this app's windows, as enumerated
    public init(handleID: Int, title: String, indexWithinApp: Int) {
        self.handleID = handleID; self.title = title; self.indexWithinApp = indexWithinApp
    }
}

/// A currently running application.
public struct LiveApp: Equatable {
    public let bundleID: String
    public init(bundleID: String) { self.bundleID = bundleID }
}

/// A currently connected display.
public struct LiveDisplay: Equatable {
    public let stableID: String
    public let originX: Double, originY: Double, width: Double, height: Double
    public var isMain: Bool
    public init(stableID: String, originX: Double, originY: Double,
                width: Double, height: Double, isMain: Bool) {
        self.stableID = stableID; self.originX = originX; self.originY = originY
        self.width = width; self.height = height; self.isMain = isMain
    }
}
