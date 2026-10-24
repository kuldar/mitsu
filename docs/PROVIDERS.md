# Spotify, weather and maps

## Spotify: optional, experimental account integration

The app includes Authorization Code with PKCE, state/callback checks, renewable tokens in this-device-only Keychain storage, playback/device queries and play/pause/skip/device transfer. It controls an existing Spotify Connect playback device. It does not implement a music catalogue browser or streaming engine. No Client ID, client secret, account, token or sample commercial artwork is shipped.

Create your own app at the [Spotify developer dashboard](https://developer.spotify.com/dashboard) and review Spotify's **current** account, development-mode, redirect and Premium requirements. Enter only your Client ID in Mitsu's Music page. A Client ID is public configuration; do not enter or commit a client secret. Developer-app availability/access may differ between accounts.

The existing native callback is **com.example.mitsu://spotify-callback**. Source implementation uses this custom scheme, independently of your app's signing bundle identifier. It must exactly match the provider's registered redirect. The current [Web API redirect documentation](https://developer.spotify.com/documentation/web-api/concepts/redirect_uri) specifies HTTPS or explicit loopback redirects; it does not establish acceptance of this native custom scheme for a newly registered app. Consequently Spotify sign-in for new accounts is **not verified or promised**. If your dashboard rejects the scheme, a developer must implement a provider-supported native callback strategy (for example an appropriate supported SDK/universal-link arrangement), rather than substituting a random URL or disabling callback validation. The rest of the dashboard builds/works without Spotify.

Relevant source: Services/SpotifyService.swift, Services/KeychainStore.swift, Core/ProviderPolicy.swift, Info.plist and project.yml. If changing callback design, update registration, generated plist, callback/state validation and tests together. Start playback in Spotify on the desired phone/iPad first; audio reaches the car through that device's existing audio connection. This does not control FM, vehicle EQ or amplifier master volume.

References: [PKCE](https://developer.spotify.com/documentation/web-api/tutorials/code-pkce-flow), [redirect URIs](https://developer.spotify.com/documentation/web-api/concepts/redirect_uri), [playback endpoint](https://developer.spotify.com/documentation/web-api/reference/start-a-users-playback).

## Weather

Choose an area explicitly; the app sends that latitude/longitude to Open-Meteo. No API key is bundled. Current data are treated as fresh for30minutes, cached up to3hours and unavailable after that. Auto day/night uses usable sunrise/sunset or a local-time fallback. Preview weather is simulated. See [Open-Meteo](https://open-meteo.com/) for its current service terms and commercial-use requirements; the project's MIT licence doesn't license a third-party service.

## Map and optional position

MapKit provides its own attribution. Maps need network or cached tiles; offline downloads and turn-by-turn navigation are not implemented. You can browse without any active GPS position. Optional iPad location is approximate and expires; Wi-Fi-only location isn't reliable GNSS. Factory GPS extraction, phone GPS relay and detected road/obstacle perception are not implemented. Weather scenery is an illustration, not a camera/sensor reconstruction.
