# Homebrew Cask — Omnissa Beta Token Utility
#
# Tap (after this file is on the default branch):
#   brew tap jtait_euc/omnissa-beta-tokens https://github.com/jtait_euc/omnissa-beta-tokens
#   brew install --cask omnissa-beta-token-utility
#
# From a clone (no tap):
#   brew install --cask ./Casks/omnissa-beta-token-utility.rb
#
# Maintainers: bump `version` + `sha256` when cutting a GitHub Release that
# attaches Omnissa-Beta-Token-Utility-<ver>-macos.zip (from tools/release.sh).

cask "omnissa-beta-token-utility" do
  version "0.1.0"
  sha256 :no_check # replace with SHA-256 of the release zip when publishing

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
    Pre-release builds may be ad-hoc signed. If Gatekeeper blocks first launch,
    right-click the app → Open, or:

      xattr -dr com.apple.quarantine "#{appdir}/Omnissa Beta Token Utility.app"

    Apple Business service name (also copied by the app):
      Workspace One AppleSeed Beta Token Service
  EOS
end
