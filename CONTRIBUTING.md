# Contributing

## Build requirements

- macOS 14.0 or later (`MACOSX_DEPLOYMENT_TARGET` is 14.0)
- Xcode 16 or later (the shared surface code uses `openSettings` and `Tab`, which first ship in that SDK)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — `brew install xcodegen`

## Generating the project

`BananaBlitz.xcodeproj` is generated from [`project.yml`](project.yml) so that
`.pbxproj` merge conflicts do not happen. Regenerate it after changing
`project.yml`, adding files, or pulling:

```sh
xcodegen generate
open BananaBlitz.xcodeproj
```

[`Config/Shared.xcconfig`](Config/Shared.xcconfig) is the canonical version
source: `MARKETING_VERSION` is the user-visible semver, changed with
`just version VERSION NOTES_FILE`. The build number is a UTC stamp captured at
build time and is never hand-edited; see
[`docs/BUILD-PROVENANCE.md`](docs/BUILD-PROVENANCE.md).

## Shared surfaces and the manual

`BananaBlitz/Shared/MacSurfaces` is a copy of the shared Settings, About,
menu, Help and menu bar code used across the portfolio's macOS apps. Never
edit it in this repository: `just surfaces` copies in the current version when
the standard's checkout is beside this one, and `xcodegen generate` runs the
same step, verifying the committed copy against `.project/mac-surfaces.lock.json`
when it is not. The app's own profile is `BananaBlitz/BananaBlitzSurface.swift`.

The in-app manual is the numbered Markdown pages in [`Manual/`](Manual/),
bundled as a folder into `Contents/Resources/Manual`. The first heading is the
page title; `[text](02-page.md)` links between pages.

## Tests

The unit-test target lives in `BananaBlitzTests/`. After `xcodegen generate`:

```sh
xcodebuild test -scheme BananaBlitz -destination 'platform=macOS' -configuration Debug \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
```

That is the same command [`.github/workflows/ci.yml`](.github/workflows/ci.yml)
runs on every push and pull request against `main`, through the shared
`macos-app-ci.yml` workflow in privacykey/gh-workflows; it additionally uploads
the `.xcresult` bundle as an artifact.

Current coverage:

| File | What it exercises |
|---|---|
| `PrivacyCleanerTests.swift` | the cleaning strategies, locked targets being left alone, explicit unlock, measured bytes reclaimed |
| `DryRunTests.swift` | dry-run copy, including locked and blocked targets |
| `FileSystemGuardTests.swift` | lock/unlock round-trips |
| `AppStateTests.swift` | persisted settings, history capping, unreadable-state handling, legacy state decoding |
| `MenuBarIconStyleTests.swift` | the one-time move of the menu bar icon choice to the shared preference key |
| `SchedulerServiceTests.swift` | unattended-run downgrading, the cleaning mutex, catch-up only after a missed fire |
| `SnapshotServiceTests.swift` | parsing `tmutil` output |
| `UnbrickScriptGeneratorTests.swift` | recovery-script generation, and that the committed `Scripts/unbrick.sh` is current |
| `HomebrewCaskTests.swift` | the cask template's sandbox `writable_paths` covering every target |

## just recipes

A [`justfile`](justfile) wraps the common commands. `just --list` prints them:

| Recipe | What it runs |
|---|---|
| `just setup` | `xcodegen generate` |
| `just test` | the unsigned Debug test command above |
| `just release <version>` | tags `v<version>` and pushes it, triggering the release workflow |
| `just release-local` | `./Scripts/release.sh` (needs Developer ID and notary credentials) |
| `just clean` | removes the declared reproducible outputs under `.project/output/` |

## Bundled scripts

All live in `Scripts/`:

- `release.sh` — the build half of a release: archive → sign → notarise → DMG →
  notarise DMG → staple, plus the dSYM zip. The shared release pipeline calls it
  through [`.github/workflows/release.yml`](.github/workflows/release.yml); it
  runs locally too as `just release-local`.
- `generate-appcast.sh` — wraps Sparkle's `generate_appcast` for local appcast
  experiments. CI generates and signs the published feed itself.
- `unbrick.sh` — reverses every Lock-with-Immutable-File operation. Auto-generated
  from `PrivacyTarget.allTargets`; do not edit it by hand.
- `regenerate-app-icons.sh` — resizes a single source PNG into every slot in
  `AppIcon.appiconset` using the built-in `sips` tool.

## Dependencies

Sparkle is the only package dependency, declared in `project.yml` from 2.10.0 and
resolved in the committed `Package.resolved`. Regenerate the project and
re-resolve after a bump so the tracked files match what CI generates.
Renovate keeps it and the Actions workflows current via the shared
`privacykey/renovate-config` preset ([`renovate.json`](renovate.json)).

## Releasing

Tag-driven; the whole process, including one-time signing and Sparkle setup, is
documented in [`docs/RELEASES.md`](docs/RELEASES.md).
