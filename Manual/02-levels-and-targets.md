# Cleaning levels and targets

A **target** is one path in `~/Library` that BananaBlitz can clean. There are 26, each with a name, a description, the path, the side effect of cleaning it and the strategies it supports. A **level** is a preset that enables a set of them.

## Levels

- **Basic.** Analytics and metrics only, 8 targets. Nothing breaks.
- **Strong.** Basic plus 10 intelligence databases, 18 targets. Suggestions get dumber until they rebuild.
- **Paranoid.** Everything, 26 targets. Maximum privacy; some features may temporarily break.

Choosing a level in the setup wizard or in Settings ▸ Schedule re-selects its targets. After that you can enable or disable any target on its own in Settings ▸ Targets, and the level row in the popover shows how many of each level's targets are on.

## Basic targets

- **Ad Privacy Daemon** — `~/Library/Caches/com.apple.ap.adprivacyd`. Advertising privacy configuration and tracking cache. Side effect: none; disabling ad tracking is the goal.
- **AMS Engagement** — `~/Library/Caches/com.apple.amsengagementd`. App Store engagement metrics. Side effect: none meaningful.
- **AMS Metrics** — `~/Library/Caches/com.apple.AppleMediaServices/Metrics/amsengagementd`. Detailed App Store engagement telemetry. Side effect: none meaningful.
- **Cloud Telemetry (Cache)** — `~/Library/Caches/com.apple.CloudTelemetry`. iCloud telemetry cache. Side effect: none meaningful.
- **Cloud Telemetry (Logs)** — `~/Library/Logs/com.apple.CloudTelemetry`. iCloud telemetry logs. Side effect: none meaningful.
- **Feedback Logger** — `~/Library/Caches/com.apple.feedbacklogger`. System feedback and crash analytics cache. Side effect: none meaningful.
- **GeoAnalytics** — `~/Library/Caches/com.apple.geoanalyticsd`. Location analytics. Side effect: none meaningful.
- **Proactive EventTracker** — `~/Library/Caches/com.apple.proactive.eventtracker`. Event tracking for predictive features. Side effect: none meaningful.

## Strong targets

- **Biome** — `~/Library/Biome`. Stream-based tracker logging app usage, web activity and notifications. Side effect: Siri and Spotlight suggestions degrade.
- **IntelligencePlatform** — `~/Library/IntelligencePlatform`. Knowledge graph of your behaviour, contacts and interactions. Side effect: Apple Intelligence features degrade.
- **KnowledgeC** — `~/Library/Application Support/Knowledge`. Legacy CoreDuet database of app usage, lock and unlock, media playback. Side effect: Handoff and suggestions degrade. Also supports Delete Databases Only.
- **Suggestions** — `~/Library/Suggestions`. People, address and interaction suggestions. Side effect: QuickType and contact suggestions degrade.
- **Parsec** — `~/Library/Caches/com.apple.parsecd`. Spotlight remote results and Safari suggestions. Side effect: Spotlight remote suggestions are slower.
- **DuetExpert** — `~/Library/Caches/com.apple.duetexpertd`. Usage prediction cache for battery and app suggestions. Side effect: battery prediction is less accurate.
- **Siri TTS** — `~/Library/Caches/com.apple.sirittsd`. Siri text-to-speech personalisation. Side effect: Siri's voice is slightly less personalised.
- **Chrono** — `~/Library/Caches/com.apple.chrono`. Widget suggestion timing data. Side effect: widget suggestions are less relevant.
- **Differential Privacy** — `~/Library/Application Support/DifferentialPrivacy`. Telemetry queued for Apple. Side effect: stops contributing anonymous analytics to Apple.
- **SBD (Secure Backup)** — `~/Library/Caches/com.apple.sbd`. Cloud sync analytics and logging. Side effect: iCloud sync analytics stop; sync itself is unaffected. Wipe Contents only.

## Paranoid targets

- **Trial (assistantd)** — `~/Library/Trial`. A/B experiments and model updates managed by triald. Side effect: Siri and assistant experiments stop; the system may re-download models.
- **Daemon Containers** — `~/Library/Daemon Containers`. Per-daemon sandbox container store for many system services. Side effect: invasive; services rebuild their containers and some may misbehave until you log out or restart. Wipe Contents only.
- **ScreenTime Agent** — `~/Library/Application Support/com.apple.ScreenTimeAgent`. Screen Time usage data, sometimes collected even when the feature is off. Side effect: Screen Time data is lost.
- **Media Analysis** — `~/Library/Containers/com.apple.mediaanalysisd/Data/Library/Caches`. Photos analysis cache: faces, objects, Live Text. Side effect: Photos search and suggestions rebuild from scratch. Wipe Contents only.
- **Keyboard Profiling** — `~/Library/Keyboard/AutocorrectionRejections.db`. Every autocorrection you reject. Side effect: autocorrect is slightly less personalised. A single file; Delete Databases Only.
- **AIML Instrumentation** — `~/Library/com.apple.aiml.instrumentation`. Apple AI and ML telemetry. Side effect: none meaningful.
- **DuetExpertCenter** — `~/Library/DuetExpertCenter`. Central prediction engine store. Side effect: battery and app prediction models rebuild.
- **Safari Web Caches** — `~/Library/Containers/com.apple.Safari/Data/Library/Caches`. Safari's cache, including tracking scripts and some session data. Side effect: may log you out of some websites. Wipe Contents only.

## Reading a target row

In Settings ▸ Targets each row shows the target's name, a one-line description, its size on disk (or *not present on this Mac*) and a switch. Click a row to expand it: the side effect, the full path, the strategy picker where more than one strategy is supported, **Verify state** to re-read that one path, and **Unlock** when the target is locked. A lock icon beside the name means the path is currently replaced by a locked file. See [Strategies](03-strategies.md).
