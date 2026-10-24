# Build and install

## Requirements

Use macOS with Xcode and its iOS SDK. Launch Xcode once to finish platform/tool setup and install an iPad simulator. This snapshot is verified with Xcode27.0 and targets iPadOS18+. It uses only Apple frameworks. Python3 is used for offline analysis/tests and the source-hygiene check; it is not an app runtime dependency.

Open app/Mitsu.xcodeproj, select the Mitsu scheme, select an iPad simulator and press Run. In Settings, enable Simulated preview. For repeatable launches, add --preview and --day (or --night) under Scheme → Run → Arguments. Optional weather arguments: --weather=clear/cloud/rain/snow/fog. The app does not automatically connect to Bluetooth at launch.

## Regenerate the project

A generated project is included for convenience. app/project.yml is the source of truth. Install XcodeGen if needed, then from the root:

```sh
brew install xcodegen
xcodegen generate --spec app/project.yml
```

The source tree and required resources must remain together; don't copy just the .xcodeproj. Project generation also detects a locally added optional model or local profile. Regeneration overwrites project-only signing edits, so either keep those local or set your own team/bundle IDs in your private fork's spec.

## Your iPad

1. Connect and trust the iPad in Xcode. Sign into your own Apple account in Xcode Settings → Accounts.
2. Enable Developer Mode on the iPad when Xcode requests it. Restart/confirm on the device if prompted.
3. Choose your iPad as the run destination. Under Signing & Capabilities, select your own Team and a unique app bundle identifier, such as a reverse-domain identifier you control. If tests need signing too, give their targets unique identifiers under the same team.
4. Build and Run. Follow any on-device developer-app trust prompt. Free personal provisioning can have limits and require re-signing; follow the current [Apple device setup instructions](https://developer.apple.com/documentation/xcode/running-your-app-in-simulator-or-on-a-device).

The Spotify callback scheme is independent of the bundle identifier; see docs/PROVIDERS.md before changing it. Do not commit a provisioning profile, certificate, Apple account state or your Xcode user data. There is no prebuilt IPA or shared signing identity in this repository.

## CLI builds and tests

```sh
sh tools/check.sh
xcodebuild -project app/Mitsu.xcodeproj -scheme Mitsu \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build/Simulator CODE_SIGNING_ALLOWED=NO build
```

List local simulator destinations with xcodebuild -showdestinations -project app/Mitsu.xcodeproj -scheme Mitsu. Run hosted unit tests using a simulator name/ID that actually exists on your Mac:

```sh
xcodebuild -project app/Mitsu.xcodeproj -scheme Mitsu \
  -destination 'platform=iOS Simulator,name=YOUR_IPAD_SIMULATOR' \
  -only-testing:MitsuUnitTests test
```

Use -only-testing:MitsuUITests for UI tests. The full scheme includes both suites; choose intentionally rather than accidentally starting a long UI run. A generic destination builds but cannot execute tests. Mac Catalyst development remains enabled; the primary target is iPad.

## Troubleshooting

- Signing fails: select your own Team and a unique identifier; nobody else's team is included.
- xcodebuild points at Command Line Tools: select the installed Xcode in Xcode Settings → Locations or use xcode-select with your own installation path.
- Missing model: the procedural default needs no USDZ. A malformed optional model will report an asset failure; remove your local file to return to the default.
- Missing textures: verify all Resources/Environment files are in the source tree and regenerate the project.
- Disabled vehicle check: Preview must be off, a real connection active, parked confirmation enabled and fresh speed exactly zero. A local profile is additionally needed for body/preferences records. Other queued/running checks reserve the test kit.
- A test timeout during UI automation is not proof of a failed vehicle connection; these are separate checks.
