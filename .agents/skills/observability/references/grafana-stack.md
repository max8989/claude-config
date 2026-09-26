# Reuse or prepare the central environment

Inspect existing Compose/config/provisioning and authorized service status.
Build a small inventory: component, location/version, selected signals,
ingestion/query endpoints, protocol, authentication variable, reachable
networks, storage/retention and config owner. Unknown is not missing.

Reuse Grafana dashboards/data sources, Prometheus, Loki, Tempo and any compatible
collector separately. Extend existing Alloy/collector pipelines without
duplicating collection. No per-app Grafana stack, no replacement Prometheus
because an app needs metrics, and no second host Alloy without a concrete
collection gap. A remote collector cannot automatically read this host's
container logs; reuse or propose an authorized host collector if needed.

For the chosen signal routes, prepare minimal reviewable config changes:

- Register the app's discovery/scrape targets and metadata mappings.
- Connect the trace receiver/exporter to Tempo and log collection to Loki.
- Identify the browser-reachable Faro receiver separately from private OTLP.
- Add or adapt Grafana data sources and trace-to-log/log-to-trace links using
  actual data-source IDs, field names and labels; preserve existing entries.
- Supply app/environment filters and a useful starting dashboard or saved
  queries for request rate/errors/latency, logs, traces and selected load data.

Check protocol compatibility and endpoint binding; localhost inside a container
is that container. Do not publish storage backends or private collectors to
the internet just to make an app connect. Reuse the host's network/proxy/TLS
policy and confirm intended reachability before changing it. Read current
[Alloy OTLP collection guidance](https://grafana.com/docs/alloy/latest/collect/opentelemetry-data/)
for receiver → processor → exporter configuration, batching and memory limits.

## When infrastructure is missing

Offer central setup; obtain explicit authorization covering the environment
before provisioning or deploying it. Prepare the concrete files/plan first so
approval is reviewable. If authorization was already given, do not ask again.

Keep its Compose/provisioning directory independent of any application's
Compose lifecycle. Reuse existing components and generate only the missing
selected services. When a complete stack was requested, cover Grafana,
Prometheus, Loki, Tempo and Alloy with:

- current verified compatible versions pinned in generated files;
- storage volumes, ownership, disk/retention limits and backup/recovery steps;
- private networks/endpoints and only confirmed public ingress;
- secret references outside committed config, protected operator access;
- actual per-signal collector routing, scrape/discovery configuration and
  explicit identity/label mapping;
- provisioned data sources, correlation links, app/environment filters;
- config validation, startup/health checks and signal ingestion verification;
- a scoped apply/restart and rollback plan that preserves existing services/data.

Do not turn a development/demo all-in-one container into an assumed production
deployment. Use official docs for each installed version:
[Grafana](https://grafana.com/docs/grafana/latest/),
[Prometheus](https://prometheus.io/docs/prometheus/latest/configuration/configuration/),
[Loki](https://grafana.com/docs/loki/latest/),
[Tempo](https://grafana.com/docs/tempo/latest/), and
[Alloy](https://grafana.com/docs/alloy/latest/).
When deployment is outside the authorized scope, deliver validated config and
exact operator steps without applying it or claiming live ingestion.
