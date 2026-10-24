# Architecture and customization

## Structure

| Area | Responsibility |
|---|---|
| app/Mitsu/MitsuApp.swift | App lifecycle, root view and development launch arguments |
| DashboardStore.swift | UI state, source-qualified snapshots, preview data and coordination |
| Views/ | Native cockpit, navigation, map, music, trips, settings and parked test kit |
| Scene/ | RealityKit vehicle, camera gestures, localized environment and Metal fade/precipitation |
| Connection/BluetoothClient.swift | User-selected BLE discovery, observed KW906 channel, prompt framing, command cancellation/timeouts |
| Connection/DiagnosticSession.swift | Supported-PID discovery, serialized polling and guarded manual checks |
| Core/ | Foundation framing/decoding, route policy helpers, freshness, trips, OAuth validation and capture reports |
| Services/ | Weather, optional location, Spotify, Keychain and local trip persistence |
| tools/ReadPolicy.swift | Shared explicit read/route allowlist used by app and tests |
| app/project.yml | XcodeGen target/resource/signing specification |

There is no server. Spotify and weather use the providers directly. Trips, profiles, reports and authorisation state are local to each installation.

## Make it yours

Start with Views/Theme.swift for palette, typography and press feedback, then DriveView.swift and DashboardView.swift for cockpit composition. Keep one persistent scene across resizing; rebuilding it on orientation changes loses camera state and can cause layout jumps. Test wide and tall layouts. Live freshness uses a current monotonic clock rather than a cached UI tick, which avoids newly received values flickering out.

OutlanderModel.swift builds the original procedural illustration. OutlanderAsset.swift optionally loads a locally supplied USDZ; VehicleBodyRenderer.swift discovers named parts to animate. See MODELS.md. No model changes should infer unsupported telemetry.

WeatherService.swift contains public city shortcuts and explicit area selection. LocationService.swift asks for optional approximate iPad position. A chosen weather area is not presented as the vehicle's GPS. Weather information expires rather than being invented offline.

Core/Telemetry.swift defines signals, source tags and TTLs. Standard OBD values require supported-PID discovery, exact response validation and source/freshness checks. Resources/Signals.json is a descriptive catalogue of candidates, not an assertion that a connected car supports them. Add or change a signal only with appropriate protocol evidence and tests; don't turn a candidate list into automatic scans.

## Diagnostic flow

User chooses adapter → observed BLE service/characteristics → ELM identity/voltage preflight → acknowledged formatting/protocol/engine route → supported PIDs → sequential live engine polling.

Manual operations are admitted atomically through enqueue. Body/climate captures pause polling, validate identity and documented routes, enforce a deadline and parked continuation, then restore the engine route. Any transport/configuration/restore failure disconnects. No arbitrary command field exists.

The body's local identity profile is intentionally empty in a public checkout. It is separate from the public read definitions. Native/synthetic tests inject invented acceptance values; those values must never become a real profile.

## Tests

Foundation tests cover parsers, source isolation, freshness, history, routes, cancellation and guard behavior. Native tests exercise UIKit/RealityKit integration and admission. The optional-model renderer is tested using tiny original synthetic geometry, so the public build does not depend on an unlicensed asset. UI tests cover navigation, orientations, themes, preview isolation and scene interactions. Passing any of these does not validate a user's live car.
