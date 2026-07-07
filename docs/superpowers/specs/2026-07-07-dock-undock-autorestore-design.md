# Restack v1.1 — Dock/Undock Auto-Restore — Design Spec

**Date:** 2026-07-07
**Status:** Approved design, pre-implementation
**Branch:** `v1.1-dock-detect`
**One-liner:** When the monitor configuration changes (dock/undock, monitor plug/unplug), Restack automatically restores the window layout it last had on that exact setup — opt-in, with an Undo.

---

## 1. Summary

The sharpest pain from the market research: unplug an external monitor and macOS scrambles all your windows onto the laptop screen; re-dock and you rebuild the arrangement by hand. v1 restores layouts on demand and on login. v1.1 makes it **automatic on monitor configuration change**.

**Model (decided):** fully automatic, per-configuration. Restack keeps one rolling "auto-layout" snapshot for each distinct monitor configuration, identified by the set of connected display IDs. On a config change it restores that configuration's remembered layout. No naming, no manual assignment (that pinning layer is deferred).

**Control (decided):** opt-in. A single setting, **off by default**: "Auto-restore layout when monitors change." When an auto-restore fires, Restack posts a notification with an **Undo** action.

**Capture (decided):** periodic background autosave. Because macOS scrambles windows the instant a display drops, Restack cannot capture the outgoing layout at disconnect time. Instead it periodically autosaves the current config's layout while stable, so a recent, good layout is always on file to restore.

---

## 2. Scope

### In scope (v1.1)
- Detect monitor configuration changes (display connect/disconnect) with debounce.
- Identify a configuration by the sorted set of connected display stable IDs.
- Maintain one rolling auto-layout snapshot per configuration (periodic autosave while stable + enabled).
- On a debounced change to a configuration that has a saved auto-layout, restore it via the existing `RestoreEngine`.
- Capture the pre-restore ("incoming, scrambled") state as a single-level **Undo** baseline; expose Undo via a notification action, with a transient menu-item fallback.
- Opt-in toggle (off by default), persisted; starting/stopping all background activity with the toggle.
- Post a user notification on auto-restore.

### Out of scope (v1.1 — deferred)
- Manual pinning of a *named* workspace to a configuration (the power-user B/C layer).
- Multi-level undo / undo history.
- Disambiguating two configurations that share the same display-ID set but differ in arrangement.
- Handling identical-model displays with no serial (inherits v1's known stable-ID limitation).
- Cross-device sync of auto-layouts.

---

## 3. Architecture

Reuses v1 wholesale: `Snapshot`, `CaptureEngine`, `RestoreEngine`, `DisplayProviding`, `WindowControlling`, `WorkspaceControlling`, `Clock`. New pieces isolate the reliability-critical logic into pure, testable units behind the OS adapters.

| Component | Layer | Responsibility |
|---|---|---|
| `DisplayConfigID` | RestackCore (pure) | Compute a stable configuration key from `[LiveDisplay]` (sorted, joined stable IDs) |
| `ConfigChangeDebouncer` | RestackCore (pure) | Given timestamped config-observation events + a `Clock`, emit a "new stable config" only after the set holds steady for the debounce interval; absorb flapping; ignore no-op changes |
| `AutoLayoutStore` | RestackCore | Persist/load one `Snapshot` per configuration key (sanitized filename under an `auto/` subdir); `save`/`load`/`exists`/`delete` |
| `AutosaveDecider` | RestackCore (pure) | Given last-autosave time, current time, and transition state, decide whether an autosave is due (throttle + skip-during-transition) |
| `DisplayConfigWatcher` | RestackKit | Observe `NSApplication.didChangeScreenParametersNotification` / CG reconfiguration; feed observations to the debouncer; thin adapter |
| `AutosaveScheduler` | RestackKit | Timer that, while enabled+stable, asks `AutosaveDecider` and triggers a capture→`AutoLayoutStore.save` for the current config |
| `Notifying` (+ `UNUserNotificationNotifier`) | RestackKit | Protocol to post an auto-restore notification with an Undo action; real impl uses `UNUserNotificationCenter`; faked in tests |
| `DockRestoreCoordinator` | RestackKit | The brain: owns the watcher, debouncer, scheduler, store, engines, notifier, clock; handles config-change events; performs restore + captures Undo baseline + notifies; exposes `undoLastRestore()` |
| Toggle + wiring | App | `RestackSettings.autoRestoreOnConfigChange` (off by default); `AppModel` starts/stops the coordinator; menu shows the toggle and the transient Undo fallback |

**Boundary rule (unchanged):** RestackCore imports no AppKit. All OS interaction (screen notifications, timers, notifications) lives in RestackKit adapters; the decision logic (`DisplayConfigID`, `ConfigChangeDebouncer`, `AutosaveDecider`, and the coordinator's branching, tested via fakes) is pure and unit-tested.

---

## 4. Data & keys

**Configuration key** — `DisplayConfigID.make(from: [LiveDisplay]) -> String`: take each display's `stableID`, sort ascending, join with `|`. Order-independent; deterministic. Example: `"builtin|V123-M4-S5"`.

**Auto-layout storage** — `AutoLayoutStore` writes one `Snapshot` (the existing v1 model) per config key. Filename = a filesystem-safe encoding of the key (e.g. SHA-256 hex, or percent/base32 of the key) under `~/Library/Application Support/Restack/auto/`. Named workspaces (`snapshots/`) and the login "Last Session" snapshot are a separate namespace and untouched.

**Undo baseline** — held in memory on the coordinator: the `Snapshot` captured immediately before an auto-restore overwrote the screen. Single-level; valid until the next config change or app quit.

---

## 5. Behavior / flows

### Startup
On coordinator start (only if the toggle is on): read current displays, set `lastKnownConfigID` as the baseline **without** restoring (so it never fights v1's login "Last Session" restore). Start the autosave scheduler for the current config.

### Periodic autosave (while enabled + stable)
Every tick (~45s target; interval is a constant), `AutosaveScheduler` asks `AutosaveDecider`. If due and not mid-transition: `CaptureEngine.capture` the current layout → `AutoLayoutStore.save` under the current config key. Skipped entirely while the toggle is off.

### Configuration change
1. `DisplayConfigWatcher` sees a screen-parameters change → pushes the new observed config + timestamp to `ConfigChangeDebouncer`.
2. When the set holds steady for the debounce interval (~2s), the debouncer emits `newConfigID`.
3. If `newConfigID == lastKnownConfigID` → ignore (no real change).
4. Else the coordinator:
   a. If `AutoLayoutStore.exists(newConfigID)`: capture the current (scrambled) state as the **Undo baseline**; `RestoreEngine.restore(savedLayout)`; `Notifying.postRestored(configLabel, undo: true)`.
   b. If not: do nothing (first time on this config — autosave will start building it).
   c. Set `lastKnownConfigID = newConfigID`; resume autosave for the new config.

### Undo
`undoLastRestore()` → if a baseline exists, `RestoreEngine.restore(baseline)` and clear it. Triggered by the notification's Undo action or the transient menu fallback.

### Toggle off
Coordinator stops the watcher, scheduler, and clears in-memory state. Zero background work when off.

---

## 6. UX

- **Setting:** a checkbox in the menu — "Auto-restore layout when monitors change" — **off by default**, persisted in `RestackSettings.autoRestoreOnConfigChange`. Toggling on requests notification authorization (`UNUserNotificationCenter`) and starts the coordinator; toggling off stops it.
- **Notification:** on auto-restore, "Restored your layout for this display setup" with an **Undo** action button.
- **Menu fallback:** if notification authorization is denied, show a transient **"Undo last auto-restore"** item in the menu for ~30s after a restore, so Undo is always reachable.

---

## 7. Edge cases & decisions

- **Wake/dock flapping:** debounce (~2s steady) absorbs the burst of connect/disconnect events; only the settled config triggers action.
- **No-op change** (`newConfigID == lastKnownConfigID`): ignored.
- **First time on a configuration:** no restore; autosave begins building that config's layout.
- **Launch baseline:** initial config recorded without restoring, to avoid colliding with login "Last Session" restore.
- **Notifications denied:** feature still works; Undo offered via the transient menu item instead.
- **Undo scope:** single level; baseline invalidated on the next change or on quit.
- **Toggle off:** no watcher, no timer, no notifications — no background cost.
- **Identical-model displays without serials:** inherits v1's stable-ID limitation (documented, not solved here).
- **Restore re-entrancy:** reuses v1's guard; the coordinator serializes so autosave never runs during a restore.

---

## 8. Testing

Pure units (no OS):
- `DisplayConfigID`: order-independence, single vs multi-display, empty.
- `ConfigChangeDebouncer` (fake `Clock`): emits only after steady interval; absorbs flapping; suppresses no-op (same-config) emissions.
- `AutoLayoutStore` (temp dir): save/load/exists/delete per config key; key sanitization round-trips.
- `AutosaveDecider` (fake `Clock`): due after interval; not due early; skipped during transition.

Behavioral (fakes for all adapters + `Notifying` + `Clock`) — `DockRestoreCoordinator`:
- change → config **with** saved layout: restores it, captures an Undo baseline, posts a notification.
- change → config **without** saved layout: no restore, no notification.
- `undoLastRestore()`: re-applies the baseline, then clears it (second undo is a no-op).
- no-op change: nothing happens.
- launch: baseline set, no restore.
- toggle off mid-run: watcher/scheduler stop.

Adapters (`DisplayConfigWatcher`, `AutosaveScheduler`, `UNUserNotificationNotifier`) stay thin and are covered by `swift build` + manual/integration verification (real display reconfiguration can't be unit-tested).

---

## 9. Success criteria

1. With the toggle on: dock into a previously-seen multi-monitor setup → windows return to their remembered positions automatically, and a notification with Undo appears.
2. Undo (notification or menu) restores the pre-restore arrangement.
3. Undock and re-dock repeatedly → each configuration's layout is remembered and restored, kept current by periodic autosave.
4. Toggle off → no windows are ever moved automatically and no background timers run.
5. Flapping displays on wake never trigger a spurious restore.

---

## 10. Risks

- **Autosave capturing a bad transient state.** Mitigation: skip autosave during transitions; debounce; the decider gates on stability.
- **Notification authorization friction.** Mitigation: menu Undo fallback; feature works without notifications.
- **Background cost of periodic AX enumeration.** Mitigation: ~45s throttle, only while enabled and stable; paused during transitions.
- **Config-key instability for serial-less identical displays.** Accepted, inherited from v1.

---

## Appendix
Builds on v1: `docs/superpowers/specs/2026-07-05-restack-design.md`, `docs/superpowers/plans/2026-07-05-restack-v1.md`.
