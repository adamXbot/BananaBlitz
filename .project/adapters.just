# Shared Apple signing settings: docs/apple-signing.md
# List available commands

test:
    xcodebuild test -scheme BananaBlitz -destination 'platform=macOS' -configuration Debug CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
