# Homebrew Cask — Omnissa Beta Token Utility
#
#   brew tap judahtait/omnissa-beta-tokens
#   brew trust judahtait/omnissa-beta-tokens
#   brew install --cask omnissa-beta-token-utility
#
# Maintainers: bump `version` + `sha256` when replacing the release zip.

cask "omnissa-beta-token-utility" do
  version "1.0.0"
  sha256 "18d4f1a7c908ad6c18c24ef54f2f18e83341588628b493a23b3b5eb9fdbaa46b"

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
