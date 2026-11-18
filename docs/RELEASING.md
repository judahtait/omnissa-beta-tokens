# Releasing

## Build

```bash
tools/release.sh        # tests, script, guide, binary, app zip, SHA256SUMS -> dist/release/
```

Set `PYI_PYTHON` to a Python that has PyInstaller installed to include the arm64
binary, and `SKIP_APP_BUILD=1` to reuse an existing `dist/*.app`.

## Sign and notarize (needs an Omnissa Developer ID Application certificate)

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

Do not commit binaries to git; they belong on the release.

## Before making the repository public

- [ ] Legal review of the license and the upstream attribution in `NOTICE`.
- [ ] Brand approval for the icon, the styling and the use of Omnissa marks.
- [ ] Confirm the copyright holder name in `LICENSE` and `NOTICE`.
- [ ] Confirm the commit author identity you want public (history includes it).
- [ ] No tokens, tenant names or session data in any screenshot.
