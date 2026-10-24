# Working on Mitsu

Read README.md, docs/AGENT_CONTEXT.md and docs/ARCHITECTURE.md before changes. This is a native iPad app, not a website. Preserve SwiftUI/RealityKit/Metal/CoreBluetooth; avoid adding a backend or package dependency without a reason tied to the user's request.

## Build and verify

- Project: app/Mitsu.xcodeproj, scheme Mitsu. XcodeGen source of truth: app/project.yml.
- Preview requires no car, credentials or location. Use --preview --day or --preview --night launch arguments, or enable Simulated preview in Settings. Optional --weather=rain/snow/cloud/fog/clear controls illustrative Preview weather.
- Run sh tools/check.sh for core/policy/body/control/Python/hygiene checks. Body and control tests each intentionally exercise a real20second deadline.
- Run an unsigned simulator build as documented in docs/BUILD.md. Never call a build/test a real-car validation. No iPad/device identifier is prescribed.
- When modifying views, check portrait, landscape, day/night, accessibility hit targets and Reduce Motion on a simulator/device. Runtime UI automation can fail independently of compile success; report the distinction.

## Public defaults and personal setup

Keep DEVELOPMENT_TEAM blank and generic bundle IDs in the distributed project. Use your user's team locally; ask for unavailable account/device actions instead of borrowing the original author's signing. No client secrets are needed. Enter a Spotify Client ID on-device if appropriate; preserve tokens only in Keychain.

VehicleIdentity.local.json is deliberately absent and ignored. Missing/malformed profile must reject experimental body/preferences records. Do not substitute the synthetic DiagnosticFixtures values as a real profile. Review the specific user's local identity evidence and applicable definitions before configuring anything. Never put identity reports or a local profile into Git.

The bundled car is original procedural geometry. Optional Outlander2014.usdz is ignored and must be supplied with suitable rights. Don't re-download or redistribute a mesh simply because it is free to download. Native articulation tests use authored fixtures and must not require that optional asset.

## Vehicle invariants

- Default to Preview and offline tests. Only initiate Bluetooth discovery or vehicle requests with the human's explicit authorisation for that session.
- Keep Preview isolated from actual radio/telemetry; unknown is not false, off or closed.
- Keep tools/ReadPolicy.swift restrictive. No arbitrary CAN/PID/address sweeps, monitor modes, security access, session entry, resets, coding or actuator services.
- Preserve coherent acknowledged route/format/filter/flow-control state, exact responder/service/identifier validation, one request at a time and stop on uncertainty.
- Every manual check goes through DiagnosticSession.enqueue; don't expose mutable pending flags.
- Experimental captures require fresh zero speed + parked confirmation to start, bounded continuation, cancellation and20second deadline. Only publish reports after engine-route restoration. Transport/configuration/restore failure disconnects.
- Climate version matching permits raw applicability reads, not confirmed hardware support or setting writes. A customization snapshot is not a full ECU backup. A damper override is not a temperature setpoint. A door-open switch is not a lock-position sensor.
- Do not enable actions without explicit user scope and exact protocol, acknowledgement, operating-condition, expiry and release-on-Bluetooth-loss evidence. No such actions are implemented here.

## Privacy and completion

Run python3 tools/audit_public.py before sharing changes. It is a heuristic check, not a guarantee. Manually inspect new fixtures, screenshots, binary metadata and third-party licences. Exclude build output, captures, local configuration, account data and downloaded OEM packages. Never print secrets in reports.

Preserve unrelated edits. State what changed, what was actually tested and what still needs a human/device. Do not claim live features based on simulated values, static definitions or a successful compiler run.
