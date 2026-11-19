# Getting started

## Install

```bash
brew tap judahtait/omnissa-beta-tokens
brew trust judahtait/omnissa-beta-tokens
brew install --cask omnissa-beta-token-utility
```

```bash
npm install -g omnissa-beta-token-utility@0.1.0
```

Or download the signed installer:

```bash
gh release download v0.1.0 -R judahtait/omnissa-beta-tokens \
  -p 'Omnissa-Beta-Token-Utility-*-macos.pkg'
sudo installer -pkg Omnissa-Beta-Token-Utility-0.1.0-macos.pkg -target /
```

## First token

1. **Create certificate** — drag `.pem` into Apple Business.  
2. Service name: `Workspace One AppleSeed Beta Token Service` (copied for you).  
3. Download `.p7m` → app **Watch Downloads**.  
4. **Fetch beta tokens** → filter OS → Copy title / token.

**0 devices** on that Apple Business service is normal. Do not move MDM enrollment there.

## Next

- [Modes & OfferPrograms](Modes-and-OfferPrograms.md) — how to paste into UEM  
- [Admin guide](../guide.md) — screenshots end to end  
