# Docker collection and isolation

Inspect the real Compose services, logging driver, networks, host collection,
project names, env files and volume bindings. Keep app stdout/stderr as
structured logs unless the project has a reason to use another transport.
Reuse host Alloy/Docker discovery or the existing compatible collector.
Do not insert a complete observability stack into each application's Compose.

For central Docker log collection, verify the host's actual access mechanism
and driver compatibility. Scope discovery to intended projects/services;
relabel project/service/container/environment metadata into the agreed contract
before forwarding to Loki. Avoid ingesting the same stream twice through
stdout collection and an application log exporter. Read current
[Alloy Docker log collection](https://grafana.com/docs/alloy/latest/reference/components/loki/loki.source.docker/)
when implementing that route. Protect collector access to the Docker API;
do not casually mount the Docker socket into application containers or expose
the daemon. A read-only socket mount does not make API operations read-only.

Reuse existing Prometheus/container/host metrics collection. Only add an app
endpoint or exporter where it supplies a requested missing signal; choose it
from the actual runtime and host setup. Record target reachability and the
low-cardinality app/environment/service labels. Do not create a new Prometheus
container solely for a new application.

Production and dev must retain distinct Compose projects, runtime data,
frontend build volumes, host ports and telemetry environment metadata. For
`pwa-stack`, consume its `APP_ENV`/deployment selection and public frontend
build config instead of inferring environment from a host name. A shared
collector network is not shared app storage. Avoid ambiguous `api` DNS aliases
when several projects join one network; use scoped aliases/targets matched
to discovery. Keep PocketBase private within its application network.

Read-only discovery does not authorize host collection/network changes.
Prepare minimal configuration and use existing authorization for application
integration; obtain the required explicit confirmation before creating missing
central infrastructure. Validate Compose without printing resolved secrets and
report live verification separately from static checks.
