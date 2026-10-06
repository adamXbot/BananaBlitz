cask "bananablitz" do
  # TEMPLATE — rendered by the shared release workflow
  # (privacykey/gh-workflows macos-sparkle-release.yml): @@VERSION@@,
  # @@SHA256@@ and @@URL@@ are substituted per release and the result is
  # pushed to a release branch in adamxbot/homebrew-tap as
  # Casks/bananablitz.rb, with a pull request to merge. Do not hand-edit
  # version/sha256/url here; everything else passes through verbatim.
  version "@@VERSION@@"
  sha256 "@@SHA256@@"

  url "@@URL@@"
  name "BananaBlitz"
  desc "Periodically clean macOS telemetry caches in ~/Library"
  homepage "https://github.com/adamxbot/BananaBlitz"

  # The Sparkle feed is not live yet (SUFeedURL is unset), so track the
  # GitHub Release instead of the appcast.
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
