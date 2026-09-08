# Frontend gotchas

Things that cost real time to discover on this install. Each one failed
*silently* — no error in the log, no error on screen, just something that
didn't work.

## Inline event handlers do not fire

**The big one.** HTML injected into a dashboard via `innerHTML` — which is what
`button-card` custom fields do — has its inline handlers stripped:

```html
<img onload="...">     <!-- never fires -->
<div onclick="...">    <!-- never fires -->
```

Symptoms: a chart that renders nothing at all, a button that does nothing, and
*no error messages* — because every error path was inside the handler that
never ran.

Two working alternatives:

- **For clicks:** a real card with `tap_action`. A `mushroom-chips-card` nested
  inside a `custom_field` works; a panel view renders only one top-level card,
  so it has to be nested rather than a sibling.
- **For running code after injection:** schedule it from the template itself.
  The `[[[ ... ]]]` block is real JavaScript that definitely executes, so
  `setTimeout` plus a shadow-DOM walk finds the element:

```js
const findDeep = (root, sel) => {
  if (!root || !root.querySelectorAll) return null;
  const hit = root.querySelector(sel);
  if (hit) return hit;
  for (const el of root.querySelectorAll('*')) {
    if (el.shadowRoot) { const f = findDeep(el.shadowRoot, sel); if (f) return f; }
  }
  return null;
};
```

Guard re-renders with a signature stored on the element — the template re-runs
on every state update.

## Instrument before theorising

The chart above cost several rounds of guessing. What ended it was a diagnostic
rendered **outside** the failing code path:

```
field ok · pts=17 · apex=function
```

Three unknowns resolved in one screenshot: the field renders, the data is
there, the library is loaded. Everything I'd been theorising about was wrong.
**If something fails silently, make it print what it knows before changing it.**

## `height: 100%` collapses to zero

ApexCharts with `height: "100%"` renders into a zero-height box unless *every*
ancestor has a definite height. A layout-card grid cell does not qualify.

What works, copied from the View Assist stocks view:

```yaml
styles:
  card:  [{position: relative}]
  grid:  [{grid-template-rows: 100vh}]
  custom_fields:
    chart_home: [{position: absolute}, {top: 0}, {bottom: 0}]
```

`top: 0; bottom: 0` against a positioned parent is a definite height.

## Do not port `vh` units between devices

Sizing copied from the View Assist stocks view (600px-tall Echo Show) onto the
bedside iPhone (393px) produced 6px text. `1.5vh` is 9px on one and 5.9px on the
other. Use px for a known device.

## Wrong key names fail silently

Three separate times a plausible-looking key was simply ignored:

| Wrong | Right | Symptom |
|---|---|---|
| `brightness: 2` | `level: 2` | volume worked, brightness didn't |
| `play_pause` | `play_pause_stop` | two transport buttons instead of three |
| `--primary-text-color` | `--card-primary-color` | media text stayed white at night |

Nothing logs. Check the bundle for the accepted values:
`grep -oE '"(play_pause[a-z_]*|on_off|shuffle)"' mushroom.js`

## Style the inner container, not the host

Mushroom lays chips out inside `.chip-container`. Rules on the host element
(`mushroom-chips-card`) are ignored for wrapping and alignment:

```css
.chip-container { flex-wrap: nowrap !important; justify-content: flex-start !important; }
```

## Colour glyphs and images cannot be tinted

Emoji, album artwork and person photos carry their own colour — CSS `color`
does nothing. For night mode they are **hidden**, not recoloured:

- Emoji in calendar titles: stripped with a regex allowlist that keeps accents
- Album artwork: `mushroom-shape-avatar`, `.picture` hidden
- Person photos: same, name text kept so the chip still reads

## A panel view renders exactly one card

Adding a second card produces a banner — *"This view contains more than one
card, but a panel view can only show 1 card"* — and the extra card is never
rendered. Anything else has to be nested inside the first card, or wrapped in a
`vertical-stack` / `layout-card`.

## Grey is the theme, not the cards

`card_mod` can restyle a card but cannot reach the view background. Home
Assistant's default dark theme sets `--primary-background-color: #111111` and
`--card-background-color: #1c1c1c`. Fix it at the theme level.

And check `frontend:` exists at all — without

```yaml
frontend:
  themes: !include_dir_merge_named themes
```

no theme file in `themes/` is ever read. Themes are startup-only; a browser
refresh will not pick up a change.

## The companion app caches dashboards

A YAML dashboard edit that appears not to have applied is usually the app
serving a cached copy. Force it:

```yaml
action: notify.mobile_app_<device>
data:
  message: kiosk_reload
```

**Check the cache before concluding the config is wrong.** Verify what is on
disk first.
