# Shared Apple signing settings: docs/apple-signing.md
# List available commands

test:
    xcodebuild test -scheme BananaBlitz -destination 'platform=macOS' -configuration Debug CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

# End-to-end XCUITest suite. Ad-hoc signed (an unsigned runner is killed by
# macOS); its own scheme keeps it out of the shared CI's unsigned test run.
# Pass a filter to run one class or test, e.g. `just ui-test MenuBarUITests`.
ui-test selection="":
    rm -rf UITestResults.xcresult ui-screenshots
    xcodebuild test -scheme "BananaBlitz UI Tests" -destination 'platform=macOS' -configuration Debug -resultBundlePath UITestResults.xcresult CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO {{ if selection != "" { "-only-testing:BananaBlitzUITests/" + selection } else { "" } }}
    xcrun xcresulttool export attachments --path UITestResults.xcresult --output-path ui-screenshots
