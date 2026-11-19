# Getting started

## Install (private repo)

```bash
export HOMEBREW_GITHUB_API_TOKEN="ghp_…"   # repo + release read
brew untap jtait_euc/omnissa-beta-tokens 2>/dev/null || true
brew tap jtait_euc/omnissa-beta-tokens git@github.com:jtait_euc/omnissa-beta-tokens.git
brew install --cask omnissa-beta-token-utility
```

Or download the signed installer:

```bash
gh release download v0.1.0 -R jtait_euc/omnissa-beta-tokens \
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
