# Skill updates

Check for updates to **the installed pwa-stack skill** at every invocation,
before requirements, research, generation, or other project work. Use the Git
history of its `claude-config` source, following the notification-and-consent
pattern used by Agent Reach. This does not change generated apps' PWA updates.

## Check the source

1. Resolve symlinks on the loaded `SKILL.md` and locate its containing
   `claude-config` checkout. The usual location is `~/repos/claude-config`.
   Verify that the checkout supplies the installed skill and has an `origin`;
   do not use the current app's Git repository merely because it is the working
   directory. If the skill is a standalone copy and its source cannot be
   verified, mention that the update check is unavailable and continue with the
   installed version. Do not clone or install anything for this check.
2. Fetch the current default-branch tip from that checkout's `origin`, with a
   bounded network timeout. For example, with `config_repo` set to the verified
   checkout, run `git -C "$config_repo" fetch --quiet --no-tags origin HEAD`,
   then resolve `FETCH_HEAD` to a full commit ID and retain it as
   `reviewed_commit`. This refreshes source information without applying an
   update; it does not assume the default branch is named `main` or `master`.
   If fetching fails or times out, mention once that updates could not be
   checked and continue with the installed version. Do not claim it is current
   based on stale remote refs or retry in a loop.
3. Inspect incoming commits with
   `git -C "$config_repo" log "HEAD..$reviewed_commit" --date=short --format='%h %ad %s' -- .agents/skills/pwa-stack .claude/skills/pwa-stack`.
   Both trees are part of this skill: include their entry points, references,
   scripts, and templates. Ignore changes elsewhere in `claude-config`, and
   use history rather than an arbitrary recent-date cutoff so older missing
   updates are also found.
4. Check the actual installed file contents against the reviewed source before
   offering an update. Commit counts alone are insufficient: an update already
   copied into the working tree, including new untracked files, must not be
   offered again. Inspect any local edits and local-only skill commits too;
   they are not evidence that upstream has a new version. If there are no
   incoming skill changes, or their resulting contents are already installed,
   continue silently. If histories cannot be compared, report the check as
   unavailable rather than treating an arbitrary difference as an update.

## Notify and wait for the user's choice

When incoming skill changes remain to be installed, show a short message in the
user's language with the latest relevant commit/date and one to three concrete
changes, then ask whether to apply the update. For example:

> Une mise à jour de **pwa-stack** est disponible dans `claude-config`
> (`<commit>`, `<date>`). Changements : `<résumé>`. Veux-tu la mettre à jour
> avant de continuer ?

Prepare the scoped diff before asking. Mention any local skill modifications
that would need to be preserved. Ask once per reviewed source commit in a
conversation; still perform the check on later invocations, but do not repeat
an offer the user already declined for the same revision. If declined, continue
the requested work with the installed skill. While an answer is pending, do
not apply the update or begin work that depends on which skill version is used.

## Apply only after agreement

The update notice is not authorization to update. Once the user agrees, recheck
local changes and apply only the reviewed changes to the two pwa-stack trees.
Preserve local edits, local-only commits, unrelated files, the repository's
current branch/HEAD, and existing staged work. Do not use a whole-repository
pull/reset or overwrite conflicting local work to perform a skill update. If
local changes conflict, prepare a resolution that preserves them; ask for a
decision only where the intended result cannot be inferred.

Use the reviewed commit, not a newly fetched revision with unseen changes.
Verify the resulting skill files, resolve any installation links needed for
new files using the existing installation workflow, and reread the updated
`SKILL.md` and relevant references before continuing. Report completion briefly;
if the update fails, keep the installed version usable and explain the failure.
