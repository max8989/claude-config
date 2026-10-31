# Shared PWA UI structure

Use this contract for every new `pwa-stack` project. It captures the web/PWA
structure of `/home/maxime/repos/chinese-learning`: the shell in
`frontend/src/App.tsx`, the Home, Library, NewContent, and Profile pages, and
`frontend/src/theme/variables.css`. The rules below are self-contained; a new
project does not need access to that repository.

Preserve the shell, page hierarchy, shared components, and interaction rules.
Adapt the resource names, main activity, brand, fonts, and content language to
the product. Explicit user choices take precedence. Apply web/React guidance
from `ui-ux-pro-max` within this structure.

## Contents

1. Record the project UI contract
2. Build the stable bottom shell
3. Follow the core page hierarchy
4. Make creation discoverable and guided
5. Reuse components, tokens, and materials
6. Treat iPhone constraints as layout inputs
7. Confirm consequential actions and recover from failure
8. Separate interface language from content language
9. Preserve accessibility, offline behavior, and performance
10. Verify the design and retain evidence

## 1. Record the project UI contract

Before generating components, write `UI_GUIDE.md` in the generated project
root with the decisions for this app:

- primary resource, repeatable action, and returning/resume state;
- root destinations in order, labels, routes, and ownership of detail routes;
- the Home, collection, Add, main activity, detail, and Profile hierarchy;
- the activity dock and creation entry points, where applicable;
- chosen light/dark colors, font families, spacing, and component roles;
- loading, empty, error, offline, and permission-denied states;
- confirmation boundaries, UI language, and content language; and
- browser checks and physical-device checks, with evidence and remaining limits.

Copy [the project agent instructions](../templates/AGENTS.md) and
[the Claude entry point](../templates/CLAUDE.md) into the project root. They
make this contract apply to later UI tasks as well as the initial scaffold.
Merge with existing project instructions when present. Keep generated documents
self-contained: their links must resolve inside the new project, and their
rules must not depend on this skill or the Chinese app being installed.

## 2. Build the stable bottom shell

Use the Chinese PWA's five roles as the default, in this order:

| Role | Chinese PWA | Adaptation for another product |
| --- | --- | --- |
| Home | Home | Today's status, next action, recent activity |
| Collection | Library | The main objects users browse or manage |
| Creation | Add | A central, text-labeled Add/Create entry |
| Main activity | Flashcards | The product's repeatable work or review flow |
| Profile | Profile | Preferences, installation, account controls |

Rename roles for the domain and omit a destination with no meaningful purpose;
do not invent features to fill five slots. Keep three to five permanent
destinations and record the chosen order. Use one consistent icon family with
visible labels. Keep the creation entry central when the five-role shell fits.

Keep tab count and positions stable. Downloads, statistics, activity/job
history, discovery, and similar utilities belong under their owning pages.
Playback, uploads, timers, and other transient work use a compact dock above
the tabs instead of another tab. The dock's main region reopens the activity;
its play/pause or other primary control is separately tappable. A dismiss
control, if present, must be separately named and must not discard saved work.

Keep roots distinct from pushed details and forms. Tab switching must not
leave a stack of previous roots to traverse with Back. Details retain normal
back navigation. Keep the dock in place beneath an expanded activity sheet so
collapsing it immediately reveals the same activity and state.

Fit the entire shell at 320 CSS px and enlarged text sizes. Reserve scrolling
space for the dock and tabs; the final row and its actions must remain visible.

## 3. Follow the core page hierarchy

### Home

Follow the PWA's compact daily overview: a Today/status heading, a concise
progress summary, one clear daily/continue action, then recent content or
activity. Show a resume state when real saved work exists. Optional requests
or discovery links remain secondary. Provide a visible creation entry without
competing with the primary daily action. Use typography and spacing to rank
content rather than making every statistic an equally prominent card.

### Collection or library

Use a clear title and a text-labeled Add action. Group meaningful collection
types with consistent segment/filter controls, then show search, sorting, and
the content list. Keep owned content distinguishable from shared or suggested
content. Default new user-created items to newest first; preserve meaningful
user ordering or an explicitly chosen sort. Give rows a strong title/meta
hierarchy. The empty state explains the next step and offers a labeled Add
action; filtered-empty and initial-empty states have different recovery copy.

Use swipe-to-reveal edit/delete for owned, editable rows where appropriate.
Provide the same actions through a keyboard/screen-reader reachable menu or
detail view. Shared/read-only rows do not expose owner actions. Close revealed
actions when selected and confirm before deleting. Data-bearing root/list
pages support pull-to-refresh; complete the refresh on success and failure.
Do not attach it to an Add form or an active reorder/edit gesture.

### Add/Create

Use one central creation route for equivalent entry points from the tabs,
Home, collection header, and empty state. Keep the same flow and draft state
regardless of entry. Present the available input modes first, then guide the
user through only the decisions needed for the selected mode.

### Main activity and detail

Prioritize the content and the repeatable action. Show the title once as the
primary heading; a toolbar may take it over after the body title scrolls away.
Place secondary metadata and management controls below the main task. Preserve
position, draft, or session state when leaving and returning where relevant.

### Profile and settings

Use grouped settings rows with secondary current values, consistent controls,
and useful section labels. Group appearance, behavior, notifications, and
account controls. Include an Install app entry while installation is available
or manual instructions are useful; hide it after installation. Sign out belongs
with account controls and uses the shared confirmation flow.

## 4. Make creation discoverable and guided

- Keep the visible Add/Create label under or beside its icon. A lone toolbar
  `+` must not be the only creation entry.
- Use an add icon for adding an object and a compose/edit icon for drafting.
  Avoid sparkle/star/wand imagery as the generic creation symbol.
- Keep visible text in the accessible name and hide decorative icons from
  assistive technology.
- For a multi-step creator, order decisions as input method, source/description,
  essential settings, preview, then save/publish. Put infrequent controls in a
  clearly labeled advanced section. Use descriptive mode cards for materially
  different workflows such as Generate, Paste, or Manual.
- Keep the primary action reachable without covering fields, validation
  messages, or the keyboard. Preserve entered work across navigation and warn
  before abandoning a meaningful draft.
- Prevent duplicate submissions; show progress, success, failure, and retry
  in the same flow.

## 5. Reuse components, tokens, and materials

Use [the shared theme rules](theme-tokens.md). Establish reusable page/header,
button, field, grouped-row, card, segmented-control, empty/error-state,
confirmation, and activity-dock components as the product needs them. Extend
those components for later screens. Keep genuinely domain-specific content in
its own components.

Start with calm opaque surfaces, readable typography, the 4/8/12/16/24/32 px
spacing scale, and a consistent content width (about 680 px for ordinary
reading/list pages). Keep color, typography, radii, spacing, and motion in
semantic tokens. Define light and dark appearances for every shared component
and its pressed, focused, disabled, loading, and error states.

Separate low-level content with spacing, tonal groups, dividers, and type.
Reserve borders and shadows for meaningful containment. Use gradients only
for a deliberate brand moment. Apply glass to navigation or compact controls
with an opaque fallback; keep reading, forms, and long lists opaque. Avoid
adding a second blur over an already translucent header.

Prefer CSS/SVG decoration. Do not add WebGL, shader, liquid-glass, or animated
logo runtimes as global UI dependencies. If the product specifically needs an
isolated WebGL visual, lazy-load it outside the initial route, cap resolution,
pause it while hidden, handle context loss, and provide static/reduced-motion
fallbacks. Decorative visuals must not intercept input or enter the
accessibility tree.

## 6. Treat iPhone constraints as layout inputs

- Use `width=device-width, initial-scale=1, viewport-fit=cover` and preserve
  pinch zoom. Include an Apple touch icon and synchronize status/theme colors.
- Assign one owner for each safe-area inset. Ionic headers/tab bars and custom
  docks must not both add the same bottom or top inset. Standalone content
  without covering chrome may need its own padding; see the theme reference.
- Keep every interactive target at least 44 by 44 CSS px, including chips,
  toolbar, seek, and icon-only controls.
- Use native Ionic toolbar button structure and let the translucent header own
  its rendering. Verify both icon and label in Safari and standalone mode.
- For custom full-height login/form/sheet layouts, use a `100vh` fallback then
  `100dvh`. Keep focused fields and actions scrollable when the visual viewport
  shrinks. Leave Ionic-owned page/content sizing to Ionic.
- Check long labels, larger text, keyboard, edge swipe, supported rotation,
  and the home indicator. Gesture actions also need non-gesture alternatives.

## 7. Confirm consequential actions and recover from failure

- Route delete, remove, irreversible toggles, draft abandonment, and sign out
  through one app-wide promise-based confirmation component.
- Backdrop dismissal, swipe-down, Escape, and Cancel mean cancellation. Do not
  mutate data or clear authentication until confirmation.
- Name the item or consequence in the copy. Use destructive color for
  destructive outcomes; ordinary sign out can use the primary treatment unless
  local-only work would be lost.
- Every query needs an explicit error and Retry state. A failed request must
  not remain an indefinite skeleton. Pair optimistic changes with rollback and
  a clear failure message.

## 8. Separate interface language from content language

Use the selected UI language (English by default) for chrome, navigation,
filters, and metadata. Preserve learning, media, and user-authored content in
its source language.

Return original labels and optional localized labels in list, search, filter,
and nested-detail DTOs. Select display text through one pure helper: prefer a
trimmed UI-language label, fall back to the original, and show the original as
secondary text only when different. Keep editing forms bound to raw fields.
Keep script/charset preferences separate from UI locale.

## 9. Preserve accessibility, offline behavior, and performance

- Use semantic headings, labeled fields, real buttons, explicit selected states,
  visible focus, and logical dialog focus/return. Do not nest interactive controls.
- Check AA contrast for text and controls in each theme, reduced motion, text
  scaling, and keyboard access independently.
- Prefer system or bundled/self-hosted fonts with suitable content-language
  fallbacks. Verify cold/offline launch when external fonts are chosen.
- Lazy-load non-root pages and nonessential visuals; keep the initial route
  light. Show offline readiness and pending work where useful, and keep saved
  work usable when a network request fails.
- Use deterministic static visual effects in screenshot tests.

## 10. Verify the design and retain evidence

Generate focused component tests for labeled creation entries and empty states,
confirmation cancellation/acceptance, draft retention and duplicate-submit
prevention, retry behavior, stable tabs while activity starts, accessible
owner actions, and localized-label fallback when applicable.

Run browser checks in WebKit at 320×568, 390×844, and 430×932 in supported light
and dark themes, with enlarged text and reduced motion. Assert no horizontal
overflow, 44×44 targets, safe-area clearance, usable keyboard-open forms, and
no content/dock/tab overlap. Test nonzero safe-area proxy values because
desktop WebKit does not emulate an iPhone notch. Check accessible names,
dialog focus, and contrast. Compare Home, collection, Add, activity/detail,
and Profile against the recorded project hierarchy.

Treat browser automation as a regression layer. Before shipping, verify the
installed HTTPS app on a physical iPhone: safe areas, keyboard, edge-swipe/back,
standalone status bar, VoiceOver, offline launch, installation, and update
lifecycle. Record evidence and unchecked limits in `UI_GUIDE.md`; passing types
or screenshots alone does not establish these behaviors.
