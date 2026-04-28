#!/bin/bash

# BananaBlitz Unbrick Script
# Auto-generated from PrivacyTarget.allTargets — do not edit by hand.
# Reverses the 'Lock with Immutable File' strategy: removes the immutable
# flag, deletes the lock file, and recreates the directory.
#
# To regenerate: open BananaBlitz → Settings → Preferences → Data →
# "Save Recovery Script…", or call UnbrickScriptGenerator.write(to:) from a
# Swift Playground / unit test.

set -u

EXIT_CODE=0

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
    "$HOME/Library/Containers/com.apple.Safari/Data/Library/Caches"
)

FILE_TARGETS=(
    "$HOME/Library/Keyboard/AutocorrectionRejections.db"
)

for target in "${DIR_TARGETS[@]}"; do
    if [ -e "$target" ] && [ ! -d "$target" ]; then
        echo "Unlocking and restoring directory: $target"
        chflags nouchg "$target" 2>/dev/null || EXIT_CODE=1
        rm -f "$target" || EXIT_CODE=1
        mkdir -p "$target" || EXIT_CODE=1
    fi
done

for target in "${FILE_TARGETS[@]}"; do
    if [ -e "$target" ]; then
        echo "Unlocking and removing file: $target"
        chflags nouchg "$target" 2>/dev/null || EXIT_CODE=1
        rm -f "$target" || EXIT_CODE=1
    fi
done

echo "Restarting UI services to restore the menu bar..."
killall ControlCenter SystemUIServer Dock 2>/dev/null || true

if [ "$EXIT_CODE" -ne 0 ]; then
    echo "Done with errors. Review the output above; some paths may still be locked."
else
    echo "Done! The menu bar should reappear momentarily. If not, please log out or restart your Mac."
fi

exit $EXIT_CODE
