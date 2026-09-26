# Backend instrumentation

Detect the runtime/framework/logger and existing instrumentation first. Prefer
OpenTelemetry, preserving working existing integrations. Choose only selected
signals and supported instrumentations; avoid duplicate SDK initialization,
HTTP spans or log export via two paths.

## Node / TypeScript / Fastify

Inspect Node version, ESM versus CommonJS, `tsx`/build start commands, Fastify
version, HTTP clients and structured logger. Verify compatible OpenTelemetry
packages/instrumentations using current docs. Initialize instrumentation before
the modules it patches; test the real container start command, not only a test
runner. Confirm the current ESM/loader requirements rather than assuming an
import in an arbitrary module is early enough.

Capture inbound HTTP requests, normalized route, response status, latency,
supported outbound HTTP calls, and error spans/exceptions. Connect the logger
to the active context so structured stdout records have trace/span IDs.
Do not assume automatic framework instrumentation covers handled application
errors or unhandled failures: verify both, and add focused hooks where needed.
Preserve the application's crash/restart behavior; telemetry must not swallow
fatal exceptions or force an unbounded flush. Scrub auth/query/body data before
serialization. Export only to configured, reachable collector endpoints.

Consult [OpenTelemetry Node.js](https://opentelemetry.io/docs/languages/js/getting-started/nodejs/)
and the installed framework/instrumentation's official documentation. Confirm
SDK initialization, resource attributes, exporter protocol and module-loading
instructions for the exact versions. Generate lockfile-backed dependencies;
do not copy a frozen list of package versions from this skill.

## .NET

Inspect target framework, host builder, ASP.NET Core versus workers, logging
providers, HttpClient and existing Activity instrumentation. Use current
official OpenTelemetry .NET integrations for the detected host/runtime.
Configure selected inbound/outbound tracing, runtime/application metrics and
structured log correlation through supported builder/provider APIs. Verify
resource identity, exporter protocol, sampling and bounded shutdown on the
actual service, not just a console demo. Avoid duplicate export if a central
stdout collector already owns logs.

Start with [OpenTelemetry .NET](https://opentelemetry.io/docs/languages/dotnet/getting-started/)
and follow its official signal-specific integrations for the installed version.

## Other backends and common checks

Use the detected language's supported OpenTelemetry SDK/instrumentations, not
Node assumptions. If required signals are unsupported, state the gap and use
the existing compatible integration without redesigning the application.

Environment configuration should cover enablement, service/project identity,
deployment environment, exporter endpoint/protocol, protected auth, sampling
and bounded buffering. Keep metrics paths private or protected according to
the discovered host model. Use route templates rather than arbitrary URLs as
metric dimensions; status/method/service/environment are bounded labels.

Validate health while the exporter is unreachable, normal requests, a safe
controlled error, structured log output and real trace/span correlation. Never
log authorization headers, session tokens, API keys, passwords, PocketBase
admin credentials, or sensitive request/response bodies. Trace attributes and
exception text need the same redaction as logs.
