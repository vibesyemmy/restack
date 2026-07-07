// Sources/RestackCore/RestorePlanner.swift
import Foundation

public struct AppRestorePlan: Equatable {
    public let bundleID: String
    public let needsLaunch: Bool
    public let windows: [WindowSnapshot]   // saved slots for this app, in indexWithinApp order
}

public struct RestorePlan: Equatable {
    public let appPlans: [AppRestorePlan]
    public var appsToLaunch: [String] { appPlans.filter(\.needsLaunch).map(\.bundleID) }
}

public enum RestorePlanner {
    public static func plan(snapshot: Snapshot, runningBundleIDs: Set<String>) -> RestorePlan {
        // Group windows by bundle, preserving first-seen order for determinism.
        var order: [String] = []
        var byApp: [String: [WindowSnapshot]] = [:]
        for w in snapshot.windows {
            if byApp[w.appBundleID] == nil { order.append(w.appBundleID) }
            byApp[w.appBundleID, default: []].append(w)
        }
        let appPlans = order.map { bundle in
            AppRestorePlan(
                bundleID: bundle,
                needsLaunch: !runningBundleIDs.contains(bundle),
                windows: (byApp[bundle] ?? []).sorted { $0.indexWithinApp < $1.indexWithinApp }
            )
        }
        return RestorePlan(appPlans: appPlans)
    }

    // Convenience overload taking an array.
    public static func plan(snapshot: Snapshot, runningBundleIDs: [String]) -> RestorePlan {
        plan(snapshot: snapshot, runningBundleIDs: Set(runningBundleIDs))
    }
}
