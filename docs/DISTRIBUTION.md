# Distribution: Developer ID signing + notarization

Restack ships outside the Mac App Store, so distributable builds need a
**Developer ID Application** signature and Apple **notarization**. This is a
one-time setup per machine/account, then a single command per release.

No separate `.xcodeproj` is required for any of this — `Package.swift` is the
project; open it directly in Xcode (`open Package.swift`) for GUI development,
or just use the scripts below from the CLI.

## One-time setup

### 1. Get a Developer ID Application certificate

Requires an active Apple Developer Program membership.

Easiest path (Xcode):
1. Xcode ▸ Settings ▸ Accounts ▸ select your Apple ID ▸ **Manage Certificates…**
2. Click **+** ▸ **Developer ID Application**
3. Xcode creates the certificate and private key and installs both in your
   login keychain.

Manual path (no Xcode UI): generate a CSR in Keychain Access
(Certificate Assistant ▸ Request a Certificate From a Certificate Authority),
upload it at developer.apple.com ▸ Certificates ▸ **+** ▸ Developer ID
Application, download the resulting `.cer`, and double-click it to install.

### 2. Find your signing identity string

```
security find-identity -v -p codesigning
```

Look for a line like:

```
1) ABCD1234... "Developer ID Application: Jane Doe (TEAMID1234)"
```

The quoted string is the value to pass as `SIGN_IDENTITY`.

### 3. Store notarization credentials once

You need an **app-specific password** (not your Apple ID password):
sign in at https://appleid.apple.com ▸ Sign-In and Security ▸ App-Specific
Passwords ▸ generate one.

Then store credentials in the keychain under a named profile so you never
have to pass Apple ID/team ID/password again:

```
xcrun notarytool store-credentials "restack-notary" \
  --apple-id "you@example.com" \
  --team-id "TEAMID1234" \
  --password "abcd-efgh-ijkl-mnop"
```

This creates a keychain profile named `restack-notary`. `scripts/release.sh`
looks this profile up by name via `NOTARY_PROFILE`.

## Cutting a release

```
SIGN_IDENTITY="Developer ID Application: Jane Doe (TEAMID1234)" \
NOTARY_PROFILE="restack-notary" \
scripts/release.sh
```

This builds `Restack.app` in release configuration, signs it with Hardened
Runtime + a secure timestamp, verifies the signature, submits it to Apple's
notary service and waits for a result, staples the notarization ticket on
success, and cleans up the intermediate zip. The final `Restack.app` in the
repo root is ready to zip/dmg and distribute.

If you only set `SIGN_IDENTITY` (no `NOTARY_PROFILE`), you get a properly
signed but **un-notarized** build — Gatekeeper will still warn on other
Macs until it's notarized.

If neither variable is set, the script degrades to an **ad-hoc** signature
(`codesign --sign -`) and skips notarization entirely — useful for local
testing on the machine that built it, not for sharing.

## Free alternative: a few testers, no notarization

If you just need to get a build onto a handful of testers' Macs without
paying for/setting up notarization, ship the ad-hoc-signed `.app` (plain
`scripts/build-app.sh`, or `scripts/release.sh` with no env vars) and have
each tester do one of:

- Right-click (or Control-click) `Restack.app` ▸ **Open** ▸ confirm in the
  dialog. This bypasses Gatekeeper's quarantine check for that one launch.
- Or strip the quarantine flag directly:
  ```
  xattr -dr com.apple.quarantine Restack.app
  ```

This does not scale past a small trusted group — untrusted downloads (e.g.
from a website) will still be blocked, and there's no malware-scan pass from
Apple. For anything wider, notarize.
