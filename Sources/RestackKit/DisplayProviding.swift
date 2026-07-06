// Sources/RestackKit/DisplayProviding.swift
import RestackCore

public protocol DisplayProviding {
    func currentDisplays() -> [LiveDisplay]
}
