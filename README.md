# Mitsu

A native iPad dashboard for a petrol 2014/2015 Mitsubishi Outlander: a calm instrument display, a touchable 3D car, day/night lighting, weather, maps, trips and optional Spotify controls.

Built with SwiftUI, RealityKit, Metal and CoreBluetooth. No web wrapper, backend, package dependency or paid asset is required to build the app. This is an experimental enthusiast project, independent of Mitsubishi.

**You can build and explore it without a car, dongle, GPS or Spotify account.** Enable **Settings → Simulated preview**. Preview data is visibly marked and never connects to the car.

## Get running

1. Install Xcode and finish its first-launch setup. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen) if you want to regenerate the project (`brew install xcodegen`). A generated Xcode project is included.
2. Open `app/Mitsu.xcodeproj`, choose the **Mitsu** scheme and an iPad simulator, then Run.
3. In the app, select **Settings → Simulated preview**. Try day/night, weather, portrait/landscape, orbit and pinch-to-zoom.
4. To install on your own iPad, choose your own development team and a unique bundle identifier in **Signing & Capabilities**. No developer account or signing identity is bundled. See [Build & install](docs/BUILD.md).

The deployment target is **iPadOS 18+**. This export was compiled using **Xcode 27.0**; older Xcode/SDK combinations have not been verified for this snapshot. A physical iPad needs Developer Mode and personal signing. App Store distribution is not configured.

## What you get

- Integrated cockpit with large speed, RPM ribbon, engine details and persistent navigation/music controls.
- Original **procedural black car illustration**, touch orbit/zoom and localized weather over a ground surface that fades into the UI. The environment's HDR lighting never displays a sky.
- Explicitly selected KW906 Bluetooth LE connection, supported-PID discovery, sequential read-only polling, stale-data handling and safe disconnects.
- Local trips and export, an optional approximate location, a browsable map without GPS, and weather for an explicitly selected area.
- Optional Spotify account/playback code using PKCE and on-device Keychain storage. It controls an existing Spotify playback device; it does not stream audio itself. See [Spotify & providers](docs/PROVIDERS.md) for current limitations.
- A guarded parked test kit for experimental controller identity, raw body/climate records and a light/lock customization snapshot. Captures are not validated live body telemetry or car controls.
- Core, protocol, native and UI test sources; a portable verification script; agent context and contribution guidance.

## What is experimental

Standard readings depend on your ECU's supported PIDs. The app does not promise fuel range, gear, tyre pressures or any particular manufacturer's extended data. Engine values still need comparison against your own instruments.

Actual door/light/indicator states remain **unknown** in the real 3D scene. Climate records are raw research captures. There is no normal temperature-setting, lock/unlock, lighting command, window control, coding, reset or actuator interface. Steering is a manually requested parked wheel-angle snapshot with an unverified scale.

The detailed downloaded community car used during private development is **not included** because redistribution permission was not established. The original procedural car is included and the project works without the downloaded model. Door and lens animations require an optional correctly articulated model; the default illustration supports beam illumination and wheel motion. See [Models & assets](docs/MODELS.md).

## Bring your own car and configuration

Start with Preview. For a real connection, use a compatible iOS Bluetooth LE adapter, park safely, close other OBD clients and select your adapter explicitly. The implemented channel is based on a KW906 service/characteristic layout; other ELM-labelled devices are not automatically compatible. Read [Vehicle connection & captures](docs/VEHICLE.md) before connecting.

No original owner's VIN, Bluetooth device ID, signing team, accounts, captures or exact controller profile is included. A fresh install has no selected adapter, saved area, trips or Spotify session. Local data only appears after you use the app. City shortcuts in the weather picker are public examples, not the car's location.

## Customize it

Start at [Architecture & customization](docs/ARCHITECTURE.md). Coding agents should read [AGENTS.md](AGENTS.md) and [the handoff context](docs/AGENT_CONTEXT.md). A [starter prompt](docs/AGENT_PROMPT.md) is provided for someone who wants an agent to build and configure their own version.

```sh
# From the repository root on macOS
sh tools/check.sh
xcodebuild -project app/Mitsu.xcodeproj -scheme Mitsu \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build/Simulator CODE_SIGNING_ALLOWED=NO build
```

See [Publishing](docs/PUBLISHING.md), [Contributing](CONTRIBUTING.md), [Privacy](docs/PRIVACY.md), [Security](SECURITY.md) and [Verification status](docs/VERIFICATION.md).

## Licence

Original code, documentation, procedural geometry and shaders are **MIT licensed**. Modify, fork and redistribute them under that licence. Bundled Poly Haven environment assets are **CC0**, with sources in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). Brand names, third-party services and optional imported assets have their own rights and terms; the MIT licence does not grant those rights.
