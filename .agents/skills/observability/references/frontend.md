# React / browser / PWA telemetry

Prefer Grafana Faro when Grafana is the target; inspect the app/router/runtime
and any existing browser instrumentation first. Use current supported APIs,
not a copied initializer from an old SDK version. Implement only selected
browser signals: uncaught errors, unhandled promise rejections, supported web
vitals/performance, useful route context, traces and API request correlation.

Read the current [Faro setup documentation](https://grafana.com/docs/grafana-cloud/observe-and-act/monitor-applications/frontend-observability/instrument/faro/)
and [Alloy Faro receiver](https://grafana.com/docs/alloy/latest/reference/components/faro/faro.receiver/).
Distinguish managed Frontend Observability features from self-hosted Faro
ingestion into Loki/Tempo; do not promise a managed UI merely because Faro is
installed. Confirm receiver formats, trace forwarding and current tracing/
router integrations for the SDK version actually chosen.

Initialize once, early enough to capture useful startup errors, with an
environment-controlled disable path. Public config should contain only receiver
URL, enablement, app/service/environment/version and selected public options.
In Vite apps, `VITE_*` is public bundle data; never include private collector
credentials there. Wire public build-time settings through actual Docker build
args when applicable and rebuild for each environment. Do not assume API
runtime env changes update an already-built frontend bundle.

## Browser trust boundary

A browser-accessible receiver accepts untrusted input; a browser token is not
a private credential. Prefer the existing protected ingestion design. Confirm
allowed origins, HTTPS, payload/rate limits and any public ingestion-key
semantics; CORS alone is not authentication or abuse protection. Keep storage
credentials on the server/collector. Do not forward the app's bearer token or
session cookie into telemetry requests. Do not expose private OTLP/Loki/Tempo
endpoints just to avoid configuring a browser receiver.

Limit trace propagation to owned API origins. Verify W3C context reaches the
backend and cross-origin preflight works when relevant, without attaching trace
headers to every third-party request. Exclude telemetry requests from tracing
to prevent feedback loops.

## Privacy and PWA behavior

Review automatic console/error/resource/breadcrumb collection. Scrub query
strings, URL fragments, exception text, referrers and logs before sending.
Never intentionally capture passwords, form contents, auth/session tokens or
private user content. Keep user identity collection off unless separately
requested and scoped. In `pwa-stack`, redact the SSE token query parameter.

Handle offline/receiver failure without blocking navigation, login, mutations,
app startup or service-worker updates. Bound queues/retries and do not add
telemetry POSTs to a general offline replay/cache policy. Verify installed-PWA
behavior when relevant, with local telemetry disabled by default unless the
user selected that environment.

Test a synthetic error/rejected promise and a normal browser→API request.
Verify delivery, app/environment identity, a connected trace and redacted
payloads at the receiver/storage. Browser network success alone does not prove
events are queryable. If the central stack is inaccessible, clearly separate
local capture/transport verification from pending ingestion checks.
