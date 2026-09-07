# View Assist

Only **our** assets are tracked. Upstream views are managed by the View Assist
updater and would be overwritten on the next release anyway.

Tracked: `view_assist/views/stocks/`, `view_assist/dashboard/user_dashboard.yaml`.

## Surviving dashboard updates

The View Assist updater preserves exactly one key of the live dashboard:

```python
new_dashboard_config["views"] = old_dashboard_config.get("views")
```

Everything else — including the whole `button_card_templates` block — is
replaced by upstream. Our night-mode icon colour lives in
`button_card_templates.icon_template`, so it is destroyed by every update.

`backup_existing` is accepted by `assets/dashboard.py` but **never used**, so
Home Assistant's "backup before update" toggle is a no-op for the dashboard.

The supported escape hatch is `view_assist/dashboard/user_dashboard.yaml`,
re-applied by `_apply_user_dashboard_changes()` after every update. It is a
**dictdiffer patch spec**, not a config fragment:

```yaml
change:
  - path: button_card_templates.icon_template.styles.icon.1.color
    orig: white
    updated: |-
      [[[ ... ]]]
```

Verified working through the 1.3.2 → 1.4.0 update: `8B1A1A` vanished from
`dashboard.yaml` (upstream overwrote it) but survived in the live store.

**Failure mode:** if a future release reorders `styles.icon`, the patch
silently no-ops and the icons revert to white. That is the symptom to look for.

## Custom views are never touched

Views only update if they exist in the upstream repo. `stocks` does not, so it
is never a candidate. Only `clock` has an update entity here.

## Stocks view

`stocks.yaml` — 30/70 split, portfolio stats left, chart right. Chart depends
on which state you are in:

- `chart_home.buttoncard.yaml` — **current**: candlesticks, hand-rolled on
  ApexCharts inside a button-card custom field
- `chart_home.apex.yaml` — stacked-area fallback using apexcharts-card
- `chart_home.candles.yaml` — the attempt that failed, kept as a record

### Why candlesticks are hand-rolled

`apexcharts-card` **hard-rejects** candlestick at load:

```js
ChartCardChartType: union(lit("line"), lit("scatter"), lit("pie"),
                          lit("donut"), lit("radialBar"))
```

The `apex_config` back door does not help either — the card's series builder
and y-axis autoscaling assume scalar y values, and candles need
`y: [open, high, low, close]`.

The workaround: `apexcharts-card` does `globalThis.ApexCharts = vs` when its
bundle loads, so the **library is on `window` for free**. We drive it directly.
No CDN, no second download, works offline, tracks whatever version HACS has.

Injection uses a 1×1 transparent GIF data-URI with an `onload` handler —
button-card sets custom-field HTML via `innerHTML`, and `<script>` tags do not
execute that way.

### Data

`sensor.robotray_ohlc` — REST sensor against RobotRay's `/api/portfolio/ohlc`.
Recorder-excluded; the candle array rides in an attribute.

**Weekly, not daily**, and deliberately: of 52 daily periods only 10 were
non-synthetic. Early history logged ~1 sample/day, and weekends are flat by
definition. Weekly gives 8 real candles out of 9. Switch by editing
`interval=` in the `robotray_ohlc_url` secret — no config change needed.

Use `sensor.robotray_daily_pnl_2`, **not** `sensor.robotray_daily_pnl` — the
unsuffixed one is an orphaned template sensor and is permanently unavailable.
