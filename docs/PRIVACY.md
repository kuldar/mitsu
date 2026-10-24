# Privacy and sharing

The public source starts without credentials, selected Bluetooth devices, a local controller profile, a chosen weather area, location history, trips, Spotify tokens, provisioning profiles or Xcode account state. Generic bundle IDs are placeholders. Public city presets are examples and aren't a user's position.

The app has no project backend or analytics SDK. It can still contact third parties when features are used: Open-Meteo receives a selected area, MapKit requests map/location services, Spotify receives authorised playback/account requests. Album artwork URLs may be downloaded after authorisation. Source licensing doesn't replace their service terms.

Trips and captures stay in the app's local container. Spotify access/refresh tokens are saved in Keychain with this-device-only accessibility. Weather area/cache and app preferences use UserDefaults. A user's own Local vehicle profile is packaged into their personal build; it must stay out of source distribution.

Captures and exports are not automatically uploaded. They can contain controller part/software bytes, raw replies, timestamps, physical-state notes and journey information. Other tools/changes could expose a VIN even though the parked body/climate captures request no VIN. Review the entire payload before posting; redact identifiers and observations, not just filenames. Never publish a device container, .xcresult, crash report, screenshot or raw diagnostic directory without inspecting it.

Git ignore rules reduce accidents; they don't erase tracked files or old Git history. tools/audit_public.py checks common risk patterns and prohibited artifacts and can be run before publishing, but it cannot prove no sensitive information exists. Review staged files with git diff --cached and the intended archive contents. If a credential was ever committed, remove it from history and revoke/rotate it with the provider; deleting the current file isn't enough.
