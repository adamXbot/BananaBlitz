# List available commands
default:
    @just --list

# Generate BananaBlitz.xcodeproj from project.yml (requires xcodegen)
[group("dev")]
setup:
    xcodegen generate

# Build and run the unit tests (unsigned Debug, same as CI)
[group("dev")]
test:
    xcodebuild test -scheme BananaBlitz -destination 'platform=macOS' -configuration Debug CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

# Tag v<version> and push it to trigger the release workflow
[group("ship")]
release version:
    git tag "v{{version}}"
    git push origin "v{{version}}"

# Build, sign, notarize and package the DMG locally (needs Developer ID + notary env)
[group("ship")]
release-local:
    ./Scripts/release.sh

# Remove build and release outputs
[group("dev")]
clean:
    rm -rf dist TestResults.xcresult
