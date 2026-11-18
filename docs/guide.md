# Enrolling Apple Devices in a Beta Program with Workspace ONE UEM
**Status:** Draft only. Review required by Legal, Compliance, or relevant Omnissa control owner.
**Date:** 2026-11-17
**Author:** Judah Tait (Support Engineering)

---

<!-- Source for the branded HTML guide (python3 tools/build_guide.py).
Screenshots are placeholders and must be cropped/redacted (no tokens or tenant
secrets) before use. -->

## 1. Overview

Apple lets organizations enroll managed devices in beta programs (AppleSeed for
IT) using organization-specific beta enrollment tokens. Workspace ONE UEM
delivers the token to devices with a declarative **Software Update: Settings**
configuration (Beta dictionary).

Flow: get tokens from Apple Business -> create a UEM declarative profile ->
assign to devices -> verify on the device.

## 2. Prerequisites

- Apple Business (or Apple School Manager) administrator access.
- The organization enrolled in AppleSeed for IT: https://beta.apple.com/for-it
  (otherwise Apple returns 403 `APPLE_SEED_FOR_IT_TURNED_OFF`).
- Workspace ONE UEM with declarative management support for the target OS.
- A Mac or Linux machine with Python 3.9+ and `openssl` (to run the utility).
- Supervised devices for UEM-controlled enrollment/unenrollment. On
  unsupervised devices only offering a program is possible (user enrolls
  manually). Source: Apple "Enrolling a device in a beta program".

## 3. Download the utility

`omnissa-beta-tokens` is a single Python file with no third-party dependencies.
Download it below, verify the hash, and run it with `python3`. You can read the
full source before running it.

<!-- UTILITY_DOWNLOAD -->

Run it like this (macOS or Linux):

```
python3 omnissa-beta-tokens.py --help
```

## 4. Get the beta tokens

### 4.1 Create the certificate

Run `python3 omnissa-beta-tokens.py init`. It creates a private key and a
certificate (`.pem`) in `~/.omnissa-beta-tokens`. The utility prints the exact
path of the `.pem` to upload.

### 4.2 Open Management Services in Apple Business

Go straight to the Add page:
https://business.apple.com/main/devices/managementservices/mdmservers/add

Or navigate there: sign in to Apple Business, choose **Devices** in the top
bar, select **Management Services** in the left menu, and next to
**Device Management Services** select **Add**.

![Apple Business, Devices > Management Services. Select Add in the Device Management Services row.](images/apple-business-management-services.png)

*Figure 1. Devices > Management Services. Select **Add** (right side of the
Device Management Services row).*

### 4.3 Add the external device management service

1. Enter the service name `Workspace One Beta Token Service`. Apple's form
   cannot be prefilled, so the utility copies this name to your clipboard when
   you run `init` or select **Open Apple Business** in the app. Paste it into
   **Service Name**.
2. Leave **Allow this service to release devices** unchecked.
3. Select **Upload Certificate** and choose the `.pem` file from step 4.1
   (`~/.omnissa-beta-tokens/mdm_public_cert.pem`).
4. Continue (Step 2 of 2), then select **Download Service Token** to get the
   `.p7m`. Service tokens can be redownloaded.

![Add your external device management service form: Service Name, release devices checkbox, Upload Certificate.](images/apple-business-add-service.png)

*Figure 2. Add your external device management service. Name it, leave the
release checkbox cleared, and upload the `.pem`.*

![The same form filled in: Service Name set to Workspace One Beta Token Service, release checkbox cleared, mdm_public_cert.pem attached.](images/apple-business-form-filled.png)

*Figure 3. The completed form, ready to continue.*

### 4.4 Get the beta programs

1. Run `python3 omnissa-beta-tokens.py fetch --watch` (or `--p7m <file>`).
2. Pick the program you need, for example `macOS 27 Golden Gate AppleSeed Beta`.
   Use `--reveal` or `--format json` to get the full token.

If you use the Omnissa Beta Token Utility app, the same steps are on screen:
**Open Apple Business** takes you to the Add page, then choose the `.p7m`.

Security: the `.p7m`, key and tokens are credentials. Do not share or commit
them. When finished, delete the management service in Apple Business.

## 5. Create the Workspace ONE UEM profile

### 5.1 Supported devices

The Beta setting is part of the declarative **Software Update: Settings**
configuration. Source: Apple's `softwareupdate.settings` declaration schema.

| Platform | Beta setting | Requirement |
|---|---|---|
| macOS | Supported | macOS 15.4 or later, **supervised** |
| iOS and iPadOS | Supported | Supervised. Version follows the Software Update Settings payload (iOS 18.0 or later per the schema). |
| tvOS, visionOS | Not supported | The schema lists the Beta key as not applicable. Tokens for these programs are listed by the utility but cannot be delivered with this setting. |

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
5. Choose a mode from the table below, and enter the Description (the program
   title) and the Token for the matching OS and program.
6. Select Next, set the assignment, then save and publish.

[Screenshot to add: the Beta section of the payload for the chosen mode. The
token field must be redacted.]

### 5.3 Choose a mode

Apple's schema only allows these combinations. The utility generates them for
you (app: **Mode**; CLI: `fetch --declaration --mode ...`).

| Mode | Program enrollment | Require program | Offer programs | Result |
|---|---|---|---|---|
| Automatic (`auto`) | AlwaysOn | On | Off | The device enrolls in the program automatically. Users cannot enroll using their own Apple Account. |
| Offer to user (`offer`) | Allowed | Off | On | The user can enroll in programs on their Apple Account, plus the offered program. |
| Offer, no sign-in (`offer-always-on`) | AlwaysOn | Off | On | The offered programs are presented to the user to choose. Users cannot use their own Apple Account. |
| Block and unenroll (`off`) | AlwaysOff | Off | Off | The device cannot enroll, and is removed from any beta program it is in. |

Rules from the schema:

- **Require program** is only valid with Program enrollment = **AlwaysOn**.
- **Offer programs** must not be set together with **Require program**.
- **AlwaysOff** carries no program.

An earlier test profile used Allowed with Require program on. That combination
is not valid under Apple's schema, so do not use it. Use **Automatic** instead.
How a device handles the invalid combination: data unavailable.

## 6. Verify on the device

- In UEM, confirm the profile shows as installed (Devices > the device >
  Profiles).
- Apple defines status items `softwareupdate.beta-enrollment` and
  `softwareupdate.pending-version` that report beta enrollment and the pending
  update. Whether the UEM console shows them: data unavailable.
- On the device, open Software Update (iOS and iPadOS: Settings > General >
  Software Update; macOS: System Settings > General > Software Update) and
  confirm the beta update is offered. **Assumption, not validated on a test
  device:** menu paths and wording can differ by OS version.

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
| Profile does not enroll the device | Invalid combination (for example Allowed with Require program) | Use Automatic mode: AlwaysOn with Require program |
| tvOS or visionOS device not enrolling | Beta setting not supported on these platforms | Not applicable; see the compatibility table |

## 9. References

- Apple: Enrolling a device in a beta program -
  https://developer.apple.com/documentation/devicemanagement/enrolling-a-device-in-a-beta-program
- Apple: Get beta enrollment tokens -
  https://developer.apple.com/documentation/devicemanagement/get-beta-enrollment-tokens
