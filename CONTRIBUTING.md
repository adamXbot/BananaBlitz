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

Two test targets live beside the app: the unit tests in `BananaBlitzTests/`
and the end-to-end UI suite in `BananaBlitzUITests/`.

### Unit tests

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

### End-to-end UI tests

`just ui-test` (or `just ui-test MenuBarUITests` for one class) runs
`BananaBlitzUITests` through its own scheme, `BananaBlitz UI Tests`, and
exports every screenshot to `ui-screenshots/`. XCUITest drives the real app:
the menu bar item, the setup wizard, Settings, the dry-run and self-test
sheets, the save panels, and an actual clean including the destructive lock
strategy and its Unlock.

Every test launches the app with `--ui-testing` and `CFFIXED_USER_HOME`
pointing at a fresh `bananablitz-uitest-*` directory under `$TMPDIR`
(`Support/SandboxHome.swift`). Every `~/Library` path the app scans, cleans or
locks resolves inside that directory, preferences go to a dedicated
`com.bananablitz.uitests` suite that is wiped at launch, Sparkle stays dormant,
and the app refuses to start in UI-testing mode unless its home really is a
sandbox (`BananaBlitz/Support/LaunchConfiguration.swift`). Nothing in your own
`~/Library` or your real BananaBlitz preferences is read or written.

Fixtures are plain directories and files created at the registry paths, so a
clean has something to remove and the suite can assert exact byte counts. The
Full Disk Access check is satisfied by creating `Library/Biome` in the sandbox.
Tests never create a Time Machine snapshot or register a login item; those two
remain manual checks on a signed build.

| File | What it exercises |
|---|---|
| `PreflightUITests.swift` | run first and alone in CI: fails with a clear message if a system dialog is covering the screen |
| `OnboardingUITests.swift` | auto-open on first launch, all seven steps, Back, the no-access path with Skip, the first blitz cleaning fixtures, accepting the default level enables its targets, resume after quit, Get Started from the popover |
| `MenuBarUITests.swift` | popover summary and dashboard, pause/resume, confirm-then-clean, cancel touches nothing, a cancelled confirmation stays cancelled on reopen, reopening never re-arms the schedule, Settings and Quit |
| `SettingsUITests.swift` | the five panes, About's version and build number, schedule interval and pause, default level, Full Disk Access status, preference persistence across relaunch, dry-run preview mirrors the unattended downgrade, self-test, rescan, Reset All Settings |
| `TargetsUITests.swift` | search, level filter, per-target toggles and section toggles with persistence, row details and strategy picker, lock → confirm → unlock round trip |
| `DataExportUITests.swift` | Save Recovery Script and Export History through the real save panel |
| `VisualReviewUITests.swift` | screenshots of every surface in light and dark appearance |

The suite needs an ad-hoc signed runner (macOS kills an unsigned XCUITest
runner, so `CODE_SIGNING_ALLOWED=NO` must not be passed) and a logged-in GUI
session it has to itself: any system alert that appears mid-run steals clicks
and fails whichever test is running. The shared `ci.yml` keeps running only
the `BananaBlitz` scheme; [`ui-tests.yml`](.github/workflows/ui-tests.yml)
runs the preflight and then the suite on a macOS runner.

Controls are located by the identifiers in `BananaBlitz/Support/AccessibilityID.swift`,
which is compiled into both the app and the UI test bundle. Shared surface
controls (the Settings tabs, About, Launch at login, Reset) carry no
identifiers and are found by their labels instead; never edit
`Shared/MacSurfaces` to add one.

## just recipes

A [`justfile`](justfile) wraps the common commands. `just --list` prints them:

| Recipe | What it runs |
|---|---|
| `just setup` | `xcodegen generate` |
| `just test` | the unsigned Debug test command above |
| `just ui-test [Class[/test]]` | the end-to-end UI suite, ad-hoc signed, screenshots to `ui-screenshots/` |
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
