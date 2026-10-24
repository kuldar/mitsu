# Vehicle models and environment assets

## Included default

OutlanderModel.swift authors a black Outlander-inspired procedural illustration using RealityKit meshes. It has no downloaded vehicle textures or external mesh dependency. OutlanderAsset caches/clones it, so the same orbit/zoom/weather scene works immediately after cloning this repo. It isn't OEM CAD or a dimensionally verified vehicle model. Its wheels move illustratively and headlight beams can illuminate; it does not have independently articulated doors or emissive indicator/lamp groups.

The detailed community model used in private development is excluded: a free download without an explicit adaptation/redistribution licence is not enough to include it in a public source repository. Its archive, converted USDZ, mesh-derived screenshots and source-specific converter are not part of this distribution.

## Optional model you have rights to use

Supply a correctly scaled, triangulated, rights-cleared USDZ at app/Mitsu/Resources/Outlander2014.usdz, regenerate the project and rebuild. The filename is historical; the actual supplied geometry is your choice. It is ignored by Git by default. If you deliberately publish a different licensed asset, include its licence/credit and adjust the ignore rule intentionally.

Units are metres. The default illustration is roughly4.65m long,1.8m wide, ground at y=0, front towards negativeZ. For renderer compatibility, use:

| Names | Behavior |
|---|---|
| wheel_FL, wheel_FR, wheel_RL, wheel_RR | Rotate around their localX axis from rest for illustrative speed |
| door_FL, door_FR, door_RL, door_RR | Rest-relative localY hinges; position origin at hinge, include window/trim/mirror in the group |
| tailgate | Rest-relative localX hinge |
| Lamp_lowBeam, Lamp_highBeam, Lamp_frontFog | Descendant mesh materials receive appropriate emission |
| Lamp_indicatorLeft, Lamp_indicatorRight | Preview-only illustrative blinking; no invented live phase |
| Lamp_brake, Lamp_positionLights, Lamp_reverse | Mesh emission for supported source-qualified values |

Names after Lamp_ must match BodySignal raw values; inspect VehicleBodyRenderer for exact current support/colour behavior. Missing named parts are skipped gracefully. The mere presence of a custom file does not prove its articulation works. Native renderer tests use original synthetic panels and lamps, not a downloaded model. Check the local model's licence, geometry, performance and actual visual behavior yourself.

## Environment

The small ground area, marks, verge and rain/snow fade into the UI. HDR maps provide illumination/reflections, never a visible sky. All eight bundled textures/HDR files are CC0 Poly Haven assets listed in THIRD_PARTY_NOTICES.md. They are sufficient offline; there is no asset-download step. No entire source panorama library or proprietary OEM data ships.
