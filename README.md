<p align="center">
  <img src="docs/branding/icons/v1-layered-omnissa-1024.png" alt="Omnissa Beta Token Utility icon" width="160">
</p>

# Omnissa Beta Token Utility

Get Apple beta enrollment tokens (AppleSeed for IT) and paste them into a
Workspace ONE UEM declarative **Software Update: Settings** profile so supervised
Apple devices can enroll in a beta program.

| Deliverable | Role |
|---|---|
| **macOS app** (SwiftUI) | Click-through workflow (recommended for admins) |
| **Rust CLI** (`omnissa-beta-tokens`) | Scripting / automation |
| **Offline guide** (`omnissa-beta-guide.html`) | Full walkthrough with screenshots |

Version is always read from [`rust/Cargo.toml`](rust/Cargo.toml).

> **Pre-release (0.1.0).** Ad-hoc signed only (Gatekeeper warning on first
> launch). Live Apple Business token fetch is proven; keep validating on-device
> enrollment for your tenant. Full detail: [docs/guide.md](docs/guide.md).

## Install locally (this machine)

From the repo root:

```bash
tools/release.sh          # CLI + guide + SwiftUI .app → dist/release/
# or app only:
tools/make_app.sh
```

Then open:

```bash
open "dist/Omnissa Beta Token Utility.app"
# if Gatekeeper blocks:
xattr -dr com.apple.quarantine "dist/Omnissa Beta Token Utility.app"
```

CLI binary: `dist/release/omnissa-beta-tokens-0.1.0-macos-arm64`  
Guide: `dist/release/omnissa-beta-guide-0.1.0.html`

## How it works

1. **Create a certificate** in the app (or `omnissa-beta-tokens init`).
2. **Apple Business → Devices → Management Services → Add.** Upload the `.pem`,
   download the `.p7m`. Service name: `Workspace One Beta Token Service`
   (copied for you).
3. **Import the `.p7m`** with **Watch Downloads** (app) or `fetch --watch` (CLI).
4. **Fetch programs**, filter by OS, **Copy title** / **Copy token**.
5. **UEM:** one declarative Software Update: Settings profile **per platform**
   (macOS vs iOS). Beta On → Description = title, Token = token → assign → publish.
6. **Clean up** when done: delete the ABM service; app teardown or
   `omnissa-beta-tokens cleanup --yes`.

### What success looks like

| Stage | Success |
|---|---|
| Certificate | **Certificate ready**; drag the `.pem` chip into Apple Business |
| Apple Business | Service created; **Download Service Token** works. Device count on **this** service stays **0** (expected — see below) |
| `.p7m` | App: “Imported …p7m from Downloads” |
| Fetch | **Loaded N beta programs**; pick one for your platform |
| UEM | Profile **Installed** on the device |
| Device | Software Update shows the expected beta |

### Apple Business shows 0 devices — expected

The external management service is **only** for downloading a server token and
calling Apple’s beta API. It is **not** your MDM. Workspace ONE remains the
enrollment server. Apple may list **0 devices** on this service even when UEM
manages many devices. Do **not** reassign devices to it.

### One UEM profile per platform

Filter the app/CLI to **macOS** or **iOS**, then create a matching Apple
platform profile in UEM. A macOS token cannot ride in an iOS declaration.

Modes (Automatic / Offer / Block) are set **in UEM**, not as declaration JSON
from this tool. See the [mode table in the guide](docs/guide.md#54-choose-a-mode-uem-field-guidance-only).

## Quick start (CLI)

```bash
omnissa-beta-tokens init
omnissa-beta-tokens fetch --watch
omnissa-beta-tokens fetch --os macOS --match "27" --uem-block
omnissa-beta-tokens cleanup --yes
```

| Flag | Purpose |
|---|---|
| `fetch --watch` | Wait for a new `.p7m` in `~/Downloads`, copy into workdir |
| `fetch --os` / `--match` | Narrow programs |
| `fetch --uem-block` | Title + token + short “create profile” steps (one match only) |
| `cleanup --yes` | Delete local key/cert/`*.p7m` |

Default workdir: `~/.omnissa-beta-tokens` (700 / key 600).

## Security

- OAuth secrets never printed (`[REDACTED]`).
- Decrypted server token stays in memory only.
- Treat `.p7m` / private key as credentials; never commit them.
- Talks only to `mdmenrollment.apple.com`.

## Known gaps

- Keep validating Software Update UX on supervised Mac/iPhone for your builds.
- Notarization / Developer ID not done yet (Gatekeeper).
- Repo and releases are private.
- Brand/icon review still open.

## Build from source

```bash
# CLI + tests
cd rust && cargo test && cargo build --release

# SwiftUI .app
tools/make_app.sh

# Full release folder
tools/release.sh
```

Release/signing notes: [docs/RELEASING.md](docs/RELEASING.md).  
Admin walkthrough: [docs/guide.md](docs/guide.md) → offline HTML via `build-guide`.

## Branding

Outfit Light/Medium ([SIL OFL 1.1](assets/fonts/OFL.txt)).  
[Brand sheet](docs/branding/brand-template.html) · [Icon variants](docs/branding/logo-d-beta.html)

## License

MIT ([LICENSE](LICENSE)). Improved from `betaTokens.sh` in
[microsoft/shell-intune-samples](https://github.com/microsoft/shell-intune-samples)
(MIT); see [NOTICE](NOTICE).

Apple, Apple Business, and macOS are trademarks of Apple Inc. Workspace ONE and
Omnissa are trademarks of Omnissa. Not affiliated with or endorsed by Apple.
