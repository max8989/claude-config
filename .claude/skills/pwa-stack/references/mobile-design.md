# Shared PWA UI structure

Use this contract for every new `pwa-stack` project. It captures the web/PWA
structure of `/home/maxime/repos/chinese-learning`: the shell in
`frontend/src/App.tsx`, the Home, Library, NewContent, and Profile pages, and
the shared theme. Responsive defaults follow commit
`a3cdd0dd8d42365a58c9c42c92a2cce474510fe6`, especially `AppSidebar.tsx` and
`theme/responsive.css`. The rules below are self-contained; a new project does
not need access to that repository.

Preserve the shell, page hierarchy, shared components, and interaction rules.
Adapt the resource names, main activity, brand, fonts, and content language to
the product. Explicit user choices take precedence. Apply web/React guidance
from `ui-ux-pro-max` within this structure.

## Contents

1. Record the project UI contract
2. Build the stable responsive shell
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
- phone/tablet/desktop breakpoints, navigation modes, and per-page content widths;
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

## 2. Build the stable responsive shell

Support phone, tablet, and desktop from the initial scaffold. Choose layouts
from the available window width, including tablet Split View and resized
desktop windows; do not infer them from device names or user-agent strings.
Use these defaults unless the user explicitly chooses another layout:

| Window width (CSS px) | Navigation | Content layout |
| --- | --- | --- |
| Below 768 | Stable bottom tabs | Single column |
| 768–1023 | Persistent 88px rail with icons and short visible labels; hide tabs | Wider browsing workspace, single-column Home |
| 1024–1199 | Same rail | Main/secondary Home columns and two-column collection browsing |
| 1200 and above | Persistent 248px labeled sidebar; hide tabs | Workspace capped at 1120px, with multicolumn browsing |

The wider workspace starts at 768px and has a 1120px maximum, separate from
the navigation width, with about 32px horizontal gutters. Keep readers, forms,
and focused activity/review content at their own comfortable width (about
680px or narrower). Apply the workspace width to Home, collections, and other
browsing pages, with content-specific layouts for wider screens.

Keep phone and feature styles as the base, then import
`frontend/src/theme/responsive.css` after them for shared breakpoint rules.
Use a shared app shell and a reusable `AppSidebar` for the rail/sidebar beside
the routed content. Keep one router, page tree, and set of data/draft/activity
state across widths. Prefer CSS media queries for layout changes so resizing
does not remount pages or restart work. Let flex/grid content shrink with
`min-width: 0` and `minmax(0, 1fr)`; wrap long titles and source-language text.
Fix overflow at its source rather than clipping the page to conceal it.

Use the Chinese PWA's five roles as the default, in this order:

| Role | Chinese PWA | Adaptation for another product |
| --- | --- | --- |
| Home | Home | Today's status, next action, recent activity |
| Collection | Library | The main objects users browse or manage |
| Creation | Add | A central, text-labeled Add/Create entry |
| Main activity | Flashcards | The product's repeatable work or review flow |
| Profile | Profile | Preferences, installation, account controls |

Rename roles for the domain and omit a destination with no meaningful purpose;
do not invent features to fill five slots. Keep three to five permanent phone
destinations and record the chosen order. Use one consistent icon family with
visible labels. Keep the creation entry central on phones when the five-role
shell fits. On wider screens, make Add/Create prominent in the rail/sidebar
and place Profile/account controls toward the bottom. Sidebar shortcuts may
surface existing utilities; do not invent features to fill the wider shell.

Use the same route definitions and root/detail ownership in every navigation
mode. Mark the owning destination active for nested routes. Root switches
should feel immediate, without a detail-page push animation; retain normal
modified-click/open-in-new-tab link behavior. Hide inactive navigation from
both the layout and keyboard/accessibility tree. Preserve visible focus and a
Skip to content link that focuses the current visible page, including when
other routed pages remain cached. Rail targets should be at least 56px tall,
sidebar links at least 48px tall, and all targets at least 44px in both axes.

Keep tab count and positions stable. Downloads, statistics, activity/job
history, discovery, and similar utilities belong under their owning pages.
Playback, uploads, timers, and other transient work use a compact dock above
the phone tabs and below the content on wider screens instead of another tab.
Align the wide dock with the content workspace, clear of the sidebar. Remove
unused tab/dock space when those controls are hidden, while reserving room for
active playback or offline status. The dock's main region reopens the activity;
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
content rather than making every statistic an equally prominent card. At
1024px and wider, place primary status/activity in the main column and existing
shortcuts, resume details, or secondary content in an approximately 296px side
column. Stack these in a useful reading order below that width; keep one copy
of the content and do not invent secondary features to fill a column.

### Collection or library

Use a clear title and a text-labeled Add action. Group meaningful collection
types with consistent segment/filter controls, then show search, sorting, and
the content list. Keep owned content distinguishable from shared or suggested
content. Default new user-created items to newest first; preserve meaningful
user ordering or an explicitly chosen sort. Give rows a strong title/meta
hierarchy. The empty state explains the next step and offers a labeled Add
action; filtered-empty and initial-empty states have different recovery copy.
At 1024px and wider, arrange collection groups/shelves in two columns while
keeping each group's contents readable. Reordering remains a single vertical
list. Keep search/filter controls usable with touch and a keyboard at every
width; desktop refresh must also be available without a pull gesture.

Use swipe-to-reveal edit/delete for owned, editable rows where appropriate.
Provide the same actions through a keyboard/screen-reader reachable menu or
detail view. Shared/read-only rows do not expose owner actions. Close revealed
actions when selected and confirm before deleting. Data-bearing root/list
pages support pull-to-refresh; complete the refresh on success and failure.
Do not attach it to an Add form or an active reorder/edit gesture.

### Add/Create

Use one central creation route for equivalent entry points from the tabs,
rail/sidebar, Home, collection header, and empty state. Keep the same flow and
draft state regardless of entry. Present the available input modes first,
then guide the user through only the decisions needed for the selected mode.

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

Start with calm opaque surfaces, readable typography, and the 4/8/12/16/24/32 px
spacing scale. Use separate focused-content and browsing-workspace width
tokens from the responsive shell contract; ordinary forms/readers stay narrow
while collections use the wider workspace. Keep color, typography, radii,
spacing, and motion in semantic tokens. Define light and dark appearances for
every shared component and its pressed, focused, disabled, loading, and error states.

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

Use Chrome DevTools MCP to exercise the running app at the relevant widths,
inspect console errors and failed requests, and retain browser regression
checks for these layouts:

| Coverage | Viewports (CSS px) |
| --- | --- |
| Phone, including WebKit checks | 320×568, 390×844, 430×932 |
| Tablet/narrow windows | 744×1133, 768×1024, 834×1194, 1194×834; also a narrow Split View width below 768 |
| Desktop | 1024×768, 1440×900, 1920×1080 |

Probe both sides of each breakpoint at 767/768, 1023/1024, and 1199/1200px.
Run the core flows in each navigation mode; use lightweight layout assertions
for the boundary probes. Check supported light/dark themes, enlarged text,
reduced motion, long localized labels/source content, touch input, mouse, and
keyboard. Assert no page-wide horizontal overflow, 44×44 minimum targets,
safe-area clearance, usable keyboard-open forms, and no content/dock/navigation
overlap. Test nonzero safe-area proxy values because desktop WebKit does not
emulate an iPhone notch. Check accessible names, dialog focus, and contrast.

Exercise nested detail → another root → original root, then resize between
tabs, rail, and sidebar without losing the active route, draft, or activity.
Verify selected navigation, modified-click links, Skip to content and the next
Tab target, collection expansion/reordering when present, and the dock both
active and absent. Verify mouse/keyboard access to refresh and owner actions.
Compare Home, collection, Add, activity/detail, and Profile against the recorded
project hierarchy and width roles. Retain representative tablet portrait,
tablet landscape, and desktop screenshots with behavioral results in
`UI_GUIDE.md`; include the responsive layout contract in the generated README.

Treat browser automation as a regression layer. Before shipping, verify the
installed HTTPS app on a physical iPhone: safe areas, keyboard, edge-swipe/back,
standalone status bar, VoiceOver, offline launch, installation, and update
lifecycle. Browser tablet emulation does not establish physical iPad/Safari or
Split View behavior; record those checks separately, including untested limits.
Record evidence in `UI_GUIDE.md`; passing types or screenshots alone does not
establish these behaviors.
