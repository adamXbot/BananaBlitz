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
  depends_on macos: :sonoma

  app "BananaBlitz.app"

  # Reverse the Lock-with-Immutable-File operations during uninstall
  # so users don't end up with locked directories after `brew uninstall`.
  # The app is still in appdir here; it moves back to staged_path later.
  # Homebrew sandboxes these steps: it points HOME at a throwaway dir
  # (so unbrick.sh is re-run with the user's real home via `~user`) and
  # denies writes outside writable_paths, which must list every
  # PrivacyTarget.allTargets path (HomebrewCaskTests fails on drift).
  # Homebrew also runs this on upgrade and reinstall (it can't tell them
  # apart from uninstall), so locks must be re-applied in the app after.
  uninstall_preflight_steps do
    if_path_exists "BananaBlitz.app/Contents/Resources/unbrick.sh", base: :appdir do
      run "/bin/bash",
          args:           [
            "-c", 'HOME=~{{user}} exec /bin/bash "$0"',
            "{{appdir}}/BananaBlitz.app/Contents/Resources/unbrick.sh"
          ],
          must_succeed:   false,
          print_stdout:   true,
          writable_base:  :home,
          writable_paths: [
            "Library/Caches/com.apple.ap.adprivacyd",
            "Library/Caches/com.apple.amsengagementd",
            "Library/Caches/com.apple.AppleMediaServices/Metrics/amsengagementd",
            "Library/Caches/com.apple.CloudTelemetry",
            "Library/Logs/com.apple.CloudTelemetry",
            "Library/Caches/com.apple.feedbacklogger",
            "Library/Caches/com.apple.geoanalyticsd",
            "Library/Caches/com.apple.proactive.eventtracker",
            "Library/Biome",
            "Library/IntelligencePlatform",
            "Library/Application Support/Knowledge",
            "Library/Suggestions",
            "Library/Caches/com.apple.parsecd",
            "Library/Caches/com.apple.duetexpertd",
            "Library/Caches/com.apple.sirittsd",
            "Library/Caches/com.apple.chrono",
            "Library/Application Support/DifferentialPrivacy",
            "Library/Caches/com.apple.sbd",
            "Library/Trial",
            "Library/Daemon Containers",
            "Library/Application Support/com.apple.ScreenTimeAgent",
            "Library/Containers/com.apple.mediaanalysisd/Data/Library/Caches",
            "Library/com.apple.aiml.instrumentation",
            "Library/DuetExpertCenter",
            "Library/Containers/com.apple.Safari/Data/Library/Caches",
            "Library/Keyboard/AutocorrectionRejections.db",
          ]
    end
  end

  zap trash: [
    "~/Library/Application Support/BananaBlitz",
    "~/Library/Preferences/com.bananablitz.app.plist",
    "~/Library/Saved Application State/com.bananablitz.app.savedState",
    "~/Library/Caches/com.bananablitz.app",
  ]
end
