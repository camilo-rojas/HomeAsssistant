# Helpers not in this repo

These live in `.storage/`, which is never tracked. After a rebuild they must be
recreated by hand or the dashboards and automations will fail.

## Created via YAML (already in this repo)

Defined in `configuration.yaml`, so they come back automatically:

- `light.cuarto_principal` — light group over the three bedroom lights
- `input_boolean.bedside_night_mode` — night mode source of truth
- `sensor.lluvia_ultimas_5h`, `sensor.lluvia_proximas_5h`, `binary_sensor.tenis_ok`
- `sensor.robotray_*` — REST + template sensors
- `sensor.time_date` — required by the bedside clock

## Must be recreated manually

**Input selects** referenced by presence automations:
- `input_select.camilo_status_options`
- `input_select.mellizas_status_options`

**Person entities** and their device_tracker mappings:
- `person.camilo` → the iPhone's mobile_app tracker
- `person.natalia` → her iPhone
- `person.ana` → `device_tracker.ana_tracker` (MQTT)
- `person.ada` → `device_tracker.ada_tracker` (MQTT)

The twins' trackers come from the MQTT device_tracker block in
`configuration.yaml`; the entity IDs must match or `person.*` will not resolve.

**Dashboards** other than `bedside` (storage mode, so untracked).

**Long-lived access tokens** for anything that authenticates to HA.

## Recreate-then-verify

After rebuilding helpers, check for the failure mode that has bitten this
config twice: **groups whose members no longer exist**. Both `group.presence`
and `group.cuartoprincipal` sat at `unknown` for a long time because every
member entity had been renamed or deleted. A group with no valid members
reports `unknown`, never `off`, so any `from: "off"` trigger can never fire and
the automation fails silently.

Verify with Developer Tools → States that each group shows `on` or `off`,
never `unknown`.
