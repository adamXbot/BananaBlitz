# Contributing

## Build requirements

- macOS 14.0 or later (`MACOSX_DEPLOYMENT_TARGET` is 14.0)
- Xcode 15 or later
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — `brew install xcodegen`

## Generating the project

`BananaBlitz.xcodeproj` is generated from [`project.yml`](project.yml) so that
`.pbxproj` merge conflicts do not happen. Regenerate it after changing
`project.yml`, adding files, or pulling:

```sh
xcodegen generate
open BananaBlitz.xcodeproj
```

`project.yml` is also the canonical version source: `MARKETING_VERSION` is the
user-visible semver and `CURRENT_PROJECT_VERSION` is the build number that must
increase on every notarisation submission.

## Tests

The unit-test target lives in `BananaBlitzTests/`. After `xcodegen generate`:

```sh
xcodebuild test -scheme BananaBlitz -destination 'platform=macOS' -configuration Debug \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
```

That is the same command [`.github/workflows/ci.yml`](.github/workflows/ci.yml)
runs on every push and pull request against `main`; the workflow additionally
uploads the `.xcresult` bundle as an artifact.

Current coverage:

| File | What it exercises |
|---|---|
| `PrivacyCleanerTests.swift` | the cleaning strategies |
| `FileSystemGuardTests.swift` | lock/unlock round-trips |
| `AppStateTests.swift` | persisted settings, history capping, unreadable-state handling |
| `SchedulerServiceTests.swift` | unattended-run downgrading and the cleaning mutex |
| `UnbrickScriptGeneratorTests.swift` | recovery-script generation |

## just recipes

A [`justfile`](justfile) wraps the common commands. `just --list` prints them:

| Recipe | What it runs |
|---|---|
| `just setup` | `xcodegen generate` |
| `just test` | the unsigned Debug test command above |
| `just release <version>` | tags `v<version>` and pushes it, triggering the release workflow |
| `just release-local` | `./Scripts/release.sh` (needs Developer ID and notary credentials) |
| `just clean` | removes `dist/` and `TestResults.xcresult` |

## Bundled scripts

All live in `Scripts/`:

- `release.sh` — the full release pipeline: archive → sign → notarise → DMG →
  notarise DMG → staple. Driven by
  [`.github/workflows/release.yml`](.github/workflows/release.yml); runs locally
  too with the right environment variables.
- `generate-appcast.sh` — wraps Sparkle's `generate_appcast` to produce a signed
  feed for the `gh-pages` branch.
- `unbrick.sh` — reverses every Lock-with-Immutable-File operation. Auto-generated
  from `PrivacyTarget.allTargets`; do not edit it by hand.
- `regenerate-app-icons.sh` — resizes a single source PNG into every slot in
  `AppIcon.appiconset` using the built-in `sips` tool.

## Dependencies

Sparkle is the only package dependency, pinned in `project.yml` from 2.6.0.
Renovate keeps it and the Actions workflows current via the shared
`privacykey/renovate-config` preset ([`renovate.json`](renovate.json)).

## Releasing

Tag-driven; the whole process, including one-time signing and Sparkle setup, is
documented in [`docs/RELEASES.md`](docs/RELEASES.md).
