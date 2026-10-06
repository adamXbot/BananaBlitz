# Releases

BananaBlitz ships through two channels that share the same DMG:

1. **Direct download.** A Developer ID signed and notarised DMG attached to
   a GitHub Release. Sparkle inside the running app polls
   [`https://adamxbot.github.io/BananaBlitz/appcast.xml`][appcast] and
   offers the update to anyone who installed via that DMG, once `SUFeedURL`
   and `SUPublicEDKey` are set in `Info.plist` (they are not yet; see
   [Turning Sparkle on](#turning-sparkle-on)).
2. **Homebrew Cask.** `brew install adamxbot/tap/bananablitz`, served from
   [`adamxbot/homebrew-tap`][tap]. Each release renders the template in
   [`packaging/homebrew/bananablitz.rb`][cask] and opens a pull request
   against the tap; merging that PR is what makes
   `brew upgrade --cask bananablitz` see the new version. The in-app
   updater detects a Caskroom install at runtime and steps out of the way.

[appcast]: https://adamxbot.github.io/BananaBlitz/appcast.xml
[tap]:     https://github.com/adamxbot/homebrew-tap
[cask]:    ../packaging/homebrew/bananablitz.rb

## How a release is built

[`.github/workflows/release.yml`][workflow] is a thin caller of the shared
`macos-sparkle-release.yml` pipeline in [`privacykey/gh-workflows`][shared],
pinned to an exact commit (the same one [`ci.yml`][ci] uses for the
push/PR tests). The pipeline lives there; this repo owns the three things
it reads:

| Owned here | Role |
|---|---|
| [`Config/Shared.xcconfig`][xcconfig] | `MARKETING_VERSION`, which the pushed tag must match |
| [`Scripts/release.sh`][release-sh] | archive → export → notarise → staple → DMG → notarise DMG → staple, plus the dSYM zip |
| [`packaging/homebrew/bananablitz.rb`][cask] | the cask template; `@@VERSION@@`, `@@SHA256@@` and `@@URL@@` are substituted per release |

On a `v*` tag push the shared pipeline runs two jobs:

1. **`test`, no secrets.** Checks out the tag, generates the project with
   XcodeGen, runs the unit tests and an unsigned Release build. A failure
   here stops the run before any signing secret is read.
2. **`release`, in the `macos-signing` environment.** Confirms the checkout
   is the requested tag and that the tag matches `MARKETING_VERSION`,
   imports the Developer ID certificate into an ephemeral keychain, stages
   the App Store Connect API key, then runs `Scripts/release.sh`.

`Scripts/release.sh` runs the project publication gates before it compiles
anything: a clean checkout, an annotated `v<version>` tag at HEAD, and the
required CI checks (`identity`, `Command contract`, `Native app compile`)
green at that commit. It records the build identity of the archive, the
exported app and the DMG, and verifies each against the `release` channel:
built from tagged clean source, with no repository details in the binary.
The gates and the identity format are described in
[`BUILD-PROVENANCE.md`](BUILD-PROVENANCE.md) and
[`PROJECT-COMMANDS.md`](PROJECT-COMMANDS.md).

After the script returns, the pipeline generates `appcast.xml` with its
pinned Sparkle CLI, writes a `.sha256` sidecar next to the DMG, verifies
the DMG's package record once more, attaches the DMG, the sidecar and the
dSYM zip to the GitHub Release (with auto-generated notes), pushes
`appcast.xml` to the `gh-pages` branch, and opens the cask PR in the tap
when `HOMEBREW_TAP_TOKEN` is configured. Without that token the cask step
skips and everything else still publishes.

To re-run a release for a tag that already exists, use Actions → Release →
*Run workflow* and set `release_tag`. The pipeline checks out that tag and
refuses to sign if the checkout does not match it.

[workflow]:   ../.github/workflows/release.yml
[ci]:         ../.github/workflows/ci.yml
[shared]:     https://github.com/privacykey/gh-workflows
[xcconfig]:   ../Config/Shared.xcconfig
[release-sh]: ../Scripts/release.sh

## One-time setup

### 1. Generate a Sparkle EdDSA keypair

Sparkle signs every appcast entry with an Ed25519 private key. The
matching public key is hard-coded into `Info.plist` so a running app
refuses to apply an update it can't cryptographically tie back to us.

```sh
brew install --cask sparkle
generate_keys              # writes the public half to stdout
```

The first invocation creates a keypair in your default Keychain under
"Sparkle Update Signing"; subsequent invocations print the existing public
key. Save the public key for `SUPublicEDKey` (see
[Turning Sparkle on](#turning-sparkle-on)).

The private half stays out of the repo. For CI:

```sh
generate_keys -x sparkle-private.pem    # exports the private key, already base64
pbcopy < sparkle-private.pem            # paste into the SPARKLE_PRIVATE_KEY secret as-is
rm sparkle-private.pem
```

Store the exported text **exactly as written**. It is already base64; piping
it through `base64` again double-encodes it, and the pipeline rejects a key
that does not decode to 32 or 96 bytes. Keep a backup in 1Password (entry:
"Sparkle release-signing key — BananaBlitz") so a CI rotation doesn't strand
you.

### 2. Configure GitHub Actions secrets

The shared pipeline reads these names. None exist in this repository yet;
`gh secret list` shows what is configured.

| Secret | What it holds |
|---|---|
| `APPLE_CERTIFICATE` | base64 of the `.p12` containing the Developer ID Application cert + private key |
| `APPLE_CERTIFICATE_PASSWORD` | passphrase for that `.p12` |
| `APPLE_SIGNING_IDENTITY` | the exact common name, e.g. `Developer ID Application: Name (6S9Q286XS9)` |
| `APPLE_API_KEY` | full PEM contents of the App Store Connect API `.p8` (notarisation) |
| `APPLE_API_KEY_ID` | the 10-character Key ID |
| `APPLE_API_ISSUER` | the Issuer UUID |
| `SPARKLE_PRIVATE_KEY` | the `generate_keys -x` output from step 1, as-is |
| `HOMEBREW_TAP_TOKEN` | optional: a fine-grained PAT scoped to `adamxbot/homebrew-tap` only, with Contents and Pull requests read & write |

Put the `APPLE_*` secrets on the repository. Put `SPARKLE_PRIVATE_KEY` in
the `macos-signing` environment: the release job declares that environment,
which is auto-created (unprotected) on the first run, so create it ahead of
time and add a **required-reviewers** rule. Releases then pause for human
approval after the tests pass and before any secret is read. The caller
uses `secrets: inherit` precisely so environment secrets resolve; an
explicit `secrets:` mapping would come back empty.

Notarisation uses the App Store Connect API key rather than an Apple ID and
app-specific password: it is revocable per key, immune to 2FA prompts and
shareable without sharing an account. The old gen-1 names
(`APPLE_DEVELOPER_ID_CERT`, `APPLE_DEVELOPER_ID_PASSWORD`,
`APPLE_NOTARY_USER`, `APPLE_NOTARY_PASSWORD`, `APPLE_NOTARY_TEAM_ID`) are
not read by anything and should not be created.

The workflow's default `GITHUB_TOKEN` (`permissions: contents: write`)
publishes the Release and pushes `gh-pages`; the tap PR is the only step
that needs its own token.

### 3. Bootstrap the gh-pages branch

The pipeline publishes `appcast.xml` with a git worktree. If `gh-pages`
does not exist it is created from the release commit, which carries the
whole source history onto the Pages branch. Create an orphan branch once
instead:

```sh
git checkout --orphan gh-pages
git rm -rf .
cp docs/appcast-template.xml appcast.xml
git add appcast.xml
git commit -m "Bootstrap appcast"
git push origin gh-pages
git checkout main
```

In Settings → Pages, enable Pages on the `gh-pages` branch root. The feed
will live at `https://adamxbot.github.io/BananaBlitz/appcast.xml`.

### 4. The Homebrew tap

The tap repository, `adamxbot/homebrew-tap`, already exists and serves
`Casks/bananablitz.rb`. Nothing else is needed for releases to publish;
the cask step simply skips until `HOMEBREW_TAP_TOKEN` is set. Once it is,
each release pushes the rendered cask to a `release/bananablitz-<version>`
branch in the tap and opens a PR whose body links the GitHub Release and
carries the version, SHA-256 and DMG URL. Nothing is pushed to the tap's
default branch; merging that PR is the publish step. Re-running a release
refreshes the same branch and reuses the open PR.

## Turning Sparkle on

In-app updates are dormant until `Info.plist` carries both keys:

```xml
<key>SUFeedURL</key>
<string>https://adamxbot.github.io/BananaBlitz/appcast.xml</string>
<key>SUPublicEDKey</key>
<string>…public key from generate_keys…</string>
```

`UpdaterService` then leaves its dormant state on next launch and the
in-app "Check for Updates…" command becomes active. Ship this in a release
only after step 3 has a live feed, or every installed copy will poll a 404.

## Cutting a release

```sh
# 1. Choose the version and record its approved release notes. This edits
#    MARKETING_VERSION in Config/Shared.xcconfig and CHANGELOG.md; the build
#    number is a UTC stamp captured at build time and is never hand-edited.
just version 1.0.1 notes.md

# 2. Commit on main, open a PR, merge it, and wait for CI on the merge commit.
git commit -am "Release 1.0.1"

# 3. From a clean checkout of that commit: checks the source and the required
#    CI, then creates the annotated tag v1.0.1 and pushes it.
just release 1.0.1
```

The tag push triggers [`release.yml`][workflow]. Triggered is distinct from
published: the pipeline still runs the tests, re-checks the tag against
`MARKETING_VERSION`, and the script re-runs the publication gates before
anything is signed. About 90 seconds after the run finishes, every
BananaBlitz build with a live feed sees the new version on its next check.
Merge the tap PR to publish the cask.

## Local dry runs

```sh
just release-local
# DMG ends up at dist/BananaBlitz-<version>.dmg,
# dSYM at symbols/BananaBlitz-<version>.app.dSYM.zip
```

`release-local` runs the same gates as CI: the checkout must be clean,
carry the matching annotated tag, and have green required checks. Signing
uses the Developer ID Application certificate in your keychain and the
notarisation credentials from `~/.config/apple/signing.env`, described in
[`apple-signing.md`](apple-signing.md). A saved `notarytool` Keychain
profile is the easiest local setup; the App Store Connect API key that CI
uses works too. `dist/` and `symbols/` are ignored by git so the release
outputs never trip the clean-source check.

Use Sparkle's [`generate_appcast`][gen] (or
[`Scripts/generate-appcast.sh`](../Scripts/generate-appcast.sh), which
wraps it) to produce a local `appcast.xml` that points at a `file://` URL
for end-to-end testing against a development build. CI does not use that
script; the shared pipeline generates and signs the feed itself.

[gen]: https://sparkle-project.org/documentation/publishing/
