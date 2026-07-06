# Restack — Design Spec (v1)

**Date:** 2026-07-05
**Status:** Approved design, pre-implementation
**One-liner:** A macOS menu-bar app that saves your full multi-monitor window setup and reliably rebuilds it — relaunching apps and placing their windows on the right displays — after a restart or on demand.

---

## 1. Product summary

Professionals arrange running apps across multiple monitors (two browsers side by side on one screen, four quartered windows on another). A restart, logout, or crash destroys that arrangement, and macOS's own restore is unreliable. **Restack** captures a named snapshot of the setup and restores it faithfully: it relaunches the apps that aren't running, waits for their windows, matches them to saved slots, and places each window at its saved frame on its saved display.

**v1 thesis (from market research):** Layout-only restore is commoditized (Rectangle Pro, Stay, DisplayFusion) but *unreliable at exactly the restart/dock moment*. Restack wins on **reliability of relaunch-and-place**, not on feature count. Deep app-state restore (browser tabs, open documents) is the eventual moat but is explicitly deferred.

**Platform:** macOS first. The Accessibility API requirement rules out the Mac App Store, so distribution is **direct download**.

---

## 2. Scope

### In scope (v1)
- **Restore model B:** relaunch missing apps + reposition; reposition-only as fallback.
- **Manual save** — name and store the current workspace ("Deep Work").
- **Manual restore** — pick a saved workspace from the menu bar.
- **Auto-restore on login** — rebuild a designated snapshot after reboot.
- **Auto-save on quit/shutdown** — maintain a "Last Session" snapshot automatically.
- **Multi-monitor fidelity** — windows return to the correct display via stable display IDs.
- **Multi-window-per-app** — e.g. two browser windows placed into their correct slots.
- **First-run Accessibility permission onboarding.**

### Out of scope (v1 — YAGNI, noted as future)
- Deep app state (browser tabs, open documents, scroll/selection).
- Dock/undock auto-detection (→ v1.1).
- Windows support.
- Assigning windows to specific Spaces / virtual desktops (no public API).
- iCloud / cross-device profile sync.

---

## 3. Architecture

Menu-bar app (SwiftUI, no dock icon). Components with clear, testable boundaries:

| Component | Responsibility | Depends on |
|---|---|---|
| **Menu-bar UI** | List/save/restore snapshots; onboarding; restore summary | Snapshot Store, engines |
| **Snapshot Store** | Serialize/load named snapshots as JSON on disk | Filesystem |
| **Display Manager** | Enumerate displays; assign a **stable ID** per monitor; map frames ↔ displays | CoreGraphics display APIs |
| **Capture Engine** | Read running apps + windows; build a Snapshot | AX adapter, NSWorkspace, Display Manager |
| **Restore Engine** | Launch → wait → match → place. The core value. | AX adapter, NSWorkspace, Display Manager |
| **AX Adapter** | Thin, mockable wrapper over Accessibility (AXUIElement) read/write of window frames | Accessibility API |
| **Triggers** | Login item (auto-restore); quit/shutdown observer (auto-save) | Restore/Capture engines |

**Design principle:** the *brain* (matching, display-fallback, serialization) is pure logic with no OS dependency; all OS interaction is isolated behind the AX Adapter and Display Manager so the brain is unit-testable.

Storage location: `~/Library/Application Support/Restack/snapshots/*.json`.

---

## 4. Data model

```
Snapshot {
  id: UUID
  name: String
  createdAt: Date
  displays: [Display]
  windows: [Window]
}

Display {
  stableID: String     // persistent identifier for the physical monitor
  resolution: {w, h}
  origin: {x, y}       // position in the global arrangement
}

Window {
  appBundleID: String
  appName: String
  title: String
  frame: {x, y, w, h}
  displayID: String        // references Display.stableID
  indexWithinApp: Int      // ordering fallback for window matching
}
```

JSON on disk — human-readable, inspectable, backup-friendly.

---

## 5. Core flows

### Save
1. Enumerate running apps (NSWorkspace) and their windows (AX Adapter).
2. For each window record: bundle ID, app name, title, frame, and owning display.
3. Tag each frame with the display's **stable ID** (via Display Manager).
4. Write a named Snapshot to the Store.

### Restore
1. For each distinct app in the snapshot: if not running, **launch** it (NSWorkspace); if running, reuse.
2. **Wait** for the app's windows to appear — bounded polling with a per-app timeout, **not a fixed sleep**.
3. **Match** appeared windows to saved slots: by title first, then by `indexWithinApp` order.
4. **Place** each matched window at its saved frame on its saved display (via AX Adapter).
5. Missing/unlaunchable app or window that never appears → skip and log.
6. Show a **restore summary**: "N of M windows restored," listing what was skipped.

---

## 6. Edge cases & decisions

- **App not installed / won't launch:** skip, continue, report in summary.
- **Window never appears within timeout:** skip that slot; never hang the restore.
- **Ambiguous / duplicate titles:** title match first, then saved order (`indexWithinApp`).
- **Fewer monitors on restore than at save:** clamp affected windows onto the main display rather than placing them off-screen.
- **App auto-reopened its own windows:** Restack still repositions to saved frames — it owns final placement.
- **Login auto-restore target:** default is the auto-maintained **"Last Session"** snapshot; the user may pin any named profile as the login target instead.
- **Spaces limitation (accepted):** no public API to assign a window to a specific Space; Restack places within the current Space. App + size + monitor are correct; Space is not. Documented honestly.

---

## 7. Permissions & onboarding

- Accessibility permission (System Settings → Privacy & Security → Accessibility) is **required** for reading and moving other apps' windows.
- First-run flow: explain why, deep-link to the settings pane, detect grant, and confirm before enabling capture/restore.
- Distribution: direct download, Developer ID signed + notarized (not Mac App Store — Sandbox forbids the AX use).

---

## 8. Testing strategy

Reliability is the product, so the risk-bearing logic must be provably correct:

- **Unit tests (primary):** window-matching algorithm, display-fallback/clamp logic, and Snapshot serialization — all pure functions, no OS calls, exhaustively tested (duplicate titles, missing display, extra/fewer windows, unlaunchable app).
- **AX Adapter is mocked** in unit tests so the Restore Engine's decision logic runs without real windows.
- **Integration smoke test (semi-automated):** open known apps (TextEdit, Safari) in a scripted arrangement, save, scramble, restore, assert final frames within tolerance.
- **Manual reliability matrix:** single vs multi monitor; app running vs closed; multi-window apps; monitor-count mismatch on restore.

---

## 9. Success criteria (v1)

1. Save then restore on a 2-monitor setup reproduces window frames within a small pixel tolerance.
2. After a real reboot, auto-restore rebuilds the "Last Session" workspace, relaunching closed apps and placing their windows correctly.
3. Two same-app windows (e.g. two browsers) land in their correct respective slots.
4. Graceful degradation: a missing app or monitor never crashes or hangs a restore; the user gets an honest summary.

---

## 10. Risks

- **Window matching** is the hardest part; apps with generic/identical titles degrade to order-based matching. Mitigation: design for graceful degradation, thorough unit coverage.
- **OS encroachment:** Apple keeps improving native window management. Mitigation: reliability + the deferred deep-state moat, which Apple is unlikely to touch soon.
- **Per-app quirks** in launch/window timing. Mitigation: bounded polling + skip-and-report, never block.

---

## Appendix: source research
See `../../../desktop-session-manager-research.md` (competitor teardown, OS-native gaps, demand signals, feasibility, pricing) — note: sourced but adversarial-verification pass did not complete.
