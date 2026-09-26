---
name: observability
description: >-
  Add or configure centralized Grafana-based observability for new or existing
  applications, including Docker services, React/PWA frontends, Node/Fastify,
  .NET, and other backends. Discover and reuse existing Grafana, Prometheus,
  Loki, Tempo, and compatible collectors; integrate OpenTelemetry and Grafana
  Faro where appropriate. Use for application logs, metrics, traces, frontend
  errors/performance, or an explicitly requested central observability setup.
  Independent of pwa-stack; invoking this skill does not authorize infrastructure
  creation or deployment.
---

# Observability

Make a reported problem traceable from the browser/request through backend
spans and correlated logs to container load, filtered by app and environment.
Instrument the actual project and selected signals. Prefer the existing central
stack per server/environment; do not install a full stack per application.
Do not add Sentry.

## Discover before editing

Inspect manifests/lockfiles, entrypoints, request/logging code, Compose/deploy
files, env **names**, and existing telemetry config. Detect language/runtime,
framework, module format, deployment topology, health routes and log transport.
Read only the required config; do not dump env values or credential stores.

Resolve these questions from the repo and authorized read-only host inspection
first, then ask only for missing facts in a compact group:

- Are **Grafana, Prometheus, Loki, Tempo, and Alloy (or another compatible
  collector)** each present? Record present / absent / unknown separately.
- Are they on this Docker host, another server, or managed? Which private
  networks, reachable ingestion endpoints, protocols, browser receiver, and
  authentication method exist? Record secret variable names, never values.
- Which environments are in scope: local, development, production, multiple?
- Which signals are wanted: infrastructure/container metrics, backend logs,
  backend traces, frontend errors, frontend performance, or the full stack?

Unreachable infrastructure is **unknown**, not absent. Do not re-ask questions
answered by the user, calling skill, or configuration. Confirm the target
environment from those facts before modifying application integrations. While
facts are missing, continue read-only inspection and prepare a bounded plan.

## Choose the work

Read [architecture.md](references/architecture.md) for identity, signal paths,
correlation, privacy, and failure behavior. Then load only relevant references:

| Work | Reference |
|---|---|
| Reuse/extend central services, or explicitly requested central setup | [grafana-stack.md](references/grafana-stack.md) |
| Backend instrumentation for the detected runtime | [backend.md](references/backend.md) |
| React/browser errors, performance, traces | [frontend.md](references/frontend.md) |
| Docker log discovery, infrastructure metrics, network isolation | [docker.md](references/docker.md) |
| Verify configured signals and document remaining operator work | [verification.md](references/verification.md) |

**Existing compatible services:** reuse them. Generate only app integration,
label mappings, dashboard/query configuration, or minimal collector/scrape
changes needed for selected signals. Partial existing stacks remain useful;
do not replace them because a component is missing.

**Missing central Grafana or required storage/collector services:** explain
what was found and offer to prepare a central environment or add just the
missing components. Prepare a concrete configuration/placement plan for review;
create/install/start central infrastructure only after explicit confirmation
covering that environment. Prior explicit authorization counts; do not ask
again. Keep app instrumentation and central setup as separate deliverables.
When setup is deferred, leave the app usable with telemetry disabled and list
exact endpoint/configuration gaps. Never claim delivery to nonexistent services.

## Implement against current APIs

For every SDK/collector integration being written, use Context7
`resolve-library-id` then `query-docs` against installed versions. If unavailable
or uncovered, say so and use the official docs linked in the references.
Inspect compatibility, ESM/runtime boot ordering, signal support, and exporter
protocols before choosing packages. Record versions and doc links in the
project handoff. Do not paste stale version pins or assume an SDK supports all
signals identically. Preserve the user's existing stack and deployment model.

Generate environment-driven enablement, identity, sampling and endpoints, with
secret placeholders in examples. All `VITE_*` values are public. Redact before
export, keep queues/timeouts bounded, and make unavailable telemetry harmless
to application startup, health, and normal user operations.

Follow [verification.md](references/verification.md) for observable evidence.
Finish with files changed, reused services, signal routes, environment filters,
how to follow a trace into logs, tests performed, and any exact server-side
checks still pending. Package installation/configuration alone is not success.
