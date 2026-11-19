<p align="center">
  <img src="docs/branding/icons/v2-key-bow-abm-1024.png" alt="Omnissa Beta Token Utility" width="128">
</p>

# Omnissa Beta Token Utility

**Omnissa** · Workspace ONE UEM

Fetch AppleSeed for IT enrollment tokens, then deliver them with a Workspace ONE
UEM declarative **Software Update: Settings → Beta** profile.

| | |
|---|---|
| **App** | Click-through admin workflow (recommended) |
| **CLI** | `omnissa-beta-tokens` for scripting |
| **Guide** | [docs/guide.md](docs/guide.md) · offline HTML via `build-guide` |
| **Wiki** | [docs/wiki/Home.md](docs/wiki/Home.md) |

Version from [`rust/Cargo.toml`](rust/Cargo.toml). **Pre-release 0.1.0** (ad-hoc
signed; Gatekeeper may warn).

## Install

```bash
tools/release.sh          # app zip + .pkg + CLI + guide → dist/release/
tools/make_pkg.sh         # Installer → /Applications
open dist/release/Omnissa-Beta-Token-Utility-0.1.0-macos.pkg
```

Or app only: `tools/make_app.sh` then open `dist/Omnissa Beta Token Utility.app`.

## How it works

1. **Create certificate** → upload `.pem` to Apple Business Management Services.  
2. **Download `.p7m`** → **Watch Downloads** / `fetch --watch`.  
3. **Fetch programs** → Copy title / token.  
4. **UEM declarative Beta profile** → assign → publish.  
5. **Clean up** ABM token service + local credentials when finished.

Apple Business will show **0 devices** on the token service — that is expected.
Workspace ONE stays the enrollment MDM.

### Modes (aligned with Apple)

| Mode | UEM fields | Programs in one profile |
|---|---|---|
| Automatic | AlwaysOn + Require | **One** (forced) |
| Offer to user | Allowed + Offer | **One or more** (same OS) |
| Offer, no sign-in | AlwaysOn + Offer | **One or more** (same OS) |
| Block and unenroll | AlwaysOff | None |

macOS and iOS always need **separate** profiles. Details:
[guide §4](docs/guide.md#4-choose-a-mode-then-build-the-profile) ·
[wiki: Modes](docs/wiki/Modes-and-OfferPrograms.md).

## CLI

```bash
omnissa-beta-tokens init
omnissa-beta-tokens fetch --watch
omnissa-beta-tokens fetch --os macOS --match "27" --uem-block
omnissa-beta-tokens cleanup --yes
```

## Docs map

| Doc | Audience |
|---|---|
| [docs/guide.md](docs/guide.md) | Admins — short walkthrough + screenshots |
| [docs/wiki/](docs/wiki/Home.md) | Same content, split for GitHub Wiki |
| [docs/RELEASING.md](docs/RELEASING.md) | Engineers building releases |
| In-app **⇧⌘/** | Screenshot UEM steps + mode help |

Apple: [Enrolling a device in a beta program](https://developer.apple.com/documentation/devicemanagement/enrolling-a-device-in-a-beta-program) ·
[Get beta enrollment tokens](https://developer.apple.com/documentation/devicemanagement/get-beta-enrollment-tokens) ·
[Software Update settings](https://support.apple.com/guide/deployment/software-update-settings-declarative-dep0578d8b8a/web)

## Security (short)

Workdir `~/.omnissa-beta-tokens` (700); key/`.p7m` 600, Finder-hidden, Time Machine
excluded. Pasteboard clears tokens after 60s. Still open: Developer ID +
notarization.

## License

MIT. Improved from Microsoft’s `betaTokens.sh` ([NOTICE](NOTICE)).  
Apple and Omnissa / Workspace ONE are trademarks of their respective owners.
