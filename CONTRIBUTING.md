# Contributing

Fork, change and build the project with your own signing. Keep app/project.yml and the generated project in sync. Run sh tools/check.sh, an unsigned simulator build and relevant native/UI checks. Describe exact validation in a PR; compilation, simulator preview, device installation and actual parked-car behavior are different evidence levels.

Small visual improvements should preserve large tap targets, day/night contrast, portrait/landscape behavior, Reduce Motion and the existing single scene during rotation. Protocol changes need documented applicability, strict route/response checks, failure tests and preserved source/unknown semantics. Don't add automatic scans or unverified actions.

New recordings/fixtures must be invented or redacted; review actual IDs, coordinates, metadata, licence and raw bytes. Never attach a private device container, provisioning profile, local identity config or downloaded OEM definition package. Follow docs/PRIVACY.md and run the hygiene audit.

Use your own clear commit attribution. Original work is MIT; contributions should be compatible with that licence. Imported models/textures need their own explicit licence and attribution. Third-party trademarks and service accounts are not licensed by a code contribution.
