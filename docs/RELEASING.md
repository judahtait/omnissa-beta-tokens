# Releasing

## Version

Read the release version from `rust/Cargo.toml` (`[package] version`). Do not
use a separate non-Rust version string for product assets.

## Build

```bash
cd rust
cargo test
cargo build --release
# or package everything:
tools/release.sh          # Rust CLI + SwiftUI .app zip + guide + SHA256SUMS
```

`tools/make_app.sh` builds the **SwiftUI** shell into
`dist/Omnissa Beta Token Utility.app` (version from `rust/Cargo.toml`).
`SKIP_APP_BUILD=1` reuses an existing `.app`.

Ship:

- `omnissa-beta-tokens-<ver>-macos-arm64` — Rust CLI
- `Omnissa-Beta-Token-Utility-<ver>-macos.zip` — SwiftUI `.app`
- `omnissa-beta-guide-<ver>.html` — offline guide
- `SHA256SUMS`

Requires `cargo` (CLI/guide) and Swift toolchain (app).

## Sign and notarize (needs an Omnissa Developer ID Application certificate)

Ad-hoc or unsigned builds still trigger Gatekeeper. **Notarization (after
Developer ID Application signing) is still required for Gatekeeper-free
first launch** for end users. Signing alone is not enough.

```bash
SIGN_IDENTITY="Developer ID Application: <team>" tools/make_app.sh
ditto -c -k --keepParent "dist/Omnissa Beta Token Utility.app" dist/app.zip
xcrun notarytool submit dist/app.zip --keychain-profile <profile> --wait
xcrun stapler staple "dist/Omnissa Beta Token Utility.app"
SKIP_APP_BUILD=1 tools/release.sh      # re-zip the stapled app and refresh checksums
```

The bundle identifier `com.omnissa.betatokenutility` is a placeholder; confirm it
with the Omnissa app owner before the first signed release.

## Publish

Create a GitHub release and attach the Rust CLI, Rust `.app` zip, guide HTML,
and `SHA256SUMS`:

```bash
gh release create v0.1.0 dist/release/* --title "v0.1.0" --notes-file docs/RELEASE_NOTES.md
```

Attach only files that exist in `dist/release/` and that appear in
`SHA256SUMS`. Do not advertise an arm64 asset that was not built.

Do not commit binaries to git; they belong on the release.

## Before making the repository public

- [ ] Legal review of the license and the upstream attribution in `NOTICE`.
- [ ] Brand approval for the icon, the styling and the use of Omnissa marks.
- [ ] Confirm the copyright holder name in `LICENSE` and `NOTICE`.
- [ ] Confirm the commit author identity you want public (history includes it).
- [ ] No tokens, tenant names or session data in any screenshot.
- [ ] Developer ID signing + notarization complete (or Gatekeeper workaround
      still documented honestly).
