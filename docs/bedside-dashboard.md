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

## Views

Eight, all `type: panel` with `theme: bedside_black`. Everything after the first
is `subview: true` so no tab bar renders.

| Path | Purpose |
|---|---|
| `/bedside-clock/home` | clock, weather, market, controls |
| `/bedside-clock/mercado` | portfolio stats + candlestick chart |
| `/bedside-clock/clima` | hourly + daily forecast |
| `/bedside-clock/estudio` | study: lights, perfume, presence, temp, echo |
| `/bedside-clock/cocina` | kitchen: echo, camera |
| `/bedside-clock/sala` | living room: temp, echo, receiver, camera |
| `/bedside-clock/ninas` | girls' room: light, blanket, TV |
| `/bedside-clock/cameras` | 2x2 live camera grid |

Every subview carries its own **Volver** chip — `kiosk-mode` hides the header,
so there is no other way back.

## Main view layout

Fixed viewport, no scrolling. `layout-card` grid pins every element:

```
"clock    persons"   15%     people chips (twins conditional)
"clock    top"       15%     ecobee / cameras / Ben / night toggle
"clock    lights"    15%     bedroom light chips
"weather  rooms"     15%     Estudio / Cocina / Sala / Ninas
"market   keydate"   16%     next calendar event
"market   media"     24%     Spotify
   50%       50%
```

Row heights are **sized from content**, not chosen by eye. Each group's leftover
space is roughly equal, which is what makes the vertical gaps look even. An
earlier version had the market cell carrying 113px of slack against the clock
cell's 6px, which read as badly unbalanced.

The clock is a `button-card` because Mushroom cannot render a 122px font
cleanly; everything else is Mushroom. The clock re-renders off `sensor.time_date`
via `triggers_update` — without that it freezes.

**The weather strip is its own card**, not part of the clock, purely so it can
carry a `tap_action` to the Clima view. Same for the market block and Mercado.

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

## Mercado

Direct port of the View Assist stocks view — root `button-card`, absolutely
positioned chart panel, hand-rolled ApexCharts candlesticks. See
`docs/view-assist.md` for why candlesticks cannot use `apexcharts-card`, and
`docs/frontend-gotchas.md` for the height and inline-handler traps that made
this take several attempts.

The x-axis is **category**, not datetime: a datetime axis leaves a visible gap
for every weekend and holiday. Category spacing draws only the candles that
exist. Holidays are already dropped upstream by the zero-range filter, since no
trading means `open == high == low == close`.

## People chips

`person.camilo` and `person.natalia` always render; Ana and Ada use Mushroom's
`conditional` chip and appear only when `state: home`.

Photos come from `entity_picture`. Mushroom has no per-chip text colour, so the
name is coloured positionally in `card_mod`:

```css
.chip-container > *:nth-child(1)    /* Camilo  */
.chip-container > *:nth-child(2)    /* Natalia */
.chip-container > *:nth-child(n+3)  /* always green - conditional chips only
                                       render when home */
```

Photos are hidden in night mode - they cannot be tinted red.

## Key date

`calendar.key_dates` exposes the next upcoming event directly in its
attributes (`message`, `start_time`), so no `calendar.get_events` call is
needed - unlike the weather forecast, which does require one.

Emoji are stripped from the title with an allowlist regex that preserves
Spanish accents: `[^A-Za-zÀ-ÿ0-9 .,:()\-'&/]`.
