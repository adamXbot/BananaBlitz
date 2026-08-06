# Security policy

BananaBlitz modifies system-generated files inside `~/Library`, applies
immutable flags, and ships an auto-updater. We take vulnerability
reports seriously.

## Reporting a vulnerability

**Please don't open a public GitHub issue.** 

- A description of the issue and its impact.
- Steps to reproduce, or a proof-of-concept if you have one.
- The BananaBlitz version you observed it on (BananaBlitz menu →
  About BananaBlitz, or
  `mdls -name kMDItemVersion /Applications/BananaBlitz.app`).
- Your macOS version and chip family (Apple menu → About This Mac).
- Whether you've shared the finding anywhere else (e.g. coordinated
  disclosure with another vendor).

We aim to acknowledge within 72 hours and to ship a fix within 30
days for high-severity issues. We'll keep you in the loop on the
timeline and credit you in the release notes if you want — let us
know your preference.

## What's in scope

- The BananaBlitz app and its cleaning / locking / scheduling logic.
- The release pipeline (signing, notarization, appcast feed,
  Sparkle update flow).
- The Homebrew Cask published at `adamxbot/homebrew-tap`.
- The bundled recovery script (`Scripts/unbrick.sh`).

## What's out of scope

- Privilege escalation that requires the attacker to already have
  root or to control the user's keychain — those are pre-existing
  conditions BananaBlitz can't defend against.
- Findings that depend on a tampered or unsigned build of
  BananaBlitz (we don't claim to defend against an attacker who can
  replace the bundle on disk).
- Low-severity issues in third-party dependencies (Sparkle, Apple
  frameworks). Please report those upstream first; we'll happily
  track and bump versions on our end once a fix lands.
- Apple-defined system behaviour: BananaBlitz uses public APIs
  (`URLResourceValues.isUserImmutable`, `tmutil`, etc.). If macOS
  changes how those work, that's an OS issue first.

## What we promise

- We will not pursue legal action against good-faith security
  research conducted under this policy.
- We won't share your report with anyone outside the BananaBlitz
  maintainer team without your consent.
- We'll be transparent about what we fixed, what we didn't, and why.

## Hall of fame

Reporters who would like public credit will be listed in
[release notes](https://github.com/adamxbot/BananaBlitz/releases).
