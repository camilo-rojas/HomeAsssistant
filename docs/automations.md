# Automations

Notable fixes and the failures behind them. Most were silent — the automation
looked correct and simply never fired.

## Presence: bedroom lights on arrival

`Luz - Prender todas al llegar @ sunset-22h` (id `1558921639466`)

Triggers on `group.presence` going `off` → `on`.

**It had never fired once.** `group.presence` listed four members:

```
device_tracker.zte_blade_a3_lite   entity does not exist (0 states, ever)
binary_sensor.natalia_presence     entity does not exist (0 states, ever)
sensor.ana_status                  a sensor holding "Home"/"Away" text
sensor.ada_status                  same
```

Two ghosts, and two plain sensors whose text state cannot map to on/off. The
group reported `unknown` permanently, so `from: "off"` could never match.
Camilo's own tracker was not even a member.

Rebuilt as `person.camilo` + `person.natalia` — `person.*` maps `home` → on and
anything else → off, which is the semantics the automation wants.

The window was also changed from a fixed `16:00–23:00` to `after: sunset` +
`before: 22:00`.

## Estudio motion

`Presence - Setup Oficina` (id `1665710566998`) — entity id is
**`automation.sentado_estudio`**, not `automation.presence_setup_oficina`.
Home Assistant keeps the original entity_id when an alias is renamed. The
obvious guess from the alias will not resolve.

Two problems:

**The window ended at 20:00.** Walking in at 21:08 matched no branch, so
nothing ran. Extended to 22:00.

**The lamp was unreachable for most of the summer.** It required
`after sunset AND before 20:00`, and Miami sunset is 20:14–20:16 in June/July —
*after* the cutoff. An empty window from roughly May to early August:

```
Jun 21  sunset 20:15   lamp window = NONE
Aug 28  sunset 19:47   lamp window = 14 min
Dec 21  sunset 17:35   lamp window = 145 min
```

The inner check was an OR of (after sunset, before sunrise). The sunrise half
was dropped — Miami sunrise is 06:30–07:13 year round, always before the 08:00
floor, so it could never be true.

## Twins' room

`Luz - Cuarto ninas al llegar Ana o Ada` (id `1756428000000`) — new. Fires when
`person.ana` or `person.ada` reaches `home`, same sunset→22:00 window.

Both are driven by `input_select.mellizas_status_options`, so they always move
together; `mode: single` means one run, not two.

## Bedside night mode

Two automations, deliberately split:

- `1757260000000` — schedule only, flips the boolean at 22:00/08:00
- `1757260000001` — reacts to the boolean, pushes kiosk brightness + volume

The schedule never touches the phone. Both the timer and the dashboard button
go through the same path and cannot disagree.

## Reload gotcha

Editing `automations.yaml` does nothing until automations are reloaded. This
caused a fix to appear broken for two days: the file was modified at 21:38:48,
the last reload was 21:30:52 — eight minutes earlier. Home Assistant was still
running the old config.

Check with file mtime versus the last mass state-write on `automation.*`.

## Legacy device_tracker

`known_devices.yaml` is intentionally **empty with a comment**. Leaving it empty
stops the deprecated component recreating entries. `ana_tracker` and
`ada_tracker` moved to MQTT device trackers in `configuration.yaml`, named to
land on the same entity IDs so `person.ana` / `person.ada` kept working with no
re-pointing.

## Presence state machine drift

`input_select.camilo_status_options` sat on `Away` for 35 hours while
`person.camilo` was `home`. Both Movimiento automations gate on the input_select
rather than on `person.camilo` directly, so they fired and Telegrammed snapshots
of Camilo inside his own house.

Cause: `automation.presence_camilo_just_arrived` was **disabled**. The state
machine only moves one way — `just_left` and `is_away` were enabled, so
departures worked and arrivals were a dead end.

Restarts cannot repair this, and the history proves it:

```
Sep 6 08:22:53  ->  Away     (set by the automation)
Sep 6 17:20:20  ->  Away     (restart re-asserted it)
Sep 7 11:41:02  ->  Away     (restart)
Sep 7 12:13:18  ->  Away     (restart)
```

`input_select` is a restore entity — on startup it resumes its last option. And
every presence automation is state-*triggered* (`from: not_home, to: home`); a
restart produces no transition, so nothing re-evaluates. Arriving home while HA
is down loses the transition entirely.

**Fix:** `Presence - Sync Camilo status with person.camilo` (id
`1757300000000`) — triggers on `homeassistant: start` and every 12 hours, and
only writes on a genuine contradiction so the transitional `Just Left` /
`Just Arrived` states are left to run their course.

**Still worth doing:** add `person.camilo: not_home` as a second condition in
both Movimiento automations, so a stuck state machine cannot raise an alert on
its own.

## Bedside night mode

Two automations, deliberately split so the schedule and the dashboard button
share one code path:

- `1757260000000` — schedule only, flips `input_boolean.bedside_night_mode`
- `1757260000001` — reacts to the boolean, pushes kiosk brightness and volume

The brightness parameter is **`level`**, not `brightness`. The wrong name is
delivered and silently ignored — volume worked from the start because its
parameter genuinely is `volume`. Day 80%, night 2%.
