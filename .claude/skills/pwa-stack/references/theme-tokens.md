# Theme tokens & palette

Theming is a flat set of CSS custom properties in `frontend/src/theme/
variables.css`. Light values live on `:root`; dark overrides on
`.ion-palette-dark`. `lib/theme.ts` toggles that class and layers it over
Ionic's `@ionic/react/css/palettes/dark.class.css` (imported first in
`main.tsx` so our overrides win by source order). Generate this file from the
skill's colour/dark-mode/font answers.

## Token roles

Ask for a small set, derive the rest.

| Token | Role | Derive from |
|---|---|---|
| `--bg` | app background | asked (surface tone) |
| `--surface` | cards, rows, sheets | near-white (light) / lifted charcoal (dark) |
| `--hairline` | borders, dividers | a hair darker/lighter than surface |
| `--ink` / `--ink-2` / `--ink-3` | text: primary / secondary / tertiary | high→low contrast on `--bg` |
| `--accent` | brand / primary action | asked |
| `--accent-d` | pressed/shade of accent | accent darkened (light) / lightened (dark) |
| `--accent-bg` | tinted accent background (active pills) | accent mixed into surface |
| `--danger` / `--warning` / `--success` | status | conventional or brand-tuned |
| `--surface-2` | done/muted surface | between bg and surface |
| `--skeleton-a` / `--skeleton-b` | shimmer stops | two close bg-adjacent tones |
| `--shadow` / `--shadow-raised` | elevation | soft ink-tinted (light) / deep black (dark) |
| `--sp-1..6` | 4/8/12/16/24/32 spacing scale | fixed |
| `--dur-fast`/`--dur-med`, `--ease`, `--ease-pop` | motion | fixed |
| `--content-max` | max content width on wide screens | ~680px |

## Ionic bridge (do not skip)

Map the brand tokens onto Ionic's variables so every Ionic component re-skins:

```css
:root {
  /* brand tokens above, then: */
  --ion-background-color: var(--bg);
  --ion-text-color: var(--ink);
  --ion-font-family: "<body font>", system-ui, sans-serif;
  --ion-color-primary: var(--accent);
  --ion-color-primary-rgb: <r,g,b of accent>;      /* Ionic needs the rgb triplet */
  --ion-color-primary-contrast: #ffffff;
  --ion-color-primary-shade: var(--accent-d);
  --ion-color-primary-tint: <accent lightened>;
  --ion-color-success: var(--success);
  --ion-color-warning: var(--warning);
  --ion-color-danger: var(--danger);
  --ion-border-color: var(--hairline);
  color-scheme: light;
}
.ion-palette-dark {
  /* dark values of the same tokens, then re-map --ion-* including
     --ion-background-color-rgb, --ion-text-color-rgb, --ion-toolbar-background,
     --ion-item-background */
  color-scheme: dark;
}
```

`--ion-color-primary-rgb` and the `*-rgb` companions must be the comma-separated
channel triplet (Ionic composes rgba() from them) — a hex value breaks opacity.

## Component classes

Snippets and generated pages use a neutral `ui-` class prefix (`ui-row`,
`ui-card`, `ui-skeleton`, `ui-loading-bar`, `ui-task`, `ui-check`, `ui-slide`,
`ui-form`, `ui-section-title`, …). Keep component styles in the same
`variables.css`, all reading from the tokens so they follow light/dark for free.
Rename the prefix per project if you like, but keep it consistent.

## Deriving the palette from answers

The skill asks for: **accent** (brand color), **surface tone** (warm / cool /
neutral and how light), **dark mode** (both / light-only / dark-only), and
**fonts**. From those:

1. Build `--bg`/`--surface`/`--hairline` from the surface tone (a warm tone
   nudges greys toward brown; cool toward blue-grey).
2. Build the ink ramp for AA-legible text on `--bg`.
3. Derive `--accent-d`, `--accent-bg`, and the `-shade`/`-tint`/`-rgb` from the
   accent.
4. If dark mode is enabled, produce the `.ion-palette-dark` overrides: charcoal
   surfaces in the same hue family, a slightly brighter accent (dark backgrounds
   mute saturation), and black-based shadows. If light-only, omit the dark block
   **and** don't import Ionic's dark palette; if dark-only, invert.
5. Set `--bg` light/dark into three places that must agree:
   `theme/variables.css`, the `<meta name="theme-color">` tags in `index.html`,
   and `THEME_COLOR` in `lib/theme.ts`. Set the manifest `theme_color`
   (usually the accent) and `background_color` (the light `--bg`) in
   `vite.config.ts`.

Sanity-check contrast (ink on bg, accent-contrast on accent) at ~AA before
finishing. Keep the light and dark palettes the same hue family so the app reads
as one brand across modes.
