# Homebrew Cask — Omnissa Beta Token Utility (private repo)
#
# Tap over SSH (HTTPS anonymous clone will fail while the repo is private):
#   export HOMEBREW_GITHUB_API_TOKEN="ghp_…"   # repo read + release assets
#   brew tap jtait_euc/omnissa-beta-tokens git@github.com:jtait_euc/omnissa-beta-tokens.git
#   brew install --cask omnissa-beta-token-utility
#
# From a clone:
#   brew install --cask ./Casks/omnissa-beta-token-utility.rb
#
# Maintainers: bump `version` + `sha256` when replacing the release zip.

cask "omnissa-beta-token-utility" do
  version "0.1.0"
  sha256 "d0aaafa867a6cbc336d3685eb7d3051b85e0c758b3f846674b0032167dee4a4f"

  url "https://github.com/jtait_euc/omnissa-beta-tokens/releases/download/v#{version}/Omnissa-Beta-Token-Utility-#{version}-macos.zip"
  name "Omnissa Beta Token Utility"
  desc "Fetch AppleSeed beta enrollment tokens for Workspace ONE UEM"
  homepage "https://github.com/jtait_euc/omnissa-beta-tokens"

  depends_on macos: ">= :ventura"

  app "Omnissa Beta Token Utility.app"

  zap trash: [
    "~/.omnissa-beta-tokens",
  ]

  caveats <<~EOS
    Private repo: set HOMEBREW_GITHUB_API_TOKEN so brew can download the release zip.

    Apple Business service name (also copied by the app):
      Workspace One AppleSeed Beta Token Service
  EOS
end
