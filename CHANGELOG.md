# Changelog

All notable changes to hyperlane are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **Windows support** (Git Bash / MSYS / Cygwin) — still zero-install. A port
  backend is chosen once by OS (`HL_PORT_BACKEND`): `lsof` on macOS/Linux
  (unchanged), `netstat`/`taskkill` on Windows. Since Windows exposes no
  per-process working directory, ownership is attributed via a machine-local
  **launch PID registry** (`.lane-pids`) populated by a detached watcher when a
  service is started through `lane`; an unattributable listener reads as a
  fail-closed `CONFLICT (owner=?)`. See README "Platform support" and
  WISDOM §11–§12.
- **`hyperlane killport <port>`** and **`hyperlane pids <port>`** — config-less
  port utilities that centralize all OS-aware listener discovery/termination in
  the engine; `lane stop` now uses `killport`.
- **`.gitattributes`** pinning shell scripts to LF so Windows checkouts don't get
  CRLF (which breaks the shebang and shellcheck).
- CI now also runs on **windows-latest** (under Git Bash), exercising the
  netstat/taskkill backend; `bash -n` and the smoke test run on all three OSes.

### Changed

- `.lane-pids` added to the gitignore mandate, the `hyperlane guard` regex, and
  PROTECTION §2.1 (the three must stay in sync).

## [0.1.0] - 2026-06-29

First public release: a zero-dependency bash CLI that gives every parallel git
checkout of the same repo its own deterministic **port lane**, so you can run
several checkouts side by side without port collisions, stale-leftover theft, or
silent cross-wiring.

### Added

**Core engine (`hyperlane`)**

- **Config-driven port-lane engine.** A checkout's lane (a port offset) is derived
  deterministically from its basename — the primary owns lane 0 (the default,
  un-offset ports); single-letter clones `-a…-z` get fixed offsets 1–26; any other
  label is assigned the next free offset ≥27, persisted in `.lanes` so it stays
  collision-free without limit. For a service with port base `B` on lane `L`, the
  port is `B + L`. The engine ships **zero project strings** — everything
  project-specific lives in a sourced `hyperlane.conf`.
- **`hyperlane doctor`** — the conflict table: every checkout, its lane, its
  service ports, and who is currently squatting whose ports.
- **`hyperlane env <checkout>`** — generate that checkout's `.lane.env` (every
  service pinned to its lane port, exported as `<NAME>_PORT`), source-able before
  launch.
- **`hyperlane ports <checkout>`** — echo a checkout's resolved service ports.
- **Fail-closed launchers — `hyperlane launch <checkout> <service>`** — sources the
  lane env and **refuses to start** if the lane port is held by a *different*
  checkout, so a misfire errors loudly instead of cross-wiring two stacks.
- **`hyperlane check <checkout> [service|all]`** — the preflight primitive (exit 0
  = the port is free to take), for scripting your own launchers.
- **`hyperlane reap <checkout>`** — TERM **only** this checkout's out-of-lane
  strays; never another checkout, never an in-lane process.
- **`hyperlane verify <checkout>`** — read-only isolation assertion (exit 0 =
  clean), for CI or a pre-launch gate.

**Gitignore enforcement**

- **`hyperlane guard`** + an installed **pre-commit hook** — fail closed if any
  project-local file (`hyperlane.conf`, `*.local.*`, `.lanes`, `.lane.env`) is
  tracked or staged. These files carry machine paths and possibly secrets and are
  gitignored by mandate; the guard keeps them out of the public repo.

**Shell wrapper (`lane.sh`)**

- The sourced `lane` command — friendlier verbs over the engine (`lane`,
  `lane setup`, `lane cd`, `lane env`, `lane start`, `lane stop`, `lane logs`,
  `lane open`, `lane reap`, `lane verify`) plus per-checkout background launchers.
- **`install.sh`** — wires the `lane` command into your shell profile, re-asserts
  the engine's exec bits, and installs the pre-commit guard hook.

**Project & governance**

- The four pillars — `CLAUDE.md`, `PROTECTION.md`, `GUIDANCE.md`, `WISDOM.md` —
  plus a Code of Conduct, a security policy, a PR template, and CI on Linux and
  macOS (`shellcheck` + `bash -n` + an end-to-end smoke test).
- A documented `hyperlane.conf.example` schema and example configs under
  `examples/`.

[Unreleased]: https://github.com/justinjkline/hyperlane/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/justinjkline/hyperlane/releases/tag/v0.1.0
