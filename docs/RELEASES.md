# Releases

BananaBlitz ships through two channels that share the same DMG:

1. **Direct download.** A signed + notarized DMG attached to a GitHub
   Release. Sparkle inside the running app polls
   [`https://adamxbot.github.io/BananaBlitz/appcast.xml`][appcast]
   and offers the update to anyone who installed via that DMG.
2. **Homebrew Cask.** A `Casks/bananablitz.rb` cask in this repo.
   Cask users get updates via `brew upgrade --cask bananablitz`;
   the in-app updater detects the Caskroom path at runtime and steps
   out of their way.

Each release runs through the same pipeline. The whole sequence is
in [`Scripts/release.sh`][release-sh] and
[`.github/workflows/release.yml`][workflow]; this doc covers the
manual setup that has to happen once per machine / org.

[appcast]:    https://adamxbot.github.io/BananaBlitz/appcast.xml
[release-sh]: ../Scripts/release.sh
[workflow]:   ../.github/workflows/release.yml

## One-time setup

### 1. Generate a Sparkle EdDSA keypair

Sparkle signs every appcast entry with an Ed25519 private key. The
matching public key is hard-coded into `Info.plist` so a running app
refuses to apply an update it can't cryptographically tie back to us.

```sh
brew install --cask sparkle
generate_keys              # writes the public half to stdout
```

The first invocation creates a keypair in your default Keychain
under "Sparkle Update Signing"; subsequent invocations print the
existing public key. **Save the public key into**
`BananaBlitz/Info.plist` under `SUPublicEDKey`. (You'll also need to
add `SUFeedURL` pointing at the appcast — see step 3.)

The private half stays out of the repo. For CI:

```sh
generate_keys -x sparkle-private.pem    # exports the private key
base64 < sparkle-private.pem | pbcopy   # paste into the GitHub secret
rm sparkle-private.pem
```

Stash a backup in 1Password (entry name: "Sparkle release-signing
key — BananaBlitz") so a CI rotation doesn't strand you.

### 2. Configure GitHub Actions secrets

| Secret | What it's for |
|---|---|
| `APPLE_DEVELOPER_ID_CERT` | base64 of the `.p12` containing the Developer ID Application cert + private key |
| `APPLE_DEVELOPER_ID_PASSWORD` | passphrase for the `.p12` |
| `APPLE_NOTARY_USER` | Apple ID with notarization access |
| `APPLE_NOTARY_PASSWORD` | app-specific password for that Apple ID |
| `APPLE_NOTARY_TEAM_ID` | the Apple Developer team ID |
| `SPARKLE_PRIVATE_KEY` | base64 EdDSA private key from step 1 |

The workflow's default `GITHUB_TOKEN` (with `permissions: contents:
write`) is enough to publish the DMG and update `gh-pages`; no extra
PAT is needed.

### 3. Bootstrap the gh-pages branch

```sh
git checkout --orphan gh-pages
git rm -rf .
cp docs/appcast-template.xml appcast.xml
git add appcast.xml
git commit -m "Bootstrap appcast"
git push origin gh-pages
git checkout main
```

In Settings → Pages, enable Pages on the `gh-pages` branch root.
The feed will live at `https://adamxbot.github.io/BananaBlitz/appcast.xml`
and Sparkle will fetch it from there.

Once Pages is live, add the URL to `BananaBlitz/Info.plist` under
`SUFeedURL`:

```xml
<key>SUFeedURL</key>
<string>https://adamxbot.github.io/BananaBlitz/appcast.xml</string>
```

`UpdaterService` will then leave its dormant state on next launch
and the in-app "Check for Updates…" command becomes active.

## Cutting a release

```sh
# 1. Bump MARKETING_VERSION and CURRENT_PROJECT_VERSION in
#    project.yml. MARKETING_VERSION is the user-visible semver;
#    CURRENT_PROJECT_VERSION is the integer build number that must
#    monotonically increase across every notarytool submission.
$EDITOR project.yml

# 2. Regenerate the Xcode project so locally everything still builds.
xcodegen generate

# 3. Commit on main, tag, push.
git commit -am "Release 1.1.0"
git tag v1.1.0
git push --follow-tags origin main
```

The push triggers `release.yml`, which:

1. Verifies the tag matches `MARKETING_VERSION` in project.yml
   (catches "I forgot to bump" mid-air).
2. Imports the Developer ID cert into a fresh keychain on the
   runner.
3. Calls `Scripts/release.sh` to archive, sign, notarize, staple,
   DMG, then re-notarize and staple the DMG itself.
4. Calls `Scripts/generate-appcast.sh` against the resulting DMG to
   produce a fresh `appcast.xml` with this version's signed entry.
5. Attaches the DMG to the GitHub Release (auto-generated release
   notes from commits since the previous tag).
6. Pushes the new `appcast.xml` to `gh-pages`.

About 90 seconds after the workflow finishes, every running
BananaBlitz build with auto-updates enabled will see the new
version on its next check (or on next manual "Check for Updates…").

## Updating the Homebrew Cask

The end-user install command is:

```sh
brew install adamxbot/tap/bananablitz
```

That's `<owner>/<short-name>/<cask>`, where Homebrew expands the
short name to `homebrew-tap` and looks for the cask under `Casks/`.
For BananaBlitz the actual repo is therefore
`adamxbot/homebrew-tap`.

### One-time tap setup

```sh
# In a fresh empty repo at github.com/adamxbot/homebrew-tap:
mkdir -p Casks
cp /path/to/BananaBlitz/Casks/bananablitz.rb Casks/
git add Casks/bananablitz.rb
git commit -m "Add bananablitz cask"
git push
```

The shipped [`Casks/bananablitz.rb`][cask] in this repo is the
canonical source — copy it to the tap on every release rather than
editing the tap copy directly, so the in-repo file stays in sync
with what users install.

### Per-release update

After the GitHub Release is live:

1. Compute the new SHA-256: `shasum -a 256 dist/BananaBlitz-X.Y.Z.dmg`
2. Bump `version` and `sha256` in `Casks/bananablitz.rb` (in
   *this* repo).
3. Commit + push.
4. Copy the updated cask file into `adamxbot/homebrew-tap` and
   push there too. Homebrew users pick up the new cask on their
   next `brew update`.

If we ever publish through `homebrew/cask` proper, the same process
applies but the PR goes against `Homebrew/homebrew-cask` instead.

[cask]: ../Casks/bananablitz.rb

## Local dry runs

To verify the build pipeline without publishing:

```sh
# Notarization credentials from Apple ID + app-specific password.
export APPLE_NOTARY_USER=dev@example.com
export APPLE_NOTARY_PASSWORD=abcd-efgh-ijkl-mnop
export APPLE_NOTARY_TEAM_ID=XXXXXXXXXX
./Scripts/release.sh
# DMG ends up at dist/BananaBlitz-<version>.dmg
```

Use Sparkle's [`generate_appcast`][gen] manually to produce a local
appcast.xml that points at a `file://` URL for end-to-end testing
against a development build.

[gen]: https://sparkle-project.org/documentation/publishing/
