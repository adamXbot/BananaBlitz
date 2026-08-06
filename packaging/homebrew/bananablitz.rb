# BananaBlitz Homebrew Cask — TEMPLATE
#
# Canonical source. The release pipeline (privacykey/gh-workflows'
# macos-sparkle-release.yml cask step) substitutes the @@VERSION@@,
# @@SHA256@@, and @@URL@@ placeholders and pushes the rendered cask to
# adamxbot/homebrew-tap on every release, so end users on
# `brew install adamxbot/tap/bananablitz` get the new version. Do not
# hand-edit version/sha256/url here — everything else passes through
# to the tap verbatim.

cask "bananablitz" do
  version "@@VERSION@@"
  sha256 "@@SHA256@@"

  url "@@URL@@"
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
