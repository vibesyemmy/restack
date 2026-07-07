# Restack — Tester Guide

Restack is a menu-bar app that saves your window layout (which apps, where, what size, which monitor) and puts everything back — after a restart, or automatically when you plug your monitor back in.

## Install (2 minutes)

1. Unzip `Restack.zip` and drag `Restack.app` into **Applications** (or anywhere).
2. **Right-click → Open** (don't double-click the first time). macOS will warn that the app is from an unidentified developer — click **Open**. This is a one-time step; the beta build isn't notarized yet.
   - If macOS blocks it entirely, run this in Terminal instead:
     `xattr -dr com.apple.quarantine /Applications/Restack.app`
3. Look for the **stacked-squares icon** in your menu bar.
4. Click it → **Grant Permission…** → turn **Restack ON** in System Settings → Privacy & Security → Accessibility. (Restack needs this to move windows. It never reads window *content*.)

## Try this

1. **Arrange some windows** how you like them → menu → type a name → **Save**.
2. Mess everything up → **Restore**. Windows snap back.
3. Quit an app that was in the layout → **Restore** again. It relaunches and places it.
4. **Multi-monitor users** (the fun part): toggle ON **"Auto-restore when monitors change"** → arrange your docked setup → wait a minute → unplug the monitor → plug it back in. Your layout comes back by itself, with an Undo in the notification.
5. Check **Recent Activity** in the menu — every restore is logged, so you can see exactly what Restack did.

## Known limitations (beta)

- Restores window **positions**, not content — a browser comes back as a window in the right place, not with your tabs (that's coming).
- Windows on other **Spaces** (virtual desktops) aren't handled — current Space only.
- Two identical monitors of the same model may confuse the monitor-matching.
- Restack registers itself as a login item (so restore-after-reboot works).

## Feedback — 3 questions

1. Did a restore ever put a window in the **wrong place**? What app / monitor setup?
2. After a week: are you **still using it**? If you stopped — what made you stop?
3. What's the **one thing** you'd want it to do that it doesn't?

Send thoughts to Opeyemi. Thanks!
