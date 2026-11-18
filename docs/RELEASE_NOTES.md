## Omnissa Beta Token Utility 0.1.0 (pre-release)

Get Apple beta enrollment tokens (AppleSeed for IT) and use them in a Workspace ONE UEM
declarative Software Update: Settings profile.

### Included
- macOS app (SwiftUI), single-file Python script, arm64 command line binary
- Step-by-step guide (`omnissa-beta-guide-0.1.0.html`, works offline)
- `SHA256SUMS`: verify with `shasum -a 256 -c SHA256SUMS`

### Notes
- Builds are not signed or notarized yet. On first launch, right-click the app and choose
  Open, or run `xattr -d com.apple.quarantine "Omnissa Beta Token Utility.app"`.
- Only valid Apple declaration combinations are generated (automatic, offer, offer with no
  sign-in, block and unenroll). The Beta setting needs supervised devices (macOS 15.4+, iOS and
  iPadOS); it is not available on tvOS or visionOS.
- On-device behavior has not been validated end to end yet.
- Derived from `betaTokens.sh` in microsoft/shell-intune-samples (MIT); see NOTICE.
