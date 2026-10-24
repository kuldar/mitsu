# Verification status — 24 October 2026

This source snapshot was copied to a different local directory and checked without the private checkout's model, signing, configuration, captures or OEM packages.

## Passed

- Foundation core:54/54 assertions, including empty/malformed local vehicle profiles and complete synthetic identities.
- Native Swift read-policy/route assertions: permitted exact documented reads and rejected state-changing/arbitrary commands.
- Body/control capture standalone suites: synthetic identities, exact gates, malformed replies, archive/export, cancellation, parked/deadline/restore guards and actual20second in-flight cancellation checks. The public default accepts no body/preferences identity profile.
- Python:12tests, including parser/analysis fixtures and public-source audit behavior.
- Relocated unsigned iPad simulator build-for-testing using Xcode27.0: app, native-test and UI-test targets compile without a downloaded USDZ, private evidence or development team.
- Public-source hygiene audit and independent private owner-identifier/asset-metadata inspection: no findings in intended release files. No generated output, local profile, secret/signing artifact or raw report belongs in the release.
- Independent review: no blocking code/privacy/asset-licence finding. Minor catalogue descriptions were corrected to distinguish adapter supply voltage and a manual manufacturer-specific steering snapshot from standard OBD readings.

## Not verified at runtime

The simulator native-test attempt stalled without test results; it was stopped. A subsequent direct preview launch failed because the local CoreSimulator service died. No passing native/UI runtime result or new screenshot is claimed for this public export. The native/UI tests compile and are provided for execution on a working simulator/device environment.

No physical iPad was installed, no Bluetooth scan/vehicle command was initiated, no live car compatibility was validated and no Spotify account sign-in/playback was tested during packaging. Provider policy/account eligibility and actual vehicle signals still need the next user's own validation. The included GitHub workflow has not run on a remote repository.

These checks don't promise support for every iPad, adapter or Outlander. Run the documented checks and Preview on your own setup before a parked, explicitly authorised real connection. The hygiene tool is heuristic, not a proof that future additions contain no private data.
