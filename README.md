# omnissa-beta-tokens

Get Apple beta enrollment tokens (AppleSeed for IT) for use in a Workspace ONE
UEM declarative profile. Python 3.9+, no third-party dependencies, uses the
system `openssl`.

An Omnissa-maintained, improved version of the MIT-licensed upstream `betaTokens.sh`. See
`NOTICE` (upstream attribution) and `LICENSE`.

## Quick start

```bash
pip install -e .            # or: PYTHONPATH=src python3 -m omnissa_beta_tokens.cli
omnissa-beta-tokens init    # creates key + cert in ~/.omnissa-beta-tokens
# Apple Business > Devices > Management Services > Add > upload the .pem
# Download the .p7m server token, then:
omnissa-beta-tokens fetch --watch          # or --p7m /path/to/token.p7m
omnissa-beta-tokens fetch --os macOS --reveal
omnissa-beta-tokens fetch --match "macOS 27" --declaration
```

## Security

- OAuth secrets are never printed; they are shown as `[REDACTED]`.
- The decrypted server token is held in memory only (no `token.json` on disk).
- Work directory is mode 700, private key mode 600. `*.p7m`, `*.pem`, `*.key`
  are git-ignored.
- Beta tokens are masked in the table unless you pass `--reveal`. `--format
  json|csv` and `--declaration` always print full tokens because they are
  intended for export.
- Treat the `.p7m` and key as credentials. When finished, delete the
  management service in Apple Business and the local files.

## Notes

- Apple returns `OSX` for macOS; this tool displays `macOS`.
- Requires the organization to be enrolled in AppleSeed for IT
  (https://beta.apple.com/for-it); otherwise Apple returns 403
  `APPLE_SEED_FOR_IT_TURNED_OFF`.
- Tokens are per organization and per seeding period.

## Tests

```bash
PYTHONPATH=src python3 -m unittest discover -s tests -v
```

Tests use fabricated credentials only.

## Build the single-file utility and the branded guide

```bash
python3 tools/bundle.py        # dist/omnissa-beta-tokens.py (one readable file)
pip install markdown           # guide builder only
python3 tools/build_guide.py   # dist/omnissa-beta-guide.html
```

The guide HTML embeds the single-file utility with a Download button, SHA-256
hash and a Copy button, so it works offline and needs no public hosting.
`dist/` is generated and git-ignored.

## Standalone formats

| Format | Build | Output |
|---|---|---|
| Python single file | `python3 tools/bundle.py` | `dist/omnissa-beta-tokens.py` |
| arm64 binary (no Python needed) | see below | `dist/bin/omnissa-beta-tokens` |
| Native SwiftUI app | `tools/make_app.sh` | `dist/Omnissa Beta Token Utility.app` |

Binary (PyInstaller, in a throwaway venv):

```bash
python3 -m venv .venv && .venv/bin/pip install pyinstaller
.venv/bin/python -m PyInstaller --onefile --name omnissa-beta-tokens \
  --distpath dist/bin dist/omnissa-beta-tokens.py
```

SwiftUI app: `swift/` is a Swift package. `BetaTokensCore` holds the logic
(OAuth, server token, Apple client, rendering) and `OmnissaBetaTokensApp` is the
UI. Requires macOS 13+ and the Xcode command line tools.

```bash
cd swift && swift build && swift test     # build and run XCTest suite
tools/make_app.sh                         # release build -> .app, ad-hoc signed
```

### Signing and Gatekeeper

Builds are unsigned or ad-hoc signed. A downloaded copy gets a Gatekeeper
warning until it is signed with an Omnissa Developer ID Application certificate
and notarized:

```bash
SIGN_IDENTITY="Developer ID Application: <team>" tools/make_app.sh
ditto -c -k --keepParent "dist/Omnissa Beta Token Utility.app" dist/app.zip
xcrun notarytool submit dist/app.zip --keychain-profile <profile> --wait
xcrun stapler staple "dist/Omnissa Beta Token Utility.app"
```

Until then, a user can right-click > Open, or run
`xattr -d com.apple.quarantine <path>`. The bundle identifier
(`com.omnissa.betatokenutility`) is a placeholder; confirm with the Omnissa
app owner before shipping.

## Icon

`tools/make_icon.swift` draws the app icon with CoreGraphics (see
`docs/branding/logo-d-beta.html` for the variants). Build the `.icns` with
`tools/make_icns.py` (or `iconutil`), then `tools/make_app.sh` bundles it:

```bash
swiftc -O tools/make_icon.swift -o /tmp/make_icon
/tmp/make_icon iconset v2-key-bow omnissa assets/AppIcon.iconset
python3 tools/make_icns.py assets/AppIcon.iconset assets/AppIcon.icns
```

## Docs

- `docs/guide.md` - Workspace ONE enrollment guide (source for the branded HTML).
