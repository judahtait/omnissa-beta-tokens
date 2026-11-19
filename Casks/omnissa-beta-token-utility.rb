# Homebrew Cask — Omnissa Beta Token Utility
#
#   brew tap judahtait/omnissa-beta-tokens
#   brew install --cask omnissa-beta-token-utility
#
# From a clone:
#   brew install --cask ./Casks/omnissa-beta-token-utility.rb
#
# Maintainers: bump `version` + `sha256` when replacing the release zip.

cask "omnissa-beta-token-utility" do
  version "0.1.0"
  sha256 "6306dd907a99424009e8e4bf18a077ecb62ad429fe8b88d67025e6806dd517d1"

  url "https://github.com/judahtait/omnissa-beta-tokens/releases/download/v#{version}/Omnissa-Beta-Token-Utility-#{version}-macos.zip"
  name "Omnissa Beta Token Utility"
  desc "Fetch AppleSeed beta enrollment tokens for Workspace ONE UEM"
  homepage "https://github.com/judahtait/omnissa-beta-tokens"

  depends_on macos: :ventura

  app "Omnissa Beta Token Utility.app"

  zap trash: [
    "~/.omnissa-beta-tokens",
  ]

  caveats <<~EOS
    Apple Business service name (also copied by the app):
      Workspace One AppleSeed Beta Token Service
  EOS
end
