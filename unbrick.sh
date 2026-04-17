#!/bin/bash

# BananaBlitz Unbrick Script
# This script reverts the "Lock with Immutable File" strategy applied by BananaBlitz.
# It unlocks paths that were replaced with empty files, removes them, and recreates the directories.
# This fixes issues where macOS background daemons and UI components like the menu bar crash.

echo "Reversing BananaBlitz 'replaceWithFile' locks..."

DIR_TARGETS=(
    "$HOME/Library/Caches/com.apple.ap.adprivacyd"
    "$HOME/Library/Caches/com.apple.amsengagementd"
    "$HOME/Library/Caches/com.apple.AppleMediaServices/Metrics/amsengagementd"
    "$HOME/Library/Caches/com.apple.CloudTelemetry"
    "$HOME/Library/Logs/com.apple.CloudTelemetry"
    "$HOME/Library/Caches/com.apple.feedbacklogger"
    "$HOME/Library/Caches/com.apple.geoanalyticsd"
    "$HOME/Library/Caches/com.apple.proactive.eventtracker"
    "$HOME/Library/Containers/com.apple.Safari/Data/Library/Caches"
    "$HOME/Library/Biome"
    "$HOME/Library/IntelligencePlatform"
    "$HOME/Library/Application Support/Knowledge"
    "$HOME/Library/Suggestions"
    "$HOME/Library/Caches/com.apple.parsecd"
    "$HOME/Library/Caches/com.apple.duetexpertd"
    "$HOME/Library/Caches/com.apple.sirittsd"
    "$HOME/Library/Caches/com.apple.chrono"
    "$HOME/Library/Application Support/DifferentialPrivacy"
    "$HOME/Library/Caches/com.apple.sbd"
    "$HOME/Library/Trial"
    "$HOME/Library/Daemon Containers"
    "$HOME/Library/Application Support/com.apple.ScreenTimeAgent"
    "$HOME/Library/Containers/com.apple.mediaanalysisd/Data/Library/Caches"
    "$HOME/Library/com.apple.aiml.instrumentation"
    "$HOME/Library/DuetExpertCenter"
)

FILE_TARGETS=(
    "$HOME/Library/Keyboard/AutocorrectionRejections.db"
)

for target in "${DIR_TARGETS[@]}"; do
    # If the target exists but is a file (not a directory), it is locked
    if [ -e "$target" ] && [ ! -d "$target" ]; then
        echo "Unlocking and restoring directory: $target"
        # Remove immutable flag
        chflags nouchg "$target" 2>/dev/null
        # Remove the lock file
        rm -f "$target"
        # Recreate as a normal directory
        mkdir -p "$target"
    fi
done

for target in "${FILE_TARGETS[@]}"; do
    if [ -e "$target" ]; then
        echo "Unlocking and removing file: $target"
        chflags nouchg "$target" 2>/dev/null
        rm -f "$target"
    fi
done

echo "Restarting UI services to restore the menu bar..."
killall ControlCenter SystemUIServer Dock 2>/dev/null

echo "Done! The menu bar should reappear momentarily. If not, please log out or restart your Mac."
