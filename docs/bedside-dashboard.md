# Bedside dashboard

A dedicated Home Assistant dashboard for an **iPhone 15** (`iPhone15,4`,
852×393 landscape) used as a bedside clock, running the companion app's
**iOS Kiosk mode**.

Files: `bedside.yaml`, `themes/bedside/bedside_black.yaml`.
Registered in `configuration.yaml` under `lovelace: dashboards:`.

## Why the URL path has a hyphen

The dashboard is `/bedside-clock`, not `/bedside`. Home Assistant rejects YAML
dashboard keys without one:

```
Invalid config for 'lovelace': Url path needs to contain a hyphen (-)
```

`ha core check` reports this as `Successful config (partial)` in its summary
line — you have to read the full output to see the actual error.

## Layout

Fixed viewport, no scrolling. `layout-card` grid pins every element to a
fraction of the screen:

```
"clock  top"      22%     clock/date/weather   |  status chips
"clock  lights"   40%                          |  light chips
"market lights"   38%     market (tappable)    |
   58%              42%
```

Most modern HA cards assume a scrolling responsive layout. A fixed kiosk
display needs exact geometry, which is why `layout-card` wraps everything and
the clock is a `button-card` — Mushroom cannot render a 122px font cleanly.

The clock re-renders off `sensor.time_date` via `triggers_update`. Without
that it freezes until some other referenced entity changes.

## Night mode

`input_boolean.bedside_night_mode` is the single source of truth. Both the
22:00/08:00 schedule and the moon/sun chip write it; a second automation reacts
to the boolean. The schedule never touches the phone directly, so the timer and
the button cannot disagree.

At night:

| | Day | Night |
|---|---|---|
| Screen brightness | 100% | 2% (`kiosk_set_brightness`) |
| Volume | 60% | 15% (`kiosk_set_volume`) |
| Palette | white on black | `#8B1A1A` on black |
| Tennis ball | shown when dry | hidden |

Brightness accepts 0–100; **0 may blank the screen**, so 2 is the floor in
practice. If that is still too bright, iOS *Accessibility → Display & Text Size
→ Reduce White Point* dims below the hardware minimum.

**Kiosk commands are ignored while the app is backgrounded or closed.** If the
phone is picked up and left on another app, night mode will not apply until
Home Assistant is in the foreground again.

## The grey that would not go away

Early versions fought grey tile backgrounds with per-card `card_mod`. The grey
was never the cards — it was Home Assistant's **default dark theme**:

```
--primary-background-color: #111111   the gaps between tiles
--card-background-color:    #1c1c1c   behind each card
```

`card_mod` can restyle a card but can never reach the *view* background.
`themes/bedside/bedside_black.yaml` sets the variables at source instead.

A second trap: `configuration.yaml` had **no `frontend:` block**, so the
`themes/` directory was never loaded at all. Adding

```yaml
frontend:
  themes: !include_dir_merge_named themes
```

is what makes any theme file readable. Themes are startup-only — a browser
refresh will not pick up a theme change, only a restart will.

## Tennis ball

Shows when it has not rained for 5h and none is forecast for 5h.

- `sensor.lluvia_ultimas_5h` — `history_stats` over `weather.forecast_home`
- `sensor.lluvia_proximas_5h` — trigger template calling `weather.get_forecasts`
- `binary_sensor.tenis_ok` — both zero

Two design notes worth remembering:

**The forecast sensor must be trigger-based.** Met.no dropped the old
`forecast` attribute; hourly data only comes from the `weather.get_forecasts`
service, and state-based templates cannot call services.

**The verdict sensor must be state-based**, so it re-evaluates when either
input moves rather than only on a timer.

**Accuracy caveat:** there is no rain gauge. "Did it rain" is inferred from
Met.no's reported condition, which updates roughly hourly, so a short shower
between updates is missed. Fine for "is the court dry"; not a measurement.

## Header

The top bar is not removable from YAML. The companion app's *Hide sidebar and
top bar controls* hides the controls but leaves the view title. `kiosk-mode`
(NemesisRE fork) is the working answer; `bedside.yaml` already carries the
config block, inert until the plugin is installed:

```yaml
kiosk_mode:
  hide_header: true
  hide_sidebar: true
```
