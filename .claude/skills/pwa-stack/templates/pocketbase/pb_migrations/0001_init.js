/// <reference path="../pb_data/types.d.ts" />
// PocketBase JS migration. The API's superuser client does all data access, so
// most collection rules below are locked to authenticated users; tighten to
// superuser-only ("@request.auth.role = 'admin'") wherever the client should
// never touch a collection directly. Field/collection APIs shift between
// PocketBase versions — verify against the pb_data/types.d.ts of the pinned
// PB_VERSION (and the migration guide) before relying on any signature here.
migrate((app) => {
  // --- extend the default `users` auth collection ---
  const users = app.findCollectionByNameOrId("users")
  // [FEATURE: roles] role gate used by the API's requireAdmin + the admin tab.
  users.fields.add(new SelectField({ name: "role", maxSelect: 1, values: ["admin", "member"], required: true }))
  users.fields.add(new BoolField({ name: "active" }))
  // `name` and `avatar` already exist on the default users collection.
  // Anyone (even unauthenticated) may list active members for the login roster.
  users.listRule = "active = true"
  users.viewRule = "active = true"
  // Session length. PocketBase issues stateless JWTs that die exactly
  // `authToken.duration` seconds after login — the default is 5 days, which for
  // an installed household PWA means it goes dead every week or two. 30 days,
  // paired with the client-side sliding refresh (patterns.md §6), means a
  // session only ends after 30 straight days of not opening the app.
  users.authToken.duration = 2592000 // 30 days
  app.save(users)

  // --- items: the one example resource (rename to your domain) ---
  const items = new Collection({
    type: "base",
    name: "items",
    listRule: "@request.auth.id != ''",
    viewRule: "@request.auth.id != ''",
    createRule: "@request.auth.id != ''",
    updateRule: "@request.auth.id != ''",
    deleteRule: "@request.auth.id != ''",
    fields: [
      { name: "title", type: "text", required: true },
      { name: "notes", type: "text" },
      { name: "done", type: "bool" },
      { name: "due_date", type: "date" },
      { name: "created_by", type: "relation", maxSelect: 1, collectionId: users.id },
    ],
  })
  app.save(items)

  // --- [FEATURE: web-push] push_subscriptions ---
  const subs = new Collection({
    type: "base",
    name: "push_subscriptions",
    listRule: "@request.auth.id != ''",
    viewRule: "@request.auth.id != ''",
    createRule: "@request.auth.id != ''",
    deleteRule: "@request.auth.id = user.id || @request.auth.role = 'admin'",
    fields: [
      { name: "user", type: "relation", required: true, maxSelect: 1, collectionId: users.id },
      { name: "endpoint", type: "text", required: true },
      { name: "p256dh", type: "text", required: true },
      { name: "auth", type: "text", required: true },
    ],
  })
  app.save(subs)
}, (app) => {
  for (const n of ["push_subscriptions", "items"]) {
    try { app.delete(app.findCollectionByNameOrId(n)) } catch (_) {}
  }
})
