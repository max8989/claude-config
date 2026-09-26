# Prove the configured signals

Use synthetic, non-sensitive test data and a bounded time window. Do not crash
production or introduce public test-error routes; use a local/staging fixture
or an explicitly authorized controlled request. Remove temporary test hooks.
Validate only selected signals, and mark others not requested.

| Check | Evidence required |
|---|---|
| App integrity | Existing build/typecheck/tests and actual start command pass |
| Deployment | Compose config valid without secret output; API health remains healthy |
| Logs | Synthetic structured log visible in Loki with app/environment filters |
| Metrics | Endpoint/scrape reachable; fresh metric queryable in central Prometheus |
| Backend trace | Safe request produces inbound span, status/latency and selected outbound spans in Tempo |
| Controlled error | Sanitized exception/error visible in requested log/trace/browser destinations |
| Browser signals | Faro receiver accepts events and chosen errors/performance are queryable downstream |
| Correlation | Browser request → API trace → backend log works with actual trace/span IDs and Grafana links |
| Infrastructure | Container/host data joins by app/service/environment/time; no trace-ID metric label |
| Isolation | Prod/dev queries distinguish metadata and do not conflate services or data |
| Privacy | Synthetic secret canaries absent from emitted/received payloads, logs, URLs and public bundle |
| Receiver failure | App starts, remains healthy and usable; buffering/retries stay bounded when receiver is unreachable |

Use fake password/token canaries in controlled inputs, never real credentials
as test material. Inspect redaction across logs, spans, frontend payloads and
collector/proxy logs, including SSE query tokens where applicable. Avoid
printing the inspected payloads wholesale into an agent transcript.

Do not stop at package install, config parsing, receiver HTTP success or SDK
console output. Query the actual selected storage and record non-sensitive
timestamp/service/trace evidence when access is available. Validate sampling
does not discard the controlled verification request.

If the central environment is unreachable or deployment was not authorized,
report exactly which layers passed (build/config/local capture/transport) and
which remain pending. Provide operator steps using discovered data-source
names/endpoints, label selectors and a short time window, with secret env
references rather than literal keys. Do not report end-to-end telemetry as
working until data is visible in its intended destination.

The handoff should include configuration/env names, enabled signals, reused
central services, data paths and trust boundaries, app/environment filters,
one practical error→trace→logs→load walkthrough, privacy/sampling decisions,
how to disable telemetry, validation results, and pending server-side work.
