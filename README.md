# homeassistant-custom

Reproducible configuration for a Home Assistant OS install. Tracks **only**
hand-written config and custom assets — never secrets, never state, never
anything HACS or the Supervisor already manages.

## What this is for

Rebuilding this instance from scratch, and knowing *why* each piece is the way
it is. Several things here look odd until you know the history; that history is
in `docs/`.

## Layout

```
configuration.yaml          core config; all credentials via !secret
automations.yaml            automations
scripts.yaml                scripts
groups.yaml                 groups
customize.yaml              entity customisation
known_devices.yaml          retired legacy device_tracker store (kept empty)
bedside.yaml                YAML-mode dashboard for the bedside iPhone
themes/bedside/             pure-black theme for the bedside kiosk
view_assist/                our custom View Assist assets only
secrets.yaml.example        every !secret key, placeholder values
disk_report.sh              read-only disk diagnostics
cleanup.sh                  interactive reclaim (prompts before each delete)
echo_net_watch.sh           ICMP/port watchdog for a flaky device
docs/                       the reasoning behind all of it
```

## Restore procedure

1. Install Home Assistant OS.
2. Install HACS. Then, from HACS, install:
   - **Frontend**: button-card, mushroom, card-mod, layout-card, apexcharts-card,
     auto-entities, mini-graph-card, advanced-camera-card
   - **Custom repository** (not in the default store):
     `https://github.com/NemesisRE/kiosk-mode` — category Dashboard.
     The original `maykar/kiosk-mode` is archived (2022); use the fork.
     v14.0.0+ is the build for HA 2026.6 and later.
   - **Integrations**: View Assist, Alexa Media Player, Watchman, browser_mod
3. Install add-ons: Piper, Speech-to-Phrase, openWakeWord, Mosquitto, MariaDB,
   Z-Wave JS, ESPHome, Cloudflared, NGINX Proxy Manager, Advanced SSH.
4. Clone this repo over `/config`.
5. `cp secrets.yaml.example secrets.yaml` and fill in every value.
6. Recreate the helpers that live in `.storage` and are therefore not tracked:
   see `docs/helpers.md`.
7. Restart Home Assistant. Check the log before assuming success.

## Ground rules

- **Never commit `secrets.yaml` or `.storage/`.** `.gitignore` is a whitelist
  (deny-by-default) specifically so this cannot happen by accident.
- `.storage/` holds auth tokens, refresh tokens, OAuth credentials and every
  integration's API keys in plaintext. It is not, and must not become, tracked.
- HACS-managed code (`custom_components/`, `www/community/`) is deliberately
  untracked — HACS reinstalls it and tracking it would only create conflicts.

## Documentation

| Doc | Covers |
|---|---|
| `docs/bedside-dashboard.md` | The iPhone kiosk clock, night mode, tennis logic |
| `docs/view-assist.md` | Stocks view, candlesticks, surviving VA updates |
| `docs/automations.md` | Presence, lighting, the failures behind the fixes |
| `docs/infrastructure.md` | Network, disk, voice pipeline |
| `docs/helpers.md` | UI-created helpers that must be recreated by hand |
