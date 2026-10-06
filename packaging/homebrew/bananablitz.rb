# BananaBlitz Homebrew Cask
#
# Canonical source. Copy this file into adamxbot/homebrew-tap on every
# release so end users on `brew install adamxbot/tap/bananablitz` get
# the new version. Per-release updates: bump `version` and `sha256`
# below, then sync.
#
# To compute sha256:
#   shasum -a 256 dist/BananaBlitz-X.Y.Z.dmg

cask "bananablitz" do
  version "0.0.0"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"

  url "https://github.com/adamxbot/BananaBlitz/releases/download/v#{version}/BananaBlitz-#{version}.dmg"
  name "BananaBlitz"
  desc "Periodically clean macOS telemetry caches in ~/Library"
  homepage "https://github.com/adamxbot/BananaBlitz"

  livecheck do
    url :url
    strategy :github_latest
  end

  auto_updates true
  depends_on macos: ">= :sonoma"

  app "BananaBlitz.app"

  # Reverse the Lock-with-Immutable-File operations during uninstall
  # so users don't end up with locked directories after `brew uninstall`.
  uninstall_preflight do
    script_path = "#{staged_path}/BananaBlitz.app/Contents/Resources/unbrick.sh"
    system_command "/bin/bash", args: [script_path], must_succeed: false if File.exist?(script_path)
  end

  zap trash: [
    "~/Library/Application Support/BananaBlitz",
    "~/Library/Preferences/com.bananablitz.app.plist",
    "~/Library/Saved Application State/com.bananablitz.app.savedState",
    "~/Library/Caches/com.bananablitz.app",
  ]
end
