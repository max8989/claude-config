---
name: ticktick
description: >-
  Manage TickTick reminders and tasks through the connected TickTick app plugin.
  Use for viewing or searching tasks, adding reminders, editing or rescheduling,
  recurring reminders, completion, deletion, and organizing TickTick lists.
  Applies when the user mentions TickTick or invokes $ticktick; reminders in
  another app or requests for agent automations belong to their own tools.
---

# TickTick

Use the connected **TickTick:To-Do List & Calendar** plugin. If invoked without
an operation, show today's open tasks. An invocation alone does not authorize
creating or changing tasks.

## Find the tools and targets

Discover the available TickTick tools and inspect their current input schemas.
Tool names may include a connector namespace before
`ticktick_to_do_list_calendar_`; the names below are operation suffixes.
Use the plugin directly rather than installing a CLI or handling credentials.
If it is unavailable or authentication fails, explain that the TickTick plugin
needs to be connected or reconnected; do not claim to have accessed the account.

Resolve list names with `list_projects`, using returned IDs. When no list is
specified for a new task, use the returned Inbox project unless the user has
established another default. The unpaginated project listing includes Inbox;
do not invent its ID. Respect project permissions.

Resolve task names with `search_task`, then fetch full details with
`get_task_by_id` or `get_task_in_project`. Reuse a task already identified in
the conversation when its identity is clear. If multiple targets fit, ask one
focused question with titles, lists, and dates before changing anything.

## Choose the operation

| Request | Tools |
| --- | --- |
| Today, tomorrow, next seven days | `list_undone_tasks_by_time_query` |
| Custom dates, tags, priorities, status, or lists | `filter_tasks`, `list_undone_tasks_by_date` |
| All open tasks in a list, including undated tasks | `get_project_with_undone_tasks` |
| Completed tasks | `list_completed_tasks_by_date` |
| Add tasks or reminders | `create_task`, `batch_add_tasks` |
| Edit, reschedule, or change notification or recurrence settings | `update_task`, `batch_update_tasks` |
| Move between lists | `move_task` |
| Finish a task or checklist item | `complete_task`, `complete_checklist_item` |
| Delete a task | `delete_task` |
| Create or rename a list | `create_project`, `update_project` |

Use `query_command` for the relative-time tool, not a guessed argument name.
Default ordinary task views to incomplete tasks. Do not describe a today or
next-seven-days query as all reminders. For all open tasks, cover every relevant
list, including Inbox and undated or overdue tasks. Follow pagination where
provided; split `list_undone_tasks_by_date` requests into windows of at most
14 days and deduplicate by task ID. Show the actual queried scope when results
are incomplete. Use completion tools instead of substituting deletion.

## Dates, notifications, and recurrence

Resolve relative dates against the current clock in the user's timezone. Use
an explicitly requested timezone first, otherwise the account's timezone from
`get_user_preference`, then a known session timezone. Ask only if the timezone
or a necessary notification time cannot be established. Calculate offsets for
the target date so daylight saving changes are respected; never bake a local
timezone into this global skill.

Task dates use `yyyy-MM-dd'T'HH:mm:ssZ`, with an explicit UTC offset. Supply
`timeZone` and, where supported, `client_timezone` consistently. Date-only
tasks should remain all-day tasks without an invented notification time.

For "remind me at [time]", set the timed task schedule and the `reminders`
notification setting. A scheduled date alone does not establish a notification.
`TRIGGER:PT0S` is the documented at-time trigger. Use the live schema or official
documentation for other trigger offsets instead of guessing their encoding.
If a notification is requested without enough timing information, ask for the
missing time before creating it.

Use `repeatFlag` for recurrence, for example `RRULE:FREQ=DAILY;INTERVAL=1` for
daily recurrence. Set the first occurrence, timezone, and notification settings
to match the request. Preserve recurrence when merely rescheduling; clarify
whether a change affects one occurrence or the series if that distinction is
unresolved, and check that the available tool supports the requested scope.

## Make and verify changes

Carry out clearly requested changes without asking for the same authorization
again. An instruction to view reminders authorizes reads. Keep writes within
the requested tasks, lists, and fields; creating this skill is not a request
to create sample reminders in the live account.

Before editing an existing task, fetch its current details. `update_task` takes
an outer `task_id` and a `task` object containing its `id` and `projectId`.
Include the required identifiers and requested changes, using the latest
`etag` if supported. Preserve unrelated details, durations, checklist items,
tags, notifications, and recurrence. Omit untouched fields rather than sending
nulls or empty arrays; when editing a collection, retain its untouched entries.
Do not copy response-only fields into an update.

For an explicit request to remove a task date, the current connector documents
`1970-01-01T00:00:00.000+0000` as the clearing value for `startDate` or `dueDate`;
recheck the live contract before using it. Moving a task uses `move_task` and
the source and destination project IDs, rather than guessing an update.

Use batch tools for explicit multi-task requests when suitable. Inspect each
item's result and report any partial failures. After a timeout or uncertain
write result, read the affected task or search for the newly requested task
before retrying, so a retry does not duplicate a reminder.

Confirm results from successful tool responses; fetch again when the response
does not establish the changed state. Summarize titles, local dates and times,
lists, and relevant recurrence or notification settings. Include returned task
links when useful. Distinguish saved notification settings from delivery, which
a successful save cannot prove. Keep account contents in the response unless
the user asks to save or export them.

Field conventions: [official TickTick API documentation](https://developer.ticktick.com/).
The connected plugin's live schemas govern tool arguments and supported operations.
