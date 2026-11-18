# Enrolling Apple Devices in a Beta Program with Workspace ONE UEM
**Status:** Draft only. Review required by Legal, Compliance, or relevant Omnissa control owner.
**Date:** 2026-11-18
**Author:** Judah Tait (Support Engineering)

---

<!-- Source for the branded HTML guide (python3 tools/build_guide.py).
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
3. Fetch the organization's beta programs and copy a token.
4. Build a Workspace ONE UEM declarative profile and assign it to supervised
   devices.
5. Confirm enrollment on the device (see [Known gaps](#10-known-gaps)).

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

The same logic ships three ways. Pick one:

| Format | Best for | Needs |
|---|---|---|
| **macOS app** | Click-through workflow | macOS 13 or later |
| **Single-file script** (`omnissa-beta-tokens.py`) | Reading the code before you run it | Python 3.9+ and system `openssl` |
| **arm64 binary** | CLI without Python | Apple Silicon Mac |

Get release builds from the repository **Releases** page (or use the embedded
script below when you are reading this guide offline). Until builds are signed
and notarized, macOS may block the app on first launch: right-click → **Open**,
or run `xattr -d com.apple.quarantine "Omnissa Beta Token Utility.app"`.

<!-- UTILITY_DOWNLOAD -->

Command-line examples in this guide use the script form. Substitute
`omnissa-beta-tokens` if you installed the binary, or use the matching controls
in the app.

```
python3 omnissa-beta-tokens.py --help
```

## 4. Get the beta tokens

### 4.1 Create the certificate

```
python3 omnissa-beta-tokens.py init
```

This creates a private key and a certificate (`.pem`) in
`~/.omnissa-beta-tokens` (mode 700 for the folder, 600 for the key). The tool
prints the `.pem` path to upload. In the app, choose **Create certificate**.

Treat the private key and later the `.p7m` as credentials. Do not commit or
share them. When you are finished, delete the management service in Apple
Business and remove the local files.

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
python3 omnissa-beta-tokens.py fetch --watch
# or: python3 omnissa-beta-tokens.py fetch --p7m ~/Downloads/something.p7m
```

Useful filters and outputs:

```
python3 omnissa-beta-tokens.py fetch --os macOS --reveal
python3 omnissa-beta-tokens.py fetch --match "macOS 27" --format json
```

In the app: choose the `.p7m`, then **Fetch beta tokens**, pick a program, copy
the token, and use the Mode picker as a reminder of which UEM Beta fields to set.

Security notes:

- OAuth secrets are never printed in full; they appear as `[REDACTED]`.
- The decrypted server token stays in memory only.
- Table output masks beta tokens unless you pass `--reveal` (or use Reveal in
  the app). JSON and CSV output include full tokens because they are for export.

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
   title) and **Token** for that OS and program, matching the utility output.
6. Select Next, set the assignment, then save and publish.

[Screenshot to add: Software Update: Settings > Beta in Automatic mode
(Program enrollment = AlwaysOn, Require program = on). Redact the token field.
No tenant name or session data.]

### 5.3 Choose a mode

Apple's schema only allows these combinations. Enter them in the UEM Beta
payload (the app **Mode** picker shows the matching field summary).

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

## 6. Verify on the device

- In UEM, confirm the profile shows as installed (**Devices** > the device >
  **Profiles**).
- Apple defines status items `softwareupdate.beta-enrollment` and
  `softwareupdate.pending-version`. Whether the UEM console surfaces them:
  data unavailable.
- On the device, open Software Update (iOS and iPadOS: **Settings > General >
  Software Update**; macOS: **System Settings > General > Software Update**)
  and confirm the beta update is offered.

See [Known gaps](#10-known-gaps): on-device menu paths and enrollment behavior
have not been validated end to end on a supervised test device yet.

## 7. Unenroll

Assign a profile in **Block and unenroll** mode (Program enrollment =
AlwaysOff) to the device. This removes the device from any beta program.
Supervised devices only.

## 8. Troubleshooting

| Symptom | Cause | Action |
|---|---|---|
| 403 `APPLE_SEED_FOR_IT_TURNED_OFF` | Org not enrolled in AppleSeed for IT | Enroll at beta.apple.com/for-it |
| Session request fails (401/403) | Server token expired or revoked | Create a new management service and `.p7m` |
| Token not accepted | Token expired for its seeding period | Fetch fresh tokens |
| Decrypt failed | `.p7m` does not match uploaded `.pem` | Re-run `init` and re-upload |
| Device not enrolling | Unsupervised device | Offer the program; user enrolls manually |
| Profile does not enroll the device | Invalid combination (for example Allowed with Require program) | Use Automatic: AlwaysOn with Require program |
| tvOS or visionOS device not enrolling | Beta setting not supported on these platforms | Not applicable; see the compatibility table |
| macOS blocks the app on first launch | Build not notarized yet | Right-click → Open, or clear quarantine with `xattr` |

## 9. References

- Apple: [Enrolling a device in a beta program](https://developer.apple.com/documentation/devicemanagement/enrolling-a-device-in-a-beta-program)
- Apple: [Get beta enrollment tokens](https://developer.apple.com/documentation/devicemanagement/get-beta-enrollment-tokens)
- Project README (download formats, security model, known gaps)

## 10. Known gaps

- **On-device behavior** (which devices enroll, and what users see in Software
  Update) has not been validated end to end. Steps in section 6 are assumptions
  until a supervised test Mac or iPhone confirms them.
- **UEM Beta payload screenshot** for Automatic mode is still a placeholder
  above. Capture with the token redacted before external sharing.
- **Signing and notarization** for the macOS app are not done yet; Gatekeeper
  will warn on first launch.
- Builds talk only to `mdmenrollment.apple.com` for token fetch. They need no
  other cloud account.
