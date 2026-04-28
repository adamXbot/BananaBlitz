# BananaBlitz — Code Audit & Improvement Plan

Scope: full pass over the Swift sources, models, services, views, entitlements, Info.plist, build config, and the `unbrick.sh` recovery script. macOS 14, SwiftUI, Xcode 15+, XcodeGen.

Findings are grouped by area and tagged **[Severity]** — `Critical` (data-loss / correctness / security), `High` (real-world breakage or strong UX hit), `Medium` (refactor with material payoff), `Low` (polish).

---

## 1. Architecture & Concurrency

### 1.1 `AppState` is read off the main thread without snapshotting — **High**
`PrivacyCleaner.cleanAll(state: AppState)` runs on `DispatchQueue.global(qos: .userInitiated)` (see `SchedulerService.performScheduledClean` and `performManualClean`) but reads `state.enabledTargets` and `state.strategyFor()` from the background queue. Those getters touch `@Published` `enabledTargetIDs` and `targetStrategies`, which can be mutated on main at the same time (e.g. user toggles a target while a clean is firing). That's a data race, and Swift 6 strict concurrency will reject it.

Fix:
1. Annotate `AppState` and `SchedulerService` with `@MainActor`.
2. Refactor `PrivacyCleaner` to take a value-type snapshot, e.g. `cleanAll(targets: [(PrivacyTarget, CleaningStrategy)])`, built on the main actor before dispatching.
3. Make filesystem operations an `actor` (`PrivacyCleanerActor`) so call sites become `await cleaner.cleanAll(...)`.

### 1.2 Double-publish from `@AppStorage` + manual `objectWillChange.send()` — **Medium**
In `AppState`, computed accessors like `selectedLevel` and `scheduleInterval` write to an `@AppStorage`-backed raw and *also* call `objectWillChange.send()`. `@AppStorage` already publishes via its own property wrapper, so this both fires twice and fires *before* the underlying value has changed (manual `send()` in the setter is "willChange," but the actual write happens on the next line). Drop the manual sends.

### 1.3 Persistence error handling is silently swallowed — **High**
`AppState.savePersistedData` does `try? encoded.write(to: persistenceURL)` and the directory creation also uses `try?`. If Application Support isn't writable (rare but possible), the user's enabled targets, history, and strategies are silently lost on every launch. Replace with `do/catch` and a `Logger`. Same for `loadPersistedData`.

### 1.4 Force unwrap of `FileManager.default.urls(for:in:).first!` — **Medium**
`AppState.persistenceURL` will crash if Application Support resolution fails. Use `try` + propagation or fall back to `~/Library/Application Support/BananaBlitz` constructed manually.

### 1.5 `Timer.scheduledTimer` for scheduled cleaning is fragile — **High**
`SchedulerService.updateSchedule` creates a `Timer` on the run loop with a fixed interval. Three concrete problems:
- It does not fire while the Mac is asleep, and it does not "make up" missed fires.
- `nextCleanDate` and the timer are not persisted; on relaunch the schedule restarts from "now," so a 24-hour interval can skip many cleans across reboots.
- There is no observation of `NSWorkspace.didWakeNotification` to recover after wake.

Fix:
- Persist `lastCleanDate` (already done) and on launch, if `Date().timeIntervalSince(lastCleanDate) >= scheduleInterval`, run an immediate catch-up clean.
- Subscribe to `NSWorkspace.shared.notificationCenter`'s `didWakeNotification`.
- Consider `DispatchSourceTimer` on a background queue, or a `BGAppRefreshTask`-style approach via `LSBackgroundOnly` since this is `LSUIElement` already.

### 1.6 `performScheduledClean` doesn't re-check `isPaused` at fire time — **Medium**
The user can pause between scheduling and firing. Add `guard !state.isPaused else { return }` at the top of `performScheduledClean`.

### 1.7 "Reset All Settings" leaves the scheduler armed — **Medium**
`SettingsView.preferencesTab → Reset All Settings` clears state but never calls `scheduler.stop()`. The next fire will run on the (now empty / freshly defaulted) state.

### 1.8 `MenuBarExtra` `onAppear` runs initial scan only on first appearance — **Low**
The onAppear-driven scan is fine for first launch, but `MenuBarExtra` doesn't re-emit `onAppear` on later activations reliably. Move the bootstrap into the App's `init` or use a single `Task` owned by `AppState`.

---

## 2. File-System Behaviour & Security

### 2.1 Spawning `/usr/bin/chflags` is unnecessary — **Medium**
`FileSystemGuard.setImmutableFlag` runs `Process()` against `/usr/bin/chflags`. Foundation can do this in-process:

```swift
var values = URLResourceValues()
values.isUserImmutable = immutable
try url.setResourceValues(&values)
```

Or, more directly, `chflags(path, UF_IMMUTABLE)` via the C SPI. Benefits: faster, no `PATH`/system-binary dependency, no subprocess inheritance concerns, easier to mock in tests.

### 2.2 Symlink-following on destructive ops — **High**
`PrivacyCleaner.wipeContents` calls `fileManager.contentsOfDirectory(atPath:)` followed by `removeItem(atPath:)` on every entry. If a daemon races and replaces the target with a symlink, `removeItem` only removes the link itself (safe), but `directorySize`'s `enumerator(atPath:)` *does* follow symlinks and could traverse into unrelated locations. Use `enumerator(at:URL, options:[.skipsSubdirectoryDescendants, .skipsPackageDescendants])` with `URLResourceValues` for `.isSymbolicLink` and explicitly skip links before recursing.

Add a top-of-function guard that the resolved path is *inside* `NSHomeDirectory() + "/Library"`:

```swift
let home = (NSHomeDirectory() as NSString).appendingPathComponent("Library")
guard target.resolvedPath.hasPrefix(home + "/") || target.resolvedPath == home else {
    throw BananaBlitzError.refusedOutsideLibrary(target.resolvedPath)
}
```

This is a cheap belt-and-braces guard against any future refactor that lets a path leak through.

### 2.3 `isLocked` heuristic is shaky — **Medium**
For directory targets, `FileSystemGuard.isLocked` returns true if the path exists *and* is not a directory. That's a reasonable proxy but it isn't actually checking the immutable flag — any random file at that path counts as "locked" in the UI. Tighten by also checking `URLResourceValues.isUserImmutable` for non-directory targets.

### 2.4 `tmutil localsnapshot` does not need administrator privileges — **High**
`SnapshotService.createSnapshot` runs `do shell script "/usr/bin/tmutil localsnapshot /" with administrator privileges`. On modern macOS, `tmutil localsnapshot` works without admin for the boot volume in the user's session. The AppleScript admin elevation:
- Pops a sudo/Touch ID prompt the user does not need to see.
- Triggers the Automation/AppleEvents permission flow.
- Hands the app an admin token it doesn't actually need.

Replace with an in-process `Process()` invocation of `/usr/bin/tmutil` without privilege escalation. Fall back to elevated execution only on `EPERM`.

Also: the README + onboarding step describe the snapshot as a way to "revert your system state if anything goes wrong." `tmutil localsnapshot` creates a Time Machine local snapshot — useful for restoring individual files, but it is not a one-click OS rollback. Soften the copy.

### 2.5 No code signing / notarization — **Critical**
Per `project.yml`: `CODE_SIGN_IDENTITY: "-"`, `CODE_SIGN_STYLE: Manual`. README acknowledges users must `xattr -cr` to remove quarantine. Concrete consequences:
- Gatekeeper blocks first launch with no clear path forward for non-technical users.
- Full Disk Access toggles in System Settings will silently revoke whenever the binary's signature changes, since unsigned apps are tracked by code signing identity → bundle path heuristic.
- A future attacker who replaces the binary keeps FDA — without notarization, there's no integrity backstop.

Action items:
- Get a Developer ID certificate.
- Enable Hardened Runtime (`ENABLE_HARDENED_RUNTIME = YES`).
- Notarize via `notarytool` and staple in CI.
- Remove the `xattr -cr` instruction from the README once notarized.

### 2.6 Entitlements file is minimal — **Medium**
`BananaBlitz.entitlements` only sets `com.apple.security.app-sandbox = false`. With Hardened Runtime you'll likely want explicit entitlements such as:
- `com.apple.security.automation.apple-events` (only if keeping AppleScript admin — see 2.4).
- `com.apple.security.cs.disable-library-validation` only if loading 3rd-party frameworks (you aren't — leave off).

Document why each is or isn't present.

### 2.7 Persisted user state is plaintext JSON — **Low**
`Application Support/BananaBlitz/state.json` stores the user's privacy choices and full cleaning history. Not a leak per se, but it's "list of every privacy concern this user acted on" sitting in plaintext. If you later add a Keychain-stored key, encrypt at rest.

---

## 3. UI / SwiftUI

### 3.1 Filesystem calls inside view bodies — **High**
Two repeat-render hotspots:

- `SettingsView.preferencesTab` calls `PermissionChecker.shared.hasFullDiskAccess()` *twice* in the same body, every time SwiftUI re-renders. Each call walks `~/Library/Biome`, `~/Library/Trial`, `~/Library/Suggestions`, `~/Library/IntelligencePlatform` and attempts a `contentsOfDirectory`. That's filesystem I/O on the main thread per render.
- `TargetListView → TargetRowView` passes `isLocked: TargetScanner.shared.isLocked(target)` inside a `ForEach`. Each row, each render, hits the filesystem.

Fix: maintain `@Published var lockStates: [String: Bool]` on `AppState`, refreshed alongside `scanResults`. Make permission status a `@State` populated by a `.task` that polls every 2s while the view is visible, the same pattern `PermissionStepView` already uses.

### 3.2 `CleanButton.isPressed` is dead state — **Medium**
`@State private var isPressed = false` is declared and used (`symbolEffect(.bounce, value: isPressed)`, `scaleEffect(isPressed ? 0.97 : 1.0)`) but **never toggled anywhere** — so the bounce/scale never fire. Either wire it up via `.simultaneousGesture(DragGesture(minimumDistance: 0)…)` to flip it on press, or delete the state and the references.

### 3.3 `ScheduleStepView.onAppear` silently enables Launch at Login — **High**
Lines 102–106:
```swift
if !appState.launchAtLogin {
    appState.launchAtLogin = true
    try? SMAppService.mainApp.register()
}
```
This toggles a system-level launch agent without the user touching the toggle. macOS now surfaces a notification "X added an item that can run in background," which is fine — but it's still a user-hostile auto-opt-in to background execution mid-onboarding. Default the toggle to ON in the UI but require an explicit user click.

### 3.4 Animation in `ScanStepView.animateReveal` uses repeated `DispatchQueue.main.asyncAfter` — **Low**
Works, but ties view code to wall-clock. Prefer `withAnimation(.spring().delay(...))` chained per item, or `Task { try? await Task.sleep(...); … }` so cancellation is automatic when the view goes away.

### 3.5 Hard-coded "banana gold" repeated everywhere — **Low**
`Color(hue: 0.14, saturation: 0.85, brightness: 0.95)` appears in `CleanButton`, `OnboardingContainerView`, `CleanStepView`. Add `Color.bananaGold` in `Assets.xcassets` (already a colorset for AccentColor) or extract to `Color+Brand.swift`.

### 3.6 7-step onboarding has duplicated step labels — **Low**
Comments say "Step 5: Configure scheduling" (`ScheduleStepView`) and "Step 5: Execute the initial clean" (`CleanStepView`). Fix the comments, and consider whether the snapshot step really merits a full step or could be a banner on the scan screen — it would shorten the funnel.

### 3.7 `MenuBarView` quit button is the only way to close the popover safely — **Low**
Several actions (`Settings`, `Onboarding`) call `NSApplication.shared.activate(ignoringOtherApps: true)` then `openWindow`. After the user closes the window, the menu bar can lose focus. Consider `NSApp.setActivationPolicy(.accessory)` toggling.

### 3.8 No accessibility labels on emoji-only UI — **Medium**
The 🍌 menu bar item, level emoji 🟢🟡🔴, and `StatusDot` have no `accessibilityLabel` / `accessibilityHidden`. VoiceOver users get "banana, banana, banana, eight." Add labels for level pills, the menu bar label, and status dots.

### 3.9 Form layout pickers lose their label in `.menu` style — **Low**
`Picker("Strategy Override", selection:)` then immediately `.labelsHidden()` defeats the section semantics. Either keep the label visible or switch to `.segmented` for clarity.

---

## 4. Correctness Bugs

### 4.1 `OnboardingContainerView.handleNext` only triggers scan transitioning *out of* the permission step — **Low**
If the user clicks back from the scan step, `scanResults` is preserved but won't re-scan even if they have just toggled FDA off and on. Re-run on every transition into step 2, or stash results in `@StateObject` keyed by FDA state.

### 4.2 `unbrick.sh` calls `killall ControlCenter SystemUIServer Dock` unconditionally — **Medium**
Restarting these is appropriate after extensive `chflags` on system caches, but it also disrupts whatever the user is doing right now. Print a clear warning before, or wrap in a confirm prompt. Also exit non-zero if any `chflags` call fails so the user notices.

### 4.3 `notificationStyleRaw` `.silent` causes a `return` inside a guarded code path — **Low**
`SchedulerService.sendCleanNotification` short-circuits on `.silent`, but the call site already gates with `if state.notificationStyle != .silent`. Dead branch — remove for clarity.

### 4.4 Scheduler doesn't catch up missed runs at app launch — **High**
Already noted in 1.5. Concrete bug: install BananaBlitz with "every 4 hours," set Mac to sleep for 24 hours, wake it — no clean fires until 4 hours after wake. For a privacy tool the user trusts to keep things empty, that's a real gap. On launch, compare `Date().timeIntervalSince(state.lastCleanDate ?? .distantPast)` to the interval and run an immediate clean if overdue.

### 4.5 `setDefaultTargets(for:)` is called twice during onboarding — **Low**
Once from `LevelPickerStepView.onChange(of: selectedLevel)` and once from `BananaBlitzApp.onAppear` if `enabledTargetIDs.isEmpty`. Idempotent, so OK, but reads redundant.

### 4.6 `addResult` updates `totalBytesReclaimed` only for successful results — **Low**
Correct behaviour, but failures with non-zero `bytesReclaimed` (partial wipes that throw) get dropped from totals. Either set `bytesReclaimed: 0` on failure (already does) or expose a separate "partial" counter.

---

## 5. Build, Tooling, Distribution

### 5.1 No tests — **High**
Zero `XCTest` target. For a tool that destructively mutates the user's filesystem, the minimum bar is:
- `PrivacyCleanerTests` against a temp directory (`URL(fileURLWithPath: NSTemporaryDirectory())`), faking a `PrivacyTarget` whose `resolvedPath` points there.
- `FileSystemGuardTests` for lock → unlock idempotency, no-op when not locked, error path when path doesn't exist.
- `TargetScannerTests` for size, file count, lock detection.
- `AppStateTests` for round-trip persistence.

Add a `BananaBlitzTests` target in `project.yml`:
```yaml
  BananaBlitzTests:
    type: bundle.unit-test
    platform: macOS
    sources: [BananaBlitzTests]
    dependencies:
      - target: BananaBlitz
```

### 5.2 No CI — **Medium**
Add a GitHub Actions workflow:
- `xcodegen generate`
- `xcodebuild test -scheme BananaBlitz -destination 'platform=macOS'`
- `swiftlint` (add a config — there's no `.swiftlint.yml`).
- On tag: `xcodebuild archive` + `notarytool submit` + `stapler staple`.

### 5.3 No `LICENSE` file — **Low**
README says MIT; add a `LICENSE` file at repo root.

### 5.4 No bug reporting / version display — **Low**
There's no "About BananaBlitz" panel. Add the version + commit SHA somewhere in Settings → Preferences and a "Report an Issue" link. Useful when users hit a daemon edge case.

### 5.5 `print(...)` for diagnostics — **Medium**
`SettingsView.updateLoginItem` and `ScheduleStepView` both `print("Failed to update login item: \(error)")`. Migrate to `os.Logger`:
```swift
private let log = Logger(subsystem: "com.bananablitz.app", category: "loginItem")
log.error("Failed to update login item: \(error.localizedDescription, privacy: .public)")
```

### 5.6 `@AppStorage` keys are stringly-typed — **Low**
Easy migration trap: rename a key in code and you orphan a user's setting. Centralize:
```swift
enum StorageKey {
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
    static let selectedLevelRaw = "selectedLevelRaw"
    // ...
}
```

---

## 6. Documentation / Product

### 6.1 README understates the destruction model — **Medium**
The README says "non-destructive" in the caution box but the entire `replaceWithFile` strategy *is* destructive — it deletes the original directory and replaces it with an immutable empty file. Recovery requires `unbrick.sh`. Reword: "designed to be reversible," not "non-destructive."

### 6.2 Snapshot rollback messaging — **Medium**
`SnapshotStepView`: "allows you to revert your system state if anything goes wrong." This implies a one-click bootable rollback. `tmutil localsnapshot` doesn't do that — it gives you Time Machine-style file-level restore. Reword to "lets you restore individual files via Time Machine if cleaning has unexpected effects."

### 6.3 `unbrick.sh` and the in-app target list are duplicated state — **High**
`unbrick.sh` hardcodes the same paths as `PrivacyTarget.basicTargets/strongTargets/paranoidTargets`. The two will drift. Generate `unbrick.sh` from the model:
- Add a "Generate Unbrick Script" menu item in Settings → Data that writes the script to `~/Desktop` from the current registry.
- Or maintain the canonical list in a JSON/plist that both Swift and the script read.

---

## Recommended Order of Attack

1. **Code-sign & notarize** (5.x, 2.5). Until this is done, every other improvement is hidden behind `xattr -cr`.
2. **Concurrency fixes + scheduler catch-up** (1.1, 1.5, 4.4). Real-world correctness wins.
3. **Drop AppleScript admin for `tmutil`** (2.4). Removes a scary permission prompt.
4. **Add tests + CI** (5.1, 5.2). Required before further refactors.
5. **Replace `chflags` subprocess with `URLResourceValues`** (2.1). Pure quality-of-life.
6. **Fix view-body filesystem calls** (3.1) and dead button state (3.2). Easy UX wins.
7. **Generate `unbrick.sh` from the model** (6.3). Prevent drift.
8. **Hardened runtime + minimal entitlements + accessibility labels** (2.6, 3.8). Distribution + inclusivity.

---

## Quick Wins (under an hour each)

- Delete dead `isPressed` state in `CleanButton` or wire it up.
- Replace `print(...)` with `Logger`.
- Add `LICENSE` file.
- Stop auto-enabling Launch at Login in `ScheduleStepView.onAppear`.
- Add `guard !state.isPaused else { return }` at top of `performScheduledClean`.
- Have "Reset All Settings" call `scheduler.stop()`.
- Cache `hasFullDiskAccess()` in a `@State` and refresh on a `.task` timer instead of computing per render.
