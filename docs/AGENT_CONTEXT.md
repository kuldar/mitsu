# Project context for a coding agent

Mitsu is a native SwiftUI iPad cockpit for a petrol2014/2015 Outlander, with a RealityKit/Metal scene, optional Spotify/MapKit/Open-Meteo services and a directly selected KW906 BLE link. Preserve the existing native app; don't rebuild it as a website.

The intended experience is a cohesive car instrument interface: restrained surfaces, strong type, large speed, an RPM strip, a persistent car scene, clear music/navigation and thoughtful portrait/landscape behavior. The scene shows a small ground area fading into the canvas, no sky/distant landscape, localized weather and a rotatable black car illustration. Weather is illustrative and no GPS is required for the scene.

This public distribution deliberately differs from the private development setup: generic/unsigned project defaults, an original procedural model instead of an unlicensed downloaded mesh, synthetic controller fixtures instead of captured identities, and no reports, OEM packages, device configuration, history or credentials. No personal test results or identifiers should be restored from elsewhere.

Read README.md for feature maturity, docs/BUILD.md for setup, ARCHITECTURE.md for code entry points, VEHICLE.md for parked captures, MODELS.md for optional geometry and PROVIDERS.md for account limitations. AGENTS.md contains the operational rules. Use the user's own signing and credentials only through their normal local/device flows.

Current state: engine signals rely on supported-PID discovery and freshness; body/light/indicator/door states remain unknown in real mode; climate data are raw candidate captures; normal climate/lock/light actions are unimplemented. Exact controller identity and safe read transport are not proof of signal meaning or actuator support. Continue protocol work with evidence and guarded physical comparisons, not arbitrary probes.

First useful task on a new machine: run the offline checks, build an unsigned iPad simulator app, launch with --preview --day and verify the cockpit/scene. Only then make the requested visual or feature changes. Run native/UI tests if the environment supports them and report actual coverage. Do not install on or connect to any physical device/car unless that user has asked for it.
