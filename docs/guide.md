# Enrolling Apple Devices in a Beta Program with Workspace ONE UEM
**Status:** Draft only. Review required by Legal, Compliance, or relevant Omnissa control owner.
**Date:** 2026-11-18
**Author:** Judah Tait (Support Engineering)

---

<!-- Source for the branded HTML guide.
Screenshots must be cropped and redacted (no tokens, tenant names, or session
data) before external use. -->

## 1. Overview

Apple lets organizations enroll managed devices in beta programs (AppleSeed for
IT) using organization-specific beta enrollment tokens. Workspace ONE UEM
delivers the token with a declarative **Software Update: Settings**
configuration (the Beta dictionary).

High-level flow:

1. Create a local key and certificate with Omnissa Beta Token Utility.
2. Register an external device management service in Apple Business and download
   the `.p7m` server token.
3. Fetch the organization's beta programs and copy a token (optionally via
   `--uem-block`).
4. Build a Workspace ONE UEM declarative profile, assign it, and publish.
5. Confirm enrollment on the device (see [On-device validation checklist](#6-on-device-validation-checklist) and [Known gaps](#12-known-gaps)).
6. When finished, delete the Apple Business service and clean up local files
   (see [Finish / cleanup](#9-finish--cleanup)).

## 2. Prerequisites

- Apple Business (or Apple School Manager) administrator access.
- Organization enrolled in [AppleSeed for IT](https://beta.apple.com/for-it)
  (otherwise Apple returns 403 `APPLE_SEED_FOR_IT_TURNED_OFF`).
- Workspace ONE UEM with declarative management for the target OS.
- Supervised devices for UEM-controlled enrollment and unenrollment. On
  unsupervised devices, only offering a program is possible (the user enrolls
  manually). Source: Apple *Enrolling a device in a beta program*.
- A Mac to run the utility (see [Download](#3-download-the-utility)).

## 3. Download the utility

All-Rust product (version from `rust/Cargo.toml`):

| Format | Best for | Needs |
|---|---|---|
| **Rust CLI** (`omnissa-beta-tokens`, macos-arm64) | Command line | Apple Silicon Mac |
| **macOS app** (SwiftUI `.app`) | Click-through workflow | macOS 13 or later |

Get release builds from the repository **Releases** page. The CLI asset is
`omnissa-beta-tokens-<version>-macos-arm64`. Check `SHA256SUMS`, or build with
`cd rust && cargo build --release`. Until builds are signed and notarized, macOS
may block the app on first launch: right-click → **Open**, or run
`xattr -d com.apple.quarantine "Omnissa Beta Token Utility.app"`.

<!-- UTILITY_DOWNLOAD -->

Command-line examples in this guide use `omnissa-beta-tokens` (Rust). The macOS
app is the SwiftUI shell for the same workflow:

```
omnissa-beta-tokens --help
```

## 4. Get the beta tokens

### 4.1 Create the certificate

```
omnissa-beta-tokens init
```

This creates a private key and a certificate (`.pem`) in
`~/.omnissa-beta-tokens` (mode 700 for the folder, 600 for the key). The tool
prints the `.pem` path to upload. In the app, choose **Create certificate**.

Treat the private key and later the `.p7m` as credentials. Do not commit or
share them. When you are finished, delete the management service in Apple
Business and run `omnissa-beta-tokens cleanup --yes` (see
[Finish / cleanup](#9-finish--cleanup)).

### 4.2 Open Management Services in Apple Business

Go straight to the Add page:
https://business.apple.com/main/devices/managementservices/mdmservers/add

Or navigate: sign in to Apple Business → **Devices** → **Management Services**
→ **Add** next to **Device Management Services**.

![Apple Business, Devices > Management Services. Select Add in the Device Management Services row.](images/apple-business-management-services.png)

*Figure 1. Devices > Management Services. Select **Add** (right side of the
Device Management Services row).*

### 4.3 Add the external device management service

1. Enter the service name `Workspace One Beta Token Service`. Apple's form
   cannot be prefilled, so `init` and the app's **Open Apple Business** action
   copy this name to the clipboard. Paste it into **Service Name**.
2. Leave **Allow this service to release devices** unchecked.
3. Select **Upload Certificate** and choose the `.pem` from step 4.1
   (`~/.omnissa-beta-tokens/mdm_public_cert.pem`).
4. Continue (Step 2 of 2), then select **Download Service Token** to get the
   `.p7m`. Service tokens can be redownloaded later if needed.

![Add your external device management service form: Service Name, release devices checkbox, Upload Certificate.](images/apple-business-add-service.png)

*Figure 2. Add your external device management service. Name it, leave the
release checkbox cleared, and upload the `.pem`.*

![The same form filled in: Service Name set to Workspace One Beta Token Service, release checkbox cleared, mdm_public_cert.pem attached.](images/apple-business-form-filled.png)

*Figure 3. The completed form, ready to continue.*

### 4.4 Fetch the beta programs

```
omnissa-beta-tokens fetch --watch
# or: omnissa-beta-tokens fetch --p7m ~/Downloads/something.p7m
```

Useful filters and outputs:

```
omnissa-beta-tokens fetch --os macOS --reveal
omnissa-beta-tokens fetch --match "macOS 27" --format json
omnissa-beta-tokens fetch --os macOS --match "27" --uem-block
```

`--uem-block` requires **exactly one** matched program (narrow with `--os`
and/or `--match`). It prints Title, Token, and a Mode field checklist for the
UEM console — **not** declaration JSON — and copies the block to the clipboard
when `pbcopy` is available.

In the macOS app (same Rust core): choose the `.p7m`, then **Fetch beta tokens**,
pick a program, copy the token, and use the Mode picker as a reminder of which
UEM Beta fields to set.

Security notes:

- OAuth secrets are never printed in full; they appear as `[REDACTED]`.
- The decrypted server token stays in memory only.
- Table output masks beta tokens unless you pass `--reveal` (or use Reveal in
  the app). JSON and CSV output include full tokens because they are for export.
- If `access_token_expiry` on the server token is in the past, the CLI warns you
  to regenerate the `.p7m` in Apple Business.
- If any matched program is tvOS or visionOS, the CLI warns that UEM Software
  Update: Settings > Beta cannot deliver those platforms.

## 5. Create the Workspace ONE UEM profile

### 5.1 Supported devices

The Beta setting is part of the declarative **Software Update: Settings**
configuration. Source: Apple's `softwareupdate.settings` declaration schema.

| Platform | Beta setting | Requirement |
|---|---|---|
| macOS | Supported | macOS 15.4 or later, **supervised** |
| iOS and iPadOS | Supported | Supervised. Version follows the Software Update Settings payload (iOS 18.0 or later per the schema). |
| tvOS, visionOS | Not supported | The schema lists the Beta key as not applicable. The utility may still list tokens for these programs; they cannot be delivered with this setting. |

On unsupervised devices only **Offer programs** can be used (the user enrolls
manually). The organization must also be enrolled in AppleSeed for IT.

### 5.2 Create the profile

1. In UEM: **Resources > Profiles & Baselines > Profiles > Add > Add Profile**.

   ![UEM Add Profile: Select a platform to start (Apple iOS, macOS, tvOS, visionOS).](images/uem-add-profile-platform.png)

   *Figure 4. Choose the platform.*

2. Set **Management Type** = Declarative, **Declaration Type** = Configuration,
   **Context** = Device. Select Next.

   ![UEM Apple iOS profile: Management Type Declarative, Declaration Type Configuration, Context Device.](images/uem-declarative-configuration.png)

   *Figure 5. Declarative, Configuration, Device.*

3. Name the profile (for example `macOS 27 Golden Gate AppleSeed Beta`).
4. Add the **Software Update: Settings** payload and turn on **Beta**.
5. Choose a mode from the table below. Enter the **Description** (program
   title) and **Token** for that OS and program, matching the utility output
   (or paste from `--uem-block`).
6. Select Next, set the assignment (see [Assignment checklist](#5-4-assignment-checklist)), then save and publish.

[Screenshot to add: Software Update: Settings > Beta in Automatic mode
(Program enrollment = AlwaysOn, Require program = on). Redact the token field.
No tenant name or session data.]

### 5.3 Choose a mode (UEM field guidance only)

Apple's schema only allows these combinations. Enter them in the UEM Beta
payload (the app **Mode** picker and `fetch --uem-block` show the matching
field summary). **Do not expect declaration JSON from this tool** — paste title
and token, then set the fields.

| Mode | Program enrollment | Require program | Offer programs | Result |
|---|---|---|---|---|
| Automatic (`auto`) | AlwaysOn | On | Off | The device enrolls in the program automatically. Users cannot enroll using their own Apple Account. |
| Offer to user (`offer`) | Allowed | Off | On | The user can enroll in programs on their Apple Account, plus the offered program. |
| Offer, no sign-in (`offer-always-on`) | AlwaysOn | Off | On | The offered programs are presented for the user to choose. Users cannot use their own Apple Account. |
| Block and unenroll (`off`) | AlwaysOff | Off | Off | The device cannot enroll, and is removed from any beta program it is in. |

Rules from the schema:

- **Require program** is only valid with Program enrollment = **AlwaysOn**.
- **Offer programs** must not be set together with **Require program**.
- **AlwaysOff** carries no program.

Do **not** use Allowed together with Require program. That combination is
invalid under Apple's schema. Use **Automatic** instead.

### 5.4 Assignment checklist

Use this before publishing the profile:

- [ ] **Supervised only** — exclude unsupervised devices from assignment
      (Automatic / Block and unenroll require supervision).
- [ ] **OS floors** — macOS **15.4+**; iOS / iPadOS **18.0+** (per the Software
      Update Settings schema). Exclude older builds from the Smart Group.
- [ ] **Smart Group tips** — prefer an explicit test Smart Group first (named
      devices or a small pilot). Filter on platform, OS version, and
      supervision/enrollment status your tenant exposes. Avoid “all devices”
      until on-device validation passes.
- [ ] **Separate enroll vs. exit profiles** — one profile for the beta mode you
      want (for example Automatic), and a second profile in **Block and
      unenroll** (AlwaysOff) for teardown. Do not rely on simply removing the
      enroll profile if you need devices out of the beta program.
- [ ] **Assignment exclusivity** — devices should not receive conflicting Beta
      modes at once; assign the Block and unenroll profile when exiting, and
      remove or exclude the enroll profile for those devices.
- [ ] **Title and token** match `fetch` / `--uem-block` (no extra whitespace).
- [ ] Publish / activate completed; no draft-only assignment left behind.

## 6. On-device validation checklist

Human E2E scaffold. Items remain unchecked until a supervised test Mac and
iPhone confirm them. Treat section results as assumptions until then.

### Mac (supervised, macOS 15.4+)

- [ ] Profile shows as installed in UEM (**Devices** > device > **Profiles**).
- [ ] Software Update path: **System Settings > General > Software Update**.
- [ ] Expected beta program / build is offered (or Automatic enrollment
      completed without a user Apple Account prompt, if using Automatic).
- [ ] After Block and unenroll assignment: beta offer is gone / device left the
      program.
- [ ] Note UEM status items if visible (`softwareupdate.beta-enrollment`,
      `softwareupdate.pending-version`) — or mark “not surfaced in console”.

### iPhone (supervised, iOS 18+)

- [ ] Profile shows as installed in UEM.
- [ ] Software Update path: **Settings > General > Software Update**.
- [ ] Expected beta program / build is offered (or Automatic enrollment
      behavior matches the chosen mode).
- [ ] After Block and unenroll assignment: device left the program / beta offer
      cleared.
- [ ] Note any user-visible prompts that differ from macOS.

### Cross-checks

- [ ] Token period still valid (re-fetch if the seeding period rolled).
- [ ] Screenshots for the guide (token redacted; no tenant or session data).
- [ ] Record OS builds and UEM console version used for the test.

## 7. Verify on the device (summary)

- In UEM, confirm the profile shows as installed (**Devices** > the device >
  **Profiles**).
- Apple defines status items `softwareupdate.beta-enrollment` and
  `softwareupdate.pending-version`. Whether the UEM console surfaces them:
  data unavailable.
- On the device, open Software Update (iOS and iPadOS: **Settings > General >
  Software Update**; macOS: **System Settings > General > Software Update**)
  and confirm the beta update is offered.

Use the [On-device validation checklist](#6-on-device-validation-checklist) for
the full Mac + iPhone pass. See [Known gaps](#12-known-gaps): on-device menu
paths and enrollment behavior have not been validated end to end yet.

## 8. Unenroll

Assign a profile in **Block and unenroll** mode (Program enrollment =
AlwaysOff) to the device. This removes the device from any beta program.
Supervised devices only. Prefer a dedicated Smart Group / assignment for exit
(see [Assignment checklist](#5-4-assignment-checklist)).

## 9. Finish / cleanup

When you no longer need the Apple Business management service used for token
fetch:

1. Unenroll devices that should leave the beta (section 8), or leave them
   enrolled if that is intentional.
2. In Apple Business, delete the external device management service
   (`Workspace One Beta Token Service` or the name you used).
3. Remove local credentials:

```
omnissa-beta-tokens cleanup --yes
```

`cleanup` deletes `mdm_private.key`, `mdm_public_cert.pem`, and any `*.p7m`
under `--workdir` (default `~/.omnissa-beta-tokens`). It does **not** delete the
Apple Business service — do that in the portal. Without `--yes`, the CLI prompts
on a TTY and refuses on a non-interactive terminal.

## 10. Troubleshooting

| Symptom | Cause | Action |
|---|---|---|
| 403 `APPLE_SEED_FOR_IT_TURNED_OFF` | Org not enrolled in AppleSeed for IT | Enroll at beta.apple.com/for-it |
| Session request fails (401/403) | Server token expired or revoked | Create a new management service and `.p7m` |
| CLI warns about `access_token_expiry` | Server token past expiry | Regenerate `.p7m` in Apple Business |
| Token not accepted | Token expired for its seeding period | Fetch fresh tokens |
| Decrypt failed | `.p7m` does not match uploaded `.pem` | Re-run `init` and re-upload |
| `--uem-block` errors | More than one program matched | Narrow with `--os` and/or `--match` |
| Device not enrolling | Unsupervised device | Offer the program; user enrolls manually |
| Profile does not enroll the device | Invalid combination (for example Allowed with Require program) | Use Automatic: AlwaysOn with Require program |
| tvOS or visionOS device not enrolling | Beta setting not supported on these platforms | Not applicable; see the compatibility table |
| macOS blocks the app on first launch | Build not notarized yet | Right-click → Open, or clear quarantine with `xattr` |

## 11. References

- Apple: [Enrolling a device in a beta program](https://developer.apple.com/documentation/devicemanagement/enrolling-a-device-in-a-beta-program)
- Apple: [Get beta enrollment tokens](https://developer.apple.com/documentation/devicemanagement/get-beta-enrollment-tokens)
- Project README (download formats, security model, known gaps)

## 12. Known gaps

- **On-device behavior** (which devices enroll, and what users see in Software
  Update) has not been validated end to end. The checklist in section 6 is the
  scaffold for that work; steps remain assumptions until a supervised test Mac
  or iPhone confirms them.
- **UEM Beta payload screenshot** for Automatic mode is still a placeholder
  above. Capture with the token redacted before external sharing.
- **Signing and notarization** for the macOS app are not done yet; Gatekeeper
  will warn on first launch until Developer ID signing and notarization land.
- **Private distribution** — the repository and releases are private; there is
  no public download channel yet.
- Builds talk only to `mdmenrollment.apple.com` for token fetch. They need no
  other cloud account.
