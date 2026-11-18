## Omnissa Beta Token Utility 0.1.0 (pre-release)

Version from `rust/Cargo.toml`. **Prerelease.** Token fetch against a live Apple
Business org has been tested; on-device UEM enrollment, notarization, and public
distribution are not done yet.

Get Apple beta enrollment tokens (AppleSeed for IT) and use them in a Workspace ONE UEM
declarative Software Update: Settings profile.

### Product (all Rust)
- **Rust CLI** — `omnissa-beta-tokens-0.1.0-macos-arm64` (`cargo build --release` in `rust/`)
- **Rust macOS app** — egui `.app` zip (same Rust core as the CLI)
- Step-by-step guide (`omnissa-beta-guide-0.1.0.html`, works offline)
- `SHA256SUMS`: verify with `shasum -a 256 -c SHA256SUMS`

Use `omnissa-beta-tokens init|fetch|cleanup` (including `fetch --uem-block` for
UEM field paste guidance — **not** declaration JSON).

### Notes
- Builds are not signed or notarized yet. On first launch, right-click the app and choose
  Open, or run `xattr -d com.apple.quarantine "Omnissa Beta Token Utility.app"`.
- Enter only valid Apple Beta combinations in UEM (automatic, offer, offer with no
  sign-in, block and unenroll). Mode guidance is for UEM fields only — no declaration
  JSON export. The Beta setting needs supervised devices (macOS 15.4+, iOS and
  iPadOS 18+); it is not available on tvOS or visionOS.
- On-device behavior has not been validated end to end yet.
- Repository and releases are private.
- Derived from `betaTokens.sh` in microsoft/shell-intune-samples (MIT); see NOTICE.
