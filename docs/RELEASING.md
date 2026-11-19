# Releasing

## Version

Use **Semantic Versioning** (`MAJOR.MINOR.PATCH`), e.g. `0.1.0`.

**Source of truth:** `rust/Cargo.toml` → `[package] version`.

When cutting a release, set the **same** version (no `v` prefix, no `-stage` /
prerelease labels) in:

1. `rust/Cargo.toml`
2. `package.json`
3. `Casks/omnissa-beta-token-utility.rb` (+ `sha256` of the new zip)

Then tag GitHub as `v<version>` (leading `v` on the **tag only**). Artifact
filenames use the bare version: `Omnissa-Beta-Token-Utility-0.1.0-macos.zip`.

Ignore npm’s temporary `0.0.0-stage` placeholder if it appears while a new
package name is processing — product installs must pin `@0.1.0` or later.

## Build

```bash
cd rust
cargo test
cargo build --release
# or package everything:
tools/release.sh          # Rust CLI + SwiftUI .app zip + .pkg + guide + SHA256SUMS
```

`tools/make_app.sh` builds the **SwiftUI** shell into
`dist/Omnissa Beta Token Utility.app` (version from `rust/Cargo.toml`).
`SKIP_APP_BUILD=1` reuses an existing `.app`.
`tools/make_pkg.sh` wraps that `.app` in an Installer package that installs to
`/Applications` (`INSTALLER_IDENTITY` for Developer ID Installer when available).

Ship:

- `omnissa-beta-tokens-<ver>-macos-arm64` — Rust CLI
- `Omnissa-Beta-Token-Utility-<ver>-macos.zip` — SwiftUI `.app`
- `Omnissa-Beta-Token-Utility-<ver>-macos.pkg` — Installer → `/Applications`
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
