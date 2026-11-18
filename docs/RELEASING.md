# Releasing

## Build

```bash
tools/release.sh        # Rust CLI, legacy .py, guide, app zip, SHA256SUMS -> dist/release/
```

Requires a Rust toolchain (`cargo`). The primary CLI is built with
`cargo build --release` in `rust/` and shipped as
`omnissa-beta-tokens-<ver>-macos-arm64`. A cargo failure fails the release.

Optional: `SKIP_PY_TESTS=1` to skip Python unit tests; `SKIP_APP_BUILD=1` to
reuse an existing `dist/*.app`. The single-file `.py` remains a legacy/secondary
artifact via `tools/bundle.py`.

## Sign and notarize (needs an Omnissa Developer ID Application certificate)

Ad-hoc or unsigned builds still trigger Gatekeeper. **Notarization (after
Developer ID Application signing) is still required for Gatekeeper-free
first launch** for end users. Signing alone is not enough.

The primary CLI binary (`omnissa-beta-tokens-<ver>-macos-arm64`) is produced by
`cargo build --release` in `rust/` (required for `tools/release.sh`). It is not
a PyInstaller/`PYI_PYTHON` artifact. **v0.1.0** includes that binary; always
verify against `SHA256SUMS` on the release.

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

Create a GitHub release and attach everything in `dist/release/`:

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
