# Signal paths and identity

The requested default is one central stack per server/environment, shared by
applications. Reuse compatible components individually; a central service can
also be remote or managed. This is a placement preference, not a mandate to
install every component for every signal selection.

| Signal | Preferred path (adapt to discovered capabilities) |
|---|---|
| Structured container logs | stdout/stderr → existing host collector → Loki |
| Backend traces | OpenTelemetry → compatible collector/ingestion → Tempo |
| Browser errors/performance | Grafana Faro → browser receiver → configured storage |
| Browser traces | Faro tracing → receiver/collector → Tempo |
| Application metrics | app endpoint/exporter → existing Prometheus collection |
| Container/host metrics | existing host collection/exporters → Prometheus |
| Exploration | central Grafana data sources for selected storage services |

Grafana's UI URL is not an ingestion endpoint. Identify each protocol and
signal route, including receiver authentication, TLS and network reachability.
Do not assume a Faro receiver accepts OTLP or that an OTLP endpoint accepts
Faro payloads. Verify backend metrics export against actual collection support;
do not enable an assumed remote-write/OTLP receiver blindly.

## Identity contract

Choose one mapping and document it across all selected signals:

| Meaning | Resource/app metadata | Stable query label example |
|---|---|---|
| Service role | `service.name` such as `<slug>-api` / `<slug>-web` | `service_name` |
| Project grouping | `service.namespace` and app/project slug | `app` / `service_namespace` |
| Environment | current supported deployment-environment attribute | `environment` |
| Runtime origin | Compose project/service and container metadata | `compose_project`, `compose_service` |

Current OpenTelemetry conventions use `deployment.environment.name`; existing
pipelines may use `deployment.environment`. Inspect and map legacy attributes
explicitly, preserving existing dashboards; do not assume either automatically
becomes a Loki/Prometheus label. Keep app/service names stable, put release
version in separate metadata, and distinguish production/development even
when one central stack stores both. [OpenTelemetry deployment conventions](https://opentelemetry.io/docs/specs/semconv/resource/deployment-environment/)

Use bounded application/environment/service labels for filtering. Container
identity may be searchable structured metadata instead of an indexed label.
Never make user IDs, emails, arbitrary full URLs, exception messages, request
IDs, or trace IDs Prometheus labels. Keep trace/span IDs in log fields and
trace storage, not high-cardinality indexed Loki labels.

## Correlation and privacy

Preserve W3C trace context for owned browser → API → supported outbound calls.
Restrict propagation to approved application origins; configure CORS headers
only where cross-origin requests actually require them. Do not send application
credentials to telemetry receivers. Log correlation needs actual active span
IDs, consistent formatting, storage parsing and Grafana data-source links.
Joining infrastructure metrics is normally by service/container/time window,
not by a trace ID label. Validate the whole path with a synthetic request.

Redact at the source and, where useful, again at the collector. Exclude
passwords, API keys, authorization/cookie/session tokens, admin credentials,
sensitive request bodies, form contents, and unnecessary personal information.
Scrub query strings/fragments and sanitize exception messages, breadcrumb/console
content, referrers and resource URLs. In a `pwa-stack` app, SSE may place an
auth token in `/api/events?token=...`; this must be removed from logs, spans,
browser telemetry and receiver/proxy access logs. Do not add user/session
identity collection by default.

Bound sampling, batching, retries, queue memory and shutdown flush time. An
unavailable collector must not crash the app, block startup/health, accumulate
unbounded offline data, or recursively instrument exporter requests. Keep a
simple environment-controlled disable path.
