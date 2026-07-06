# Desktop Session/Workspace Manager — Market & Feasibility Teardown

**Date:** 2026-07-05
**Scope:** A desktop manager that saves & restores a professional's full setup — running apps, multi-monitor window positions, and app state (browser tabs, open docs) — after restart, dock/undock, or on demand.

> **Confidence caveat:** Sources below were fetched and quoted directly (vendor pages, OS forums, Indie Hackers, HN). The adversarial cross-verification pass did **not** run (rate-limit failure mid-workflow), so treat quantified figures as *reported, single-source* rather than triple-confirmed. Company facts (Rectangle Pro features, OS gaps) are high-confidence; revenue numbers are illustrative.

---

## 1. Headline finding — your core idea partially ships already

**Rectangle Pro already does most of what you described.** It saves entire workspaces (multiple apps + window layout) and can restore them via shortcut **or automatically when a display is connected/disconnected** — i.e. the exact dock/undock trigger you identified.

> "Save off entire workspaces with multiple [apps]…" — rectangleapp.com/comparison

What it does **not** do: restore *deep app state* — browser tabs, the specific document a window had open, scroll position, editor project. It restores the *window frame* (which app, where, what size), not the *content*.

**That gap — content/state fidelity — is your only real wedge.** Layout-only restore is a solved, commoditized problem on both platforms.

---

## 2. Competitor teardown

| Product | Platform | What it does | Save/restore layouts | Deep app state | Price | Status |
|---|---|---|---|---|---|---|
| **Rectangle (free)** | macOS | Snap/tile via keyboard | No | No | **$0**, open source | Active |
| **Rectangle Pro** | macOS | Snapping + **saved workspaces**, auto-restore on display connect | **Yes** | No | One-time, ~10-day trial, direct download (not MAS) | Active (v3.80, 2026) |
| **Moom** | macOS | Grid layouts, saved arrangements, "save window layout" snapshots | Partial (positions) | No | ~$10 one-time | Active |
| **Stay** (Cordless Dog) | macOS | Remembers window positions per display arrangement; re-applies on dock/undock | **Yes** (positions) | No | ~$15 one-time | Old, minimal marketing |
| **Workspaces** (Apptorium) | macOS | Launches app+file+URL *sets* per project | No (launches, doesn't position) | Partial (opens files/URLs) | ~$10–20 | Active |
| **Magnet** | macOS | Basic snapping | No | No | ~$5 MAS | Active |
| **DisplayFusion** | Windows | Multi-monitor power tool, window position profiles, triggers | **Yes** (positions) | No | ~$30 one-time / Pro | Active, entrenched, dated UI |
| **PowerToys FancyZones + Workspaces** | Windows | Zone layouts (FancyZones) + launch app sets into saved positions (Workspaces module) | **Yes** | Weak | **Free** (Microsoft) | Active |

**Nobody in this set restores browser tabs / open documents as part of the layout.** Two camps exist and neither bridges:
- **Position camp** (Stay, Moom, Rectangle Pro, DisplayFusion): move windows precisely, but can't force an app to reopen its content.
- **Launch camp** (Apptorium Workspaces, PowerToys Workspaces): open the right apps/files, but weak/no precise positioning and no state restore.

---

## 3. OS-native capabilities — real but flaky (this is the opening)

**macOS:**
- Monterey+ **regression**: sleeping a Mac on an external display **scrambles window positions across displays on wake**. Apple Silicon deregisters monitors on sleep → windows pile onto main display, then scatter. Thread: **350 "me too" votes**; top workaround is just "prevent sleep" — Apple ships no layout-restore. (discussions.apple.com/thread/253803495)
- Sequoia (15) added **Window Tiling** — but halves/quarters only, no arbitrary precise placement, on-by-default drag-tiling fires accidentally, poor discoverability. Third-party tools remain more capable. (appleinsider, tidbits)
- Apple has now shipped **three** window systems in 18 years (Spaces '06, Stage Manager '22, Tiling '24) — none fully solved it. Signal: durable unmet need, but also that Apple keeps encroaching.

**Windows 11:**
- Snap Layouts / Snap Groups **do not persist across restart**. Users have asked since **Oct 2021**; still unfixed as of Sept 2023. (techcommunity.microsoft.com)
- PowerToys Workspaces (free, Microsoft) is the closest native-ish answer and will keep improving — pricing floor pressure.

**Takeaway:** The native tools are *unreliable at exactly the dock/undock + restart moments you targeted*. Reliability, not features, is the unmet promise.

---

## 4. Demand signals

- HN: *"Multiple Displays on a Mac Sucks"* — users describe exactly this pain (must reorganize dozens of windows after returning to desk); commenters name paid workarounds. (news.ycombinator.com/item?id=40166268)
- Apple discussions: 350 votes on the wake-scramble thread.
- Windows: multi-year Microsoft forum demand for restart-persistent snap groups.
- Pain is **real, specific, and repeatedly voiced** — the dock/undock and post-restart moments are the emotional peak.

---

## 5. Technical feasibility (the hard part = the moat)

- **Moving other apps' windows on macOS requires the Accessibility API (AXUIElement)** + user-granted permission, and is **blocked under App Sandbox** → **the core feature can't ship on the Mac App Store.** Direct download only (this is why Rectangle Pro is direct-download). (developer.apple.com/forums/thread/125584)
- **You cannot force an arbitrary app to reopen a specific document/tab from the outside.** Deep-state restore needs **per-app integration**: browser extensions (tabs), editor CLIs/URL schemes (VS Code, etc.), app-specific scripting (AppleScript where available). This is bespoke, per-app engineering — which is *why nobody has done it* and why it's defensible if you do.
- Apps launch **asynchronously**; you must launch → wait/poll for the window → then place it. Race conditions here are why existing tools feel janky. **Nailing this sequencing reliably is the actual product.**

---

## 6. Willingness to pay

- A Mac window utility reached **~$1,500/mo**; another category app: **$2,530 month 1 → $193 month 4** — classic flat-rate launch-spike decay. (indiehackers.com)
- Founder lesson: flat one-time freemium = **no recurring income, total dependence on marketing visibility** → favors **subscription or paid-major-upgrade**.
- Mac power users spend **~$400–800/yr** on premium apps individually. (setapp.com) Room exists, but $0 anchors (Rectangle free, PowerToys) mean you must sell clearly *above* layout-snapping.

---

## 7. Gap analysis & recommendation

**The empty space is not "save my window layout." That's taken.** The empty space is:

> **One-click, reliable restore of full working context — right apps, in the right monitor positions, reopened to the right tabs/documents — that survives restart and dock/undock.**

**Positioning:** "Snapshots for your entire workspace." Named setups ("Deep Work", "Trading", "Design Review"), auto-restore on boot and on dock/undock, and — the differentiator — **content restore** via per-app integrations, starting with browser tabs (highest-value, most-requested).

**Platform first: macOS.** Sharper pain (wake-scramble bug), proven WTP, uglier/older incumbents. Accept direct-download distribution (Sandbox rules that out anyway). Windows is bigger and PowerToys is weaker on state — good second act, but Microsoft-free is a brutal anchor.

**Pricing:** Subscription (~$3–5/mo or ~$30–40/yr) or paid annual major upgrades — *not* one-time flat. Free tier = layout-only restore (compete with Rectangle); paid = content/state restore + auto dock/undock profiles.

**Moat = reliability + breadth of per-app state integrations.** The layout math is commodity; the async launch-and-place sequencing done *flawlessly* plus a growing library of app integrations is what nobody has assembled.

**Biggest risks:** (1) Apple/Microsoft continue Sherlocking layout restore (mitigate by living in deep-state, which they won't touch soon); (2) per-app integration is a treadmill (mitigate by starting with browsers, which cover most of the value).

---

## Sources
- rectangleapp.com/comparison (primary — vendor)
- news.ycombinator.com/item?id=40166268 & id=30710764 (forum — demand)
- discussions.apple.com/thread/253803495 (forum — wake-scramble, 350 votes)
- techcommunity.microsoft.com/.../2816144 (forum — Windows snap non-persistence)
- appleinsider.com/.../window-tiling-in-macos-sequoia (secondary — native limits)
- tidbits.com/2024/11/08/how-to-tame-sequoias-window-tiling (secondary)
- developer.apple.com/forums/thread/125584 (primary — AXUIElement / Sandbox constraint)
- indiehackers.com/interview/growing-a-window-management-app-for-mac (blog — revenue)
- setapp.com/app-reviews/setapp-vs-buying-apps-individually (blog — WTP envelope)
