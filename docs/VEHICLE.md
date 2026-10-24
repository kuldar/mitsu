# Vehicle connection and parked captures

## Scope

This project targets the petrol2014/2015 Outlander family, not guaranteed support for every trim/market/year or PHEV. Standard OBD availability is discovered dynamically. Enhanced routes and conversions may differ even between visually identical cars. Don't connect to another person's car or peripheral without permission.

Use a compatible iOS BLE adapter. The current implementation expects a KONNWEI KW906 advertising the observed FFF0 service with FFF1 notification and FFF2 write characteristics. It verifies service/characteristic evidence rather than using arbitrary writable characteristics. Bluetooth Classic-only ELM327 devices won't work with this CoreBluetooth implementation.

## First connection

Park safely, selectP, apply the parking brake and close other OBD clients. Use Preview first. Turn Preview off, enable the parked confirmation, choose Find adapter and select your device. Grant Bluetooth permission when asked. Nothing connects automatically at launch or after backgrounding.

The adapter identifies an ELM channel, checks fresh supply voltage and establishes CAN11bit/500kbit protocol state. The conservative voltage preflight accepts12.0–15.5V; it isn't a calibrated battery-health test. Stop on unexpected vehicle behavior or a rejected preflight. Don't repeatedly retry uncertain operations or run an engine in an enclosed space.

Verify stationary speed/RPM and other supported readings against the factory instruments. Unsupported/stale data remain unavailable. A manually requested steering snapshot has an unverified conversion and is not continuous steering animation. Trips are local estimates based on available speed samples and coverage; they are not odometer truth.

## Experimental test kit

Vehicle → Lights & body has a controller identity check and labelled captures. Use the car's own physical controls for comparisons; the app does not operate them. Keep the observed state steady until engine readings resume. Reads are sequential and won't capture an indicator's exact flash phase simultaneously.

Body route620→504 uses identity1A87/1A9C before four raw data records2178,217A,217E,2173. Body/preferences data need an exact match against **your own local profile**. The public project includes no accepted owner identity. A mismatched/empty profile stops before the data records.

Climate candidate route688→511 uses two complete identity replies with agreeing family/version fields before seven raw records2134,2122,2123,2120,2121,2110,2111. Candidate versions0000–0004 only permit applicability research, not a verified hardware match or decoded live controls. The light/lock preference snapshot reads21B2 after exact body matching; it is not a complete ECU backup or rollback file.

Both captures require parked confirmation, a live connection and fresh zero speed to start. They enforce20seconds overall, bounded replies, one expected responder and matching identifiers, first-invalid stop and restoration before completion. Failures disconnect rather than resuming on an uncertain route.

### Configure your own body identity locally

1. Perform only the parked controller identity check initially; export the identity report locally.
2. Have a developer review the actual controller family/version and the applicable documented data records. Merely making the bytes match is not compatibility validation.
3. Copy examples/VehicleIdentity.example.json to app/Mitsu/Resources/VehicleIdentity.local.json. Put the reviewed complete uppercase response payload hex for1A87 and1A9C under expectedBodyIdentity. Use the decoded payloadHex values, not the padded CAN transcript. Do not put a VIN or unrelated IDs into it.
4. Regenerate the Xcode project and rebuild. The exact-match gate remains enforced. This file is ignored and must not be published. Never use the invented test fixture identity.

Absent/malformed profiles fail closed. No helper auto-accepts whatever ECU responds. Read-only captures remain explicitly unvalidated even with a matching local profile.

### Comparison session

Use a short baseline → one changed condition → restored baseline sequence. Label every capture. For body records compare low/high beams, each indicator, hazards, individual doors/tailgate and manual locked/unlocked states with doors closed. For manual lock checks, keep your key with you and a window lowered. A door-open switch is not a lock-position sensor. Do not move the vehicle or select reverse for this kit.

For climate compare panel temperature, one normal fan step, fresh/recirculate and outlet mode separately. A/C/demister requests or switches don't prove the compressor/heater is operating; some physical functions require an appropriate engine state. No engine start is needed merely to identify a controller.

Prepare/share each latest report if collecting manually; timestamped history is also saved in the app's Documents/Diagnostics. Treat the complete report as private until reviewed/redacted. Captures contain actual controller payloads, observations and timestamps.

## Controls status

Static research suggests diagnostic climate overrides and persistent customization preferences exist. None are enabled. There is no verified normal temperature-setpoint, immediate lamp, door-lock or window control command. Air-mix damper overrides, temperature calibration bias and normal thermostat control are distinct. A diagnostic stop definition does not prove automatic release if Bluetooth disappears. Extending actions requires exact protocol applicability, acknowledgement, operating conditions, expiry, dropout release and explicit user scope, not guessed service bytes.
