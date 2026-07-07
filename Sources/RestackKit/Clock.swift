// Sources/RestackKit/Clock.swift
import Foundation

public protocol Clock {
    func now() -> Date
    func sleep(_ interval: TimeInterval)
}

public struct SystemClock: Clock {
    public init() {}
    public func now() -> Date { Date() }
    public func sleep(_ interval: TimeInterval) { Thread.sleep(forTimeInterval: interval) }
}
