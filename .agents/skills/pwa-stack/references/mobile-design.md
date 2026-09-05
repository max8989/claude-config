# Mobile product and UI blueprint

Use this blueprint before writing pages. Treat it as the default for an
iPhone-first app, then adapt labels and destinations to the product. Preserve
the hierarchy and interaction principles even when the domain is not a content
or learning app.

## Contents

1. Define the experience before the component tree
2. Build a stable, thumb-first shell
3. Give each core page a clear hierarchy
4. Make creation discoverable and guided
5. Use materials and motion selectively
6. Treat iPhone constraints as layout inputs
7. Confirm consequential actions and recover from failure
8. Separate interface language from content language
9. Preserve accessibility, offline behavior, and performance
10. Verify the design, not only the types

## 1. Define the experience before the component tree

Write a compact internal UI map containing:

- the primary object users browse or manage;
- the one repeatable action the app should make easiest;
- the state a returning user most often wants to resume;
- three to five stable root destinations;
- loading, empty, error, offline, and permission-denied states;
- destructive or session-ending actions that require confirmation; and
- the UI language, kept separate from the language or format of user content.

Do not start by distributing every feature into equal cards. Rank actions and
content first. One screen should have one unmistakable primary action.

## 2. Build a stable, thumb-first shell

- Use at most five permanent bottom destinations. A strong default for a
  creation-centered product is **Home**, the main collection, a centered and
  labeled **Create** action, the main activity/review destination, and
  **Profile**. Rename or remove destinations to fit the domain.
- Keep the tab count and positions stable. Never add a temporary sixth tab for
  playback, uploads, timers, or another transient activity.
- Show persistent activity in a compact mini-panel immediately above the tab
  bar. Make the whole panel reopen the activity and keep only its main control
  separately tappable.
- Keep the Create label visible under or beside its icon. Do not make a lone
  toolbar `+` the only way to create.
- Keep root routes distinct from pushed details and forms. Preserve normal back
  navigation on details; switching tabs must not build a confusing stack of
  previous tab roots.
- Fit the complete shell at 320 CSS px without horizontal clipping. Allow the
  tab label to remain readable at the user's text size.

## 3. Give each core page a clear hierarchy

### Home

Lead with an editorial greeting or status, then one dominant resume/continue
surface. Follow it with the next one or two useful actions, a compact progress
summary, and recent activity. Avoid a dashboard made entirely of equal emoji
tiles or same-weight bordered cards.

### Collection or library

Place a full-width, text-labeled creation CTA near the top and repeat it in the
empty state. Group owned content separately from shared, suggested, or public
content. Sort user-created content newest first unless the domain has a clear
reason not to. Use a strong title/meta hierarchy and sufficiently large visual
anchors; do not give every metadata value equal prominence.

### Detail

Show the title once as the page's primary heading. Do not repeat the same long
title in both the toolbar and body unless the toolbar title appears only after
the body title scrolls away. Keep primary consumption or editing content above
secondary metadata.

### Profile and settings

Use grouped settings rows with current values aligned as secondary text. Group
appearance, behavior, notifications, and account controls instead of stacking
many unrelated cards. Put sign out and other account actions in the Account
group.

## 4. Make creation discoverable and guided

- Expose a visible text CTA from Home, the main collection, and its empty
  state. Route every entry to the same create flow.
- Use a plain **add** icon for adding an object and a **compose/edit** icon for
  drafting one. Do not use sparkle, star, magic-wand, or similar “AI” imagery
  as the generic Create symbol, even when AI can assist the flow.
- Keep the visible label inside the accessible name. Mark a purely decorative
  icon `aria-hidden="true"`.
- For a multi-step creator, order the decisions as: choose input method;
  describe or paste content; choose only the essential settings; preview;
  save/publish. Put voices, visibility, destinations, and other infrequent
  controls in a clearly labeled advanced section.
- Use descriptive mode cards instead of ambiguous chips for materially
  different workflows such as Generate, Paste, or Manual.
- Keep the primary action reachable, but do not let a fixed or sticky action
  cover fields, validation messages, or the on-screen keyboard. Reserve space
  for it and test the smallest viewport with the keyboard open.
- Preserve entered work across back/forward navigation. Warn before abandoning
  a meaningful draft.

## 5. Use materials and motion selectively

- Build the visual language from tokens, typography, spacing, surface roles,
  and content hierarchy before adding effects.
- Use an ambient gradient or soft mesh only in a hero or brand moment. Keep
  reading, forms, and long lists on calm opaque surfaces.
- Apply glass to navigation or compact control chrome only. Provide an opaque
  fallback for unsupported `backdrop-filter`; do not stack a custom blur over
  Ionic's translucent header blur.
- Avoid outlining every card. Separate groups with spacing, tonal surfaces,
  dividers, or typography. Reserve borders and shadows for meaningful
  containment and elevation.
- Prefer CSS and SVG for decorative polish. Do not add Three.js, React Three
  Fiber, shader runtimes, DOM-sampling liquid-glass libraries, or animated-logo
  runtimes as a global UI dependency.
- If the product specifically justifies one WebGL decoration, lazy-load that
  isolated surface, cap device pixel ratio, set `pointer-events: none` and
  `aria-hidden="true"`, pause it while hidden or offscreen, handle context loss,
  and provide static and `prefers-reduced-motion` fallbacks. Keep it out of the
  initial route and account for its effect on Workbox precache/update transfer.

## 6. Treat iPhone constraints as layout inputs

- Use `width=device-width, initial-scale=1, viewport-fit=cover`. Never disable
  pinch zoom with `maximum-scale=1` or `user-scalable=no`.
- Include an explicit Apple touch icon and keep status/theme colors synchronized
  with the active theme.
- Respect `env(safe-area-inset-*)` around custom headers, sheets, floating
  controls, mini-panels, and bottom navigation. Do not add safe-area padding a
  second time where Ionic already owns it.
- Make every interactive target at least 44 by 44 CSS px, including chips,
  toolbar controls, seek controls, and icon-only actions.
- Let Ionic own translucent iOS header rendering. Avoid nested backdrop filters
  on the toolbar host; they can cause WebKit compositing and repaint failures.
- Use native Ionic button structure for toolbar actions. Verify that both the
  icon and visible label paint correctly in Mobile Safari and standalone mode.
- For custom full-height login, form, or sheet layouts, use a `100vh` fallback
  followed by `100dvh`; do not freeze them to legacy `100vh`. When the Visual
  Viewport shrinks, keep the focused field and primary action scrollable into
  view. Leave sizing to Ionic for Ionic-owned page/content containers.
- Test long labels, Dynamic Type/browser text scaling, the software keyboard,
  edge swipe, rotation if supported, and the home indicator.

## 7. Confirm consequential actions and recover from failure

- Route delete, remove, irreversible toggles, draft abandonment, and sign out
  through one app-wide promise-based confirmation component.
- Treat backdrop dismissal, swipe-down, Escape, and Cancel as `false`. Do not
  call the mutation or clear authentication until the user confirms.
- Use specific copy that names the item or consequence. Use destructive color
  only when the result is destructive; ordinary sign out can use the primary
  color unless local-only work will be lost.
- Give every query an error state with a clear retry action. Never leave an
  indefinite skeleton as the only result of a failed request.
- Pair optimistic state with rollback and a plain-language failure message.
  Disable duplicate submission while a mutation is pending.

## 8. Separate interface language from content language

Default application chrome to English unless the user requests another UI
language. In a multilingual product, use the selected UI language for page
titles, filters, selects, navigation, and metadata while leaving the actual
learning, media, or user-authored content in its source language.

- Store and return the canonical/original label and optional localized labels;
  do not overwrite one with the other.
- Preserve alternate labels in list, search, filter, and nested-detail API
  DTOs. A localized field that disappears in a narrow response will reappear
  as a source-language option in the UI.
- Centralize display selection in a pure helper. For an English UI, trim and
  prefer the English label, fall back to the transformed/original label, and
  show the original as secondary text only when it differs.
- Keep script/charset choices separate from `uiLocale`. A Traditional versus
  Simplified preference must not silently become an English versus Chinese
  preference.
- Keep editing forms bound to the raw fields, not to a computed display label.

## 9. Preserve accessibility, offline behavior, and performance

- Use real headings for section hierarchy, labels for every form control, and
  `aria-pressed` or a real segmented control for selectable modes.
- Keep visible focus, AA contrast, logical focus movement in dialogs, and a
  reduced-motion path. Never nest a button inside a link or another button.
- Prefer system or bundled/self-hosted fonts. If external fonts are explicitly
  chosen, give them robust fallbacks and verify cold/offline launch so text does
  not visibly change hierarchy.
- Lazy-load non-root pages and nonessential visuals. Track the initial JavaScript
  budget; a decorative dependency must not inflate every user's startup.
- Give visual tests deterministic static effects so screenshots do not depend
  on animation timing or GPU output.

## 10. Verify the design, not only the types

Generate component tests that prove:

- every creation entry has visible text and routes to the create flow;
- the empty state remains actionable;
- sign out and destructive actions do nothing before confirmation, cancel
  safely, and execute exactly once after confirmation;
- the create flow validates, prevents duplicate submission, preserves state,
  and exposes progress and retry states;
- the bottom destination count remains stable when transient activity starts;
  and
- localized metadata prefers the UI language while source content stays intact.

Add automated browser checks in WebKit at 320×568, 390×844, and 430×932, in
light and dark themes and with reduced motion. Assert no horizontal overflow,
44×44 targets, safe-area clearance, no overlap between content/mini-panel/tab
bar, and usable keyboard-open forms. Override the theme's safe-area proxy
tokens with representative nonzero top and bottom insets; desktop WebKit does
not emulate an iPhone notch. Run an accessibility scan for names, roles, dialog
focus, and contrast.

Treat browser automation as a regression layer, not proof of iOS behavior.
Before shipping, install the HTTPS build on a physical iPhone and verify safe
areas, the software keyboard, edge-swipe/back behavior, standalone status-bar
color, offline launch, update lifecycle, and VoiceOver.
