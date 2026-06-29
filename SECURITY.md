# Security Policy

## Reporting a vulnerability

Please **do not** open a public issue for security vulnerabilities.

Instead, report privately through GitHub's
[private vulnerability reporting](https://github.com/justinjkline/hyperlane/security/advisories/new)
(the **Security → Advisories → Report a vulnerability** flow on this repo). This
opens a confidential channel with the maintainer.

You can expect:

- an acknowledgement within a few days,
- a fix or mitigation plan once the report is triaged,
- credit in the release notes when the fix ships (unless you prefer to remain
  anonymous).

## Scope

hyperlane is a **local command-line tool**. It reads a sourced bash config,
inspects local ports with `lsof`, sends signals to local PIDs with `kill`, and
execs project-defined launch commands. It does **not** run a network service and
does **not** handle credentials itself.

The most relevant security surfaces are:

- **The sourced config is arbitrary bash by design.** `hyperlane.conf` is
  `source`d so its launch/env/verify hooks can be plain shell functions — which
  means a config can run any code with your privileges when the engine loads it.
  Only ever source a config you trust. Treat an untrusted `hyperlane.conf` (or an
  untrusted `HYPERLANE_CONFIG` path) exactly as you'd treat any script you're
  about to run.
- **`reap` / `stop` send signals to local PIDs.** `reap` is deliberately scoped to
  a single checkout's **out-of-lane strays** — it never signals another checkout
  and never an in-lane process. A bug that widened that scope (signalling a PID it
  shouldn't, or another checkout's process) is a security-relevant defect; please
  report it.
- **The launch hooks exec project commands.** `launch`/`start` run whatever the
  config's hooks define, in your shell. The engine adds a fail-closed port check
  in front of them, but the commands themselves are project-supplied — they are as
  trusted as the config that declares them.

hyperlane does not store or transmit secrets. Note, however, that a project's own
**env hook may emit secrets into the generated `.lane.env`** (e.g. a per-lane DB
URL or token). That file is gitignored by mandate and lives only in your local
checkout — keep it that way, and never commit it. `hyperlane guard` and the
pre-commit hook fail closed if any project-local file (including `.lane.env`)
becomes tracked. See [CONTRIBUTING.md](CONTRIBUTING.md) and PROTECTION.md.

Reports about any of the above are especially welcome.

## Supported versions

hyperlane is pre-1.0; only the latest `main` is supported. Fixes land there first.
