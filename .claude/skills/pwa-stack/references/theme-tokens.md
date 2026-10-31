# Theme tokens & palette

Theming is a flat set of CSS custom properties in `frontend/src/theme/
variables.css`. Light values live on `:root`; dark overrides on
`.ion-palette-dark`. `lib/theme.ts` toggles that class and layers it over
Ionic's `@ionic/react/css/palettes/dark.class.css`, imported before project
styles in `main.tsx`. Match mode-specific selector specificity when overriding
Ionic's palette; source order alone is insufficient. Generate values from the
project's colour/dark-mode/font answers. Both skill entry points use this
reference alongside [the shared PWA structure](mobile-design.md).

## Contents

1. Token roles
2. Ionic bridge
3. Component classes and safe areas
4. Palette derivation

## Token roles

Ask for a small set, derive the rest.

| Token | Role | Derive from |
|---|---|---|
| `--bg` | app background | asked (surface tone) |
| `--surface` | cards, rows, sheets | near-white (light) / lifted charcoal (dark) |
| `--hairline` | borders, dividers | a hair darker/lighter than surface |
| `--ink` / `--ink-2` / `--ink-3` | text: primary / secondary / tertiary | high→low contrast on `--bg` |
| `--accent` | readable brand-colored text/icons | derived from the chosen brand, with contrast on its surface |
| `--accent-fill` / `--on-accent` | primary button fill / its foreground | chosen brand and a verified contrasting foreground |
| `--accent-d` | pressed/shade of accent | accent darkened (light) / lightened (dark) |
| `--accent-bg` | tinted accent background (active pills) | accent mixed into surface |
| `--danger` / `--warning` / `--success` | status | conventional or brand-tuned |
| `--surface-2` | done/muted surface | between bg and surface |
| `--skeleton-a` / `--skeleton-b` | shimmer stops | two close bg-adjacent tones |
| `--shadow` / `--shadow-raised` | elevation | soft ink-tinted (light) / deep black (dark) |
| `--sp-1..6` | 4/8/12/16/24/32 spacing scale | fixed |
| `--radius-sm` / `--radius-md` / `--radius-hero` | chips, grouped rows, hero surfaces | ~12/16/22px |
| `--tap-min` | minimum interactive target in either axis | `44px` |
| `--tab-height` / `--activity-dock-height` | custom bottom chrome geometry | fixed and safe-area-independent |
| `--glass-bg` / `--glass-border` | selective navigation/control glass | translucent surface / subtle hairline |
| `--safe-top/right/bottom/left` | overridable safe-area proxies for custom chrome | `env(safe-area-inset-*, 0px)` |
| `--font-ui` / `--font-content` | shared UI and content-language families | chosen fonts with system/script fallbacks |
| `--heading-font` | page-heading family | chosen font or `--font-ui` |
| `--dur-fast`/`--dur-med`, `--ease`, `--ease-pop` | motion | fixed |
| `--content-max` | max content width on wide screens | ~680px |

## Ionic bridge (do not skip)

Map the brand tokens onto Ionic's variables so every Ionic component re-skins:

```css
:root {
  /* brand tokens above, then: */
  --ion-background-color: var(--bg);
  --ion-text-color: var(--ink);
  --ion-font-family: var(--font-ui);
  --ion-color-primary: var(--accent-fill);
  --ion-color-primary-rgb: <r,g,b of accent-fill>;
  --ion-color-primary-contrast: var(--on-accent);
  --ion-color-primary-contrast-rgb: <r,g,b of on-accent>;
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
     --ion-background-color-rgb and --ion-text-color-rgb */
  color-scheme: dark;
}
.ion-palette-dark.ios,
.ion-palette-dark.md {
  --ion-toolbar-background: var(--bg);
  --ion-item-background: var(--surface);
  --ion-tab-bar-background: var(--surface);
}
```

`--ion-color-primary-rgb` and the `*-rgb` companions must be comma-separated
channel triplets. Keep the RGB, contrast, shade, and tint values consistent
with the actual fill in each theme. Replace illustrative values in angle
brackets before generating CSS.

The class-based dark palette sets some variables per platform mode. Use
`.ion-palette-dark.ios` and `.ion-palette-dark.md` for those bridge overrides;
inspect computed styles in both modes instead of assuming a later generic
selector wins.

## Component classes

Snippets and generated pages use a neutral `ui-` class prefix (`ui-row`,
`ui-card`, `ui-skeleton`, `ui-loading-bar`, `ui-task`, `ui-check`, `ui-slide`,
`ui-form`, `ui-section-title`, …). Keep tokens and shared component styles in
`variables.css`; feature styles can live in `theme/<feature>.css` while consuming
the same tokens and reusable components. Do not invent per-screen palettes,
button shapes, or spacing scales. Keep the prefix consistent throughout the app.

Do not turn `ui-card` into the default wrapper for every block. Generate
separate roles for a dominant hero, grouped rows, compact actions, empty/error
states, the transient activity dock, and navigation. Use spacing and type to
separate low-level content; reserve borders and shadows for actual containment.

Custom bottom chrome must compose its fixed geometry with the safe area rather
than baking an iPhone inset into a token:

```css
:root {
  --safe-top: env(safe-area-inset-top, 0px);
  --safe-right: env(safe-area-inset-right, 0px);
  --safe-bottom: env(safe-area-inset-bottom, 0px);
  --safe-left: env(safe-area-inset-left, 0px);
}

.ui-tab-shell {
  box-sizing: border-box;
  min-height: calc(var(--tab-height) + var(--safe-bottom));
  padding-bottom: var(--safe-bottom);
}

.ui-icon-button,
.ui-chip,
.ui-primary-action {
  min-width: var(--tap-min);
  min-height: var(--tap-min);
}
```

Assign one owner for each inset. Avoid applying custom proxy padding a second
time where an Ionic header, tab bar, or sheet already accounts for that inset.
`IonContent` does not automatically pad every safe area: standalone scroll
content without covering chrome may need explicit padding through the relevant
`--ion-safe-area-*` variable. Reserve space for any custom activity dock too.
Override custom proxy tokens with representative nonzero values in desktop
browser tests because Playwright WebKit does not emulate an iPhone notch or
home indicator; test Ionic-owned chrome through Ionic's own inset variables.

Use glass only on navigation or compact controls. Start with an opaque surface,
then enhance where supported:

```css
.ui-glass { background: var(--surface); border: 1px solid var(--hairline); }
@supports ((-webkit-backdrop-filter: blur(1px)) or (backdrop-filter: blur(1px))) {
  .ui-glass {
    background: var(--glass-bg);
    border-color: var(--glass-border);
    -webkit-backdrop-filter: saturate(140%) blur(18px);
    backdrop-filter: saturate(140%) blur(18px);
  }
}
```

Do not apply a second blur to an Ionic toolbar when `IonHeader` is already
translucent. Long reading surfaces, forms, and lists stay opaque.

## Deriving the palette from answers

The skill asks for: **accent** (brand color), **surface tone** (warm / cool /
neutral and how light), **dark mode** (both / light-only / dark-only), and
**fonts**. From those:

1. Build `--bg`/`--surface`/`--hairline` from the surface tone (a warm tone
   nudges greys toward brown; cool toward blue-grey).
2. Build the ink ramp for AA-legible text on `--bg`.
3. Derive `--accent-d`, `--accent-bg`, and fill shade/tint/RGB values from the
   brand. Verify text/link contrast separately from a filled button. Adjust the
   readable accent or fill as needed and derive `--on-accent` for each theme;
   white text is not automatically suitable for every brand color.
4. If dark mode is enabled, produce the `.ion-palette-dark` overrides: charcoal
   surfaces in the same hue family, a slightly brighter accent (dark backgrounds
   mute saturation), and black-based shadows. If light-only, omit the dark block
   **and** don't import Ionic's dark palette; if dark-only, invert.
5. Derive glass colors from `--surface`, then verify that opaque fallbacks and
   text contrast remain correct without `backdrop-filter`.
6. Set `--bg` light/dark into three places that must agree:
   `theme/variables.css`, the `<meta name="theme-color">` tags in `index.html`,
   and `THEME_COLOR` in `lib/theme.ts`. Set the manifest `theme_color`
   (usually the accent) and `background_color` (the light `--bg`) in
   `vite.config.ts`.

Check AA contrast for primary/secondary text on every used surface, readable
accent text, button foreground on its fill, and interactive boundaries in each
theme before finishing. Keep the light and dark palettes the same hue family so the app reads
as one brand across modes. Add a `prefers-reduced-motion: reduce` block that
removes decorative animation and replaces spring/pop transitions with near-zero
durations while preserving state changes.

## Sources for the Ionic bridge

Check current [Ionic color variables](https://ionicframework.com/docs/theming/colors),
[class-based dark palettes](https://ionicframework.com/docs/theming/dark-mode),
and [content safe-area padding](https://ionicframework.com/docs/api/content#safe-area-padding)
when adapting this bridge to a different Ionic version.
