# Restack.app — manual Xcode setup

The files in this directory are the SwiftUI menu-bar app shell (Tasks 14–17 of the
v1 plan). They depend on `MenuBarExtra`, `SMAppService`, and `LSUIElement`, all of
which require an app-bundle context — they cannot be built with `swift build` and are
intentionally **not** referenced from `Package.swift`. `RestackCore` and `RestackKit`
(the SPM package at the repo root) are already built and fully unit-tested; this
directory is source only, waiting to be dropped into an Xcode app target.

## 1. Create the app target

Xcode ▸ File ▸ New ▸ Project ▸ macOS ▸ App.
- Product Name: `Restack`
- Interface: SwiftUI
- Language: Swift
- Save into the repo root, alongside `Package.swift` (so `Restack.xcodeproj` sits next
  to `Package.swift`, `Sources/`, `Tests/`, `App/`).

Xcode will generate its own `RestackApp.swift`, `ContentView.swift`, `Assets.xcassets`,
and `Info.plist`/`Restack.entitlements` inside a generated `Restack/` folder — **delete
the generated `RestackApp.swift` and `ContentView.swift`**, then add the files from this
`App/` directory to the target instead (drag them into the Xcode navigator, checking
"Copy items if needed" off since they already live in the repo, and ensure "Restack"
target membership is checked for each).

## 2. Add the local Swift package dependency

Xcode ▸ File ▸ Add Package Dependencies… ▸ Add Local… ▸ select the repo root
(the folder containing `Package.swift`).

In the `Restack` target's **General** tab, under "Frameworks, Libraries, and Embedded
Content", add both `RestackCore` and `RestackKit`.

## 3. Point the target at this `Info.plist`

In the `Restack` target's **Build Settings**, search for "Info.plist File" and set it
to `App/Info.plist` (or merge the keys below into Xcode's generated one):
- `LSUIElement` = `YES` ("Application is agent (UIElement)" in the Info tab UI) — this
  removes the Dock icon and app switcher entry; the app lives only in the menu bar.
- `NSAccessibilityUsageDescription` — shown in the system Accessibility-permission
  prompt.

## 4. Verify it launches

Build and run. Expected: the app launches with **no Dock icon and no windows**, and a
menu-bar icon (`square.stack.3d.up`) appears. Clicking it opens the Save/Restore
list, gated behind the Accessibility onboarding screen until permission is granted.

## 5. Reset-permission test command

To re-test the onboarding flow (Task 16) after granting permission once, revoke it and
relaunch:

```bash
tccutil reset Accessibility <your.bundle.id>   # e.g. com.yourcompany.Restack
```

Then relaunch `Restack.app`. Expected: the onboarding view reappears; after granting
permission again, the normal Save/Restore menu returns.

## 6. Triggers to verify manually (Task 17)

- **Auto-save on quit:** Quit the app (via the menu's "Quit Restack" or Cmd-Q) →
  a "Last Session" snapshot should appear in the list on next launch.
- **Auto-restore on login:** Log out/reboot → after login, the app should relaunch
  (via the registered `SMAppService` login item) and, ~3 seconds after launch, restore
  either the pinned `RestackSettings.loginTargetID` snapshot or "Last Session" if none
  is pinned.
- If login-launch restore is too aggressive during development, comment out the
  `restoreOnLoginIfNeeded` call in `AppModel.startTriggers()` temporarily.

## Files in this directory

| File | Task | Purpose |
|---|---|---|
| `RestackApp.swift` | 15 | `@main` entry point, `MenuBarExtra` scene |
| `AppModel.swift` | 15, 16, 17 | `@MainActor` model wiring `RestackCore`/`RestackKit`; accessibility trust check; triggers wiring; `saveLastSession(reusing:)` |
| `MenuBarView.swift` | 15, 16 | Save/list/restore/delete UI, gated on Accessibility trust |
| `OnboardingView.swift` | 16 | Accessibility permission prompt |
| `Triggers.swift` | 17 | Login-item registration, auto-save-on-quit, auto-restore-on-login |
| `Settings.swift` | 17 | `RestackSettings.loginTargetID` (pinned login-restore target) |
| `Info.plist` | 14 | `LSUIElement = YES` + Accessibility usage description |
