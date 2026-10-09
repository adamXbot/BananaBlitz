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
# Set to 1 once a locked target is found. Homebrew runs this script on
# every uninstall, upgrade and reinstall, so UI services are restarted
# only when something was actually unlocked.
CHANGED=0

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
        CHANGED=1
        chflags nouchg "$target" 2>/dev/null || EXIT_CODE=1
        rm -f "$target" || EXIT_CODE=1
        mkdir -p "$target" || EXIT_CODE=1
    fi
done

# True when $1 carries the user-immutable flag set by `chflags uchg`.
# BSD stat by full path: a GNU stat earlier on PATH reads -f differently.
is_user_immutable() {
    case ",$(/usr/bin/stat -f %Sf "$1" 2>/dev/null)," in
        *,uchg,*) return 0 ;;
        *) return 1 ;;
    esac
}

# A file target is the real file rather than a stand-in, so leave it alone
# unless it is locked.
for target in "${FILE_TARGETS[@]}"; do
    if [ -e "$target" ] && is_user_immutable "$target"; then
        echo "Unlocking and removing file: $target"
        CHANGED=1
        chflags nouchg "$target" 2>/dev/null || EXIT_CODE=1
        rm -f "$target" || EXIT_CODE=1
    fi
done

if [ "$CHANGED" -eq 1 ]; then
    echo "Restarting UI services to restore the menu bar..."
    killall ControlCenter SystemUIServer Dock 2>/dev/null || true
else
    echo "No locked targets found."
fi

if [ "$EXIT_CODE" -ne 0 ]; then
    echo "Done with errors. Review the output above; some paths may still be locked."
elif [ "$CHANGED" -eq 1 ]; then
    echo "Done! The menu bar should reappear momentarily. If not, please log out or restart your Mac."
fi

exit $EXIT_CODE
