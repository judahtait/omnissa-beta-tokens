<p align="center">
  <img src="docs/branding/icons/v1-layered-omnissa-1024.png" alt="Omnissa Beta Token Utility icon" width="160">
</p>

# Omnissa Beta Token Utility

Get Apple beta enrollment tokens (AppleSeed for IT) and use them in a
Workspace ONE UEM declarative **Software Update: Settings** profile, so managed
Apple devices can enroll in a beta program.

It ships three ways, all with the same logic:

| Format | For | Needs |
|---|---|---|
| **macOS app** (SwiftUI) | Admins who want a window | macOS 13 or later |
| **Single-file script** (`omnissa-beta-tokens.py`) | Admins who want to read the code before running it | Python 3.9+ and the system `openssl` |
| **arm64 binary** | Command line without Python | Apple Silicon Mac |

> **Status: pre-release (0.1.0).** Builds are not yet signed or notarized by
> Omnissa, so macOS shows a Gatekeeper warning on first launch (see below). The
> beta token retrieval has been tested against a live Apple Business
> organization. How devices behave after receiving the profile is still being
> validated; see [Known gaps](#known-gaps).

## Download

Get the latest files from the **Releases** page of this repository:

- `Omnissa-Beta-Token-Utility-<version>-macos.zip`: the app
- `omnissa-beta-tokens-<version>-arm64`: the command line binary
- `omnissa-beta-tokens-<version>.py`: the single-file script
- `omnissa-beta-guide-<version>.html`: the step-by-step guide (works offline)
- `SHA256SUMS`: checksums for all of the above

Verify what you downloaded:

```bash
shasum -a 256 -c SHA256SUMS
```

### First launch on macOS

Until the app is signed and notarized, macOS blocks it the first time. Either
right-click the app and choose **Open**, or remove the quarantine flag:

```bash
xattr -d com.apple.quarantine "Omnissa Beta Token Utility.app"
```

## How it works

1. **Create a certificate.** The tool generates a key and a self-signed
   certificate (`.pem`) on your Mac.
2. **Add an external device management service in Apple Business.** Upload the
   `.pem` and download the `.p7m` server token. Use the service name
   `Workspace One Beta Token Service`; the app and CLI copy it to your clipboard.
3. **Fetch the beta programs.** The tool decrypts the server token locally,
   signs a request to Apple's `mdmenrollment.apple.com` service, and lists the
   programs (`GET /os-beta-enrollment/tokens`).
4. **Use a token in Workspace ONE UEM.** Pick a program and a mode, then enter the
   values in the Software Update: Settings > Beta payload (or copy the reference
   declaration).

The full walkthrough, with screenshots, is in [docs/guide.md](docs/guide.md).

## Quick start

**App:** open it, choose **Create certificate**, upload the `.pem` in Apple
Business, choose the downloaded `.p7m`, then **Fetch beta tokens**.

**Command line:**

```bash
omnissa-beta-tokens init                      # key + certificate in ~/.omnissa-beta-tokens
omnissa-beta-tokens fetch --watch             # waits for the .p7m in ~/Downloads
omnissa-beta-tokens fetch --p7m token.p7m --os macOS --reveal
omnissa-beta-tokens fetch --match "macOS 27" --declaration --mode auto
```

Use `python3 omnissa-beta-tokens.py ...` instead if you downloaded the script.

## Modes

Apple's `softwareupdate.settings` schema allows only these combinations, and the
tool only produces them:

| Mode | Program enrollment | Require program | Offer programs |
|---|---|---|---|
| `auto` (automatic enrollment) | AlwaysOn | On | Off |
| `offer` (user chooses) | Allowed | Off | On |
| `offer-always-on` | AlwaysOn | Off | On |
| `off` (block and unenroll) | AlwaysOff | Off | Off |

The Beta setting needs **supervised** devices: macOS 15.4 or later, and iOS or
iPadOS (the schema lists the Software Update Settings payload from iOS 18.0).
It is not available on tvOS or visionOS. The organization must be enrolled in
[AppleSeed for IT](https://beta.apple.com/for-it); otherwise Apple returns 403
`APPLE_SEED_FOR_IT_TURNED_OFF`. Tokens are per organization and per seeding
period.

## Security

- OAuth secrets are never printed or logged; they appear as `[REDACTED]`.
- The decrypted server token is kept in memory only. No plaintext copy is written.
- The work folder is mode 700 and the private key mode 600.
- Beta tokens are masked on screen unless you choose to reveal them. JSON, CSV
  and declaration output include full tokens because they are for export.
- Treat the `.p7m` and the private key as credentials. When you are finished,
  delete the management service in Apple Business and the local files.
- `*.p7m`, `*.pem` and `*.key` are git-ignored. Never commit them.

The tool talks only to `mdmenrollment.apple.com`. It needs no account on
anything else and sends nothing elsewhere.

## Known gaps

- On-device behavior (which devices enroll, and what users see in Software
  Update) has not been validated end to end yet; the guide marks those steps as
  assumptions.
- No Developer ID signing or notarization yet.
- The app icon and styling have not been through an Omnissa brand review.

## Build from source

```bash
# Python: tests, single-file script, guide
PYTHONPATH=src python3 -m unittest discover -s tests -v
python3 tools/bundle.py                 # dist/omnissa-beta-tokens.py
pip install markdown && python3 tools/build_guide.py   # dist/omnissa-beta-guide.html

# Swift app (needs the Xcode command line tools)
cd swift && swift build && swift test   # Swift Testing; no full Xcode required
cd .. && tools/make_app.sh              # dist/Omnissa Beta Token Utility.app, ad-hoc signed

# Rust CLI (experimental; mirrors the Python/Swift core)
cd rust && cargo test && cargo build --release
# binary: rust/target/release/omnissa-beta-tokens

# Everything, with checksums, into dist/release/
tools/release.sh
```

`swift/BetaTokensCore` holds the logic (OAuth, server token, Apple client,
declaration rendering) and `swift/Sources/OmnissaBetaTokensApp` is the UI. The
Rust crate under `rust/` is an experimental CLI port of that same core; Python
remains the primary script distribution. Tests use fabricated credentials only.
For a signed build, set `SIGN_IDENTITY` and notarize as described in
[docs/RELEASING.md](docs/RELEASING.md).

## Branding

Fonts: Outfit Light and Medium, bundled under the
[SIL Open Font License 1.1](assets/fonts/OFL.txt). Colors, the Omnissa gradient
and components: [docs/branding/brand-template.html](docs/branding/brand-template.html).
Icon variants: [docs/branding/logo-d-beta.html](docs/branding/logo-d-beta.html).
Regenerate the icon with `tools/make_icon.swift` and `tools/make_icns.py`.

## License and attribution

MIT, see [LICENSE](LICENSE). This project is an improved, Omnissa-maintained
version of `betaTokens.sh` from
[microsoft/shell-intune-samples](https://github.com/microsoft/shell-intune-samples)
(MIT). The upstream notice is retained in [NOTICE](NOTICE).

Apple, Apple Business, and macOS are trademarks of Apple Inc. Workspace ONE and
Omnissa are trademarks of Omnissa. This project is not affiliated with or
endorsed by Apple.
