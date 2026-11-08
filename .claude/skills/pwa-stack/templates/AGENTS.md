# Project instructions

## UI work

For every UI/UX task, including small visual fixes, interaction changes, and
verification, check the available skills and read `ui-ux-pro-max` before
proposing, implementing, or reviewing the change. Follow wrappers to their
canonical instructions and use guidance for this project's web/React platform.
Read the references relevant to the task. Report unavailable skill guidance.

Read [UI_GUIDE.md](UI_GUIDE.md) before UI work. It records this project's routes,
page hierarchy, responsive breakpoints/widths, theme, shared components, and
verification requirements. Extend the chosen system and update that guide
when an approved design decision changes.

- Support phone, tablet, and desktop by default using available window width,
  including Split View. Preserve the documented phone tabs, tablet rail,
  desktop sidebar, breakpoints, and shared routes. Resizing must retain the
  active page, drafts, and transient activity; hide inactive navigation from
  the keyboard/accessibility tree.
- Preserve the documented root destination order and labels. Use the Home,
  collection, central Add/Create, main activity, and Profile roles that apply
  to this product. Keep transient activity in the dock above phone tabs or
  beneath wider content, clear of the sidebar; remove unused chrome space.
  Keep utilities under their owning pages.
- Follow the page hierarchy: a compact daily overview and next action on Home;
  grouped/searchable content with labeled creation and actionable empty states
  in the collection; one guided creation flow; content-first activity/detail;
  grouped settings and account actions in Profile.
- Reuse the shared page/header, button, field, row, card, segmented-control,
  state, confirmation, and dock components. Keep theme values in semantic
  tokens and use the same spacing and type hierarchy across screens.
- Keep shared responsive rules in `frontend/src/theme/responsive.css`. Use the
  wider Home/collection workspace and multicolumn browsing where space allows;
  preserve focused form/reader/activity widths and vertical reordering.
- Provide loading, empty, error/Retry, offline, and permission states as relevant.
  Retain drafts, prevent duplicate submissions, and roll back failed optimistic
  changes. Keep interface language separate from authored content.
- Confirm destructive actions, meaningful draft abandonment, and sign out
  before changing data or authentication. Cancellation preserves state.
- Preserve normal detail Back behavior and stable tab roots. Provide refresh on
  data-bearing root/list pages and accessible alternatives to row swipe actions.
- Keep targets at least 44×44 CSS px, focus visible, controls named, text
  scalable, zoom enabled, and safe areas/keyboard clear. Check light/dark
  contrast and reduced motion. Keep reading and form surfaces opaque.

## UI verification

Run the checks relevant to the change and record evidence or remaining limits
in `UI_GUIDE.md`. Use Chrome DevTools MCP on the running app and browser
regression checks at phone, tablet portrait/landscape, and desktop widths,
including both sides of navigation/layout breakpoints and live resizing. Check
the affected themes, long content, larger text, touch/mouse/keyboard access,
selected navigation, Skip to content, error/retry, and dock/navigation overlap.
Use a physical installed iPhone for iOS-specific safe areas, keyboard, gestures,
VoiceOver, and PWA lifecycle behavior. Distinguish
browser tablet emulation from physical iPad/Safari and Split View checks.
Record what was tested and what still needs device verification.
