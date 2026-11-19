## Omnissa Beta Token Utility 0.1.0 (pre-release)

Version from `rust/Cargo.toml`. **Prerelease.** Token fetch against a live Apple
Business org has been tested; on-device UEM enrollment, notarization, and public
distribution are not done yet.

Get Apple beta enrollment tokens (AppleSeed for IT) and use them in a Workspace ONE UEM
declarative Software Update: Settings profile.

### Product
- **SwiftUI macOS app** — mid-blue brand, in-app UEM guidance
- Step-by-step guide (`omnissa-beta-guide-0.1.0.html`, works offline)
- Installer / Homebrew cask (see README)
- `SHA256SUMS`: verify with `shasum -a 256 -c SHA256SUMS`

### Notes
- Developer ID signed (`Judah Tait`). Notarization still pending (Apple Developer agreement must be current on the team).
- Enter only valid Apple Beta combinations in UEM (automatic, offer, offer with no
  sign-in, block and unenroll). Mode guidance is for UEM fields only — no declaration
  JSON export. The Beta setting needs supervised devices (macOS 15.4+, iOS and
  iPadOS 18+); it is not available on tvOS or visionOS.
- On-device behavior has not been validated end to end yet.
- Repository and releases are private.
- Derived from `betaTokens.sh` in microsoft/shell-intune-samples (MIT); see NOTICE.
