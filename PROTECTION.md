# PROTECTION.md — hyperlane Immune System

> **Scope**: Boundaries, invariants, and guards for this repository.
> **Pillars**: [CLAUDE.md](./CLAUDE.md) | [WISDOM.md](./WISDOM.md) | [GUIDANCE.md](./GUIDANCE.md)

---

Protection is not paranoia — it is institutional care. Everything here should be
**enforceable, testable, and fail-closed where safety matters**. The goal is to
make the dangerous thing hard, and to make it survivable when prevention fails.

> **When to update**: see [GUIDANCE.md](./GUIDANCE.md) "Pillar Update Protocol".
> A PROTECTION entry should name the **trigger**, the **risk class**, the
> **control** (what prevents it), and the **proof path** (how you verify the
> control works).

---

## 1. Destructive Action Prevention

### 1.1 Never Delete Untracked Files
**Risk class: DATA LOSS — UNRECOVERABLE.** Untracked files may be hours of work-in-progress that git cannot recover.
- **NEVER** run `git clean`, `rm -rf`, or otherwise delete untracked files without explicit user approval.
- **NEVER** run `git checkout -- .` / `git restore .` / `git reset --hard` on uncommitted changes without confirming.
- Before any destructive operation, run `git status` and list exactly what would be affected.
- If files must be removed, **commit or stash them first**. When in doubt, ask.

### 1.2 Branch Safety
- Never force-push to `main`.
- Never amend or rewrite published commits without an explicit request.
- Never skip hooks (`--no-verify`) — the pre-commit hook runs `hyperlane guard` (see §2).
- Create feature branches for non-trivial changes.

### 1.3 File Overwrite Protection
- Always read a file before writing to it — prevents clobbering content you haven't seen.
- Never `Write` over an existing file without reading it first; prefer `Edit` for modifications.
- When creating a new file, confirm the path doesn't already exist.

### 1.4 `reap` and `stop` Send Signals — Stay In Lane
**Risk class: KILLING ANOTHER SESSION'S WORK.** hyperlane sends `SIGTERM` to listening processes. The whole design premise is that parallel checkouts may each hold live, in-flight work you cannot see.
- `reap <checkout>` must **only** TERM listeners that are (a) owned by that checkout (resolved by the PID's cwd) **and** (b) on an out-of-lane port. It must never touch another checkout's processes, nor the target's own in-lane ports. This is the controlled cleanup path; keep it conservative.
- `stop <checkout>` kills whatever holds that checkout's *own* lane ports — scoped by port, by design.
- A change that broadens either to kill by name-match, by port alone, or across checkouts is a bug even if it "works." Verify against the multi-checkout case before trusting it.

---

## 2. Secrets, Project-Local Config & Public-Repo Safety
**Risk class: SECURITY-CRITICAL — IRREVERSIBLE ONCE PUSHED.** This is a public, world-readable repository, and the tool's entire model is "generic public engine + machine-local project config."

### 2.1 The Gitignore Mandate (THE load-bearing rule)
Project-specific configuration is **local by mandate** and must NEVER be committed:
- `hyperlane.conf` (real config — carries machine paths, clone names, and possibly secrets via its env hook)
- `*.local` / `*.local.*` (any project-local override or context, e.g. a per-project `CLAUDE.local.md`)
- `.lanes` (the machine-local lane registry), `.lane.env` (generated per-checkout env), `.local-*` (shared key/secret files)
- `.lane-pids` (the machine-local launch PID registry — the Windows cwd-substitute mapping launched PIDs to checkouts; machine-specific, carries no secrets but is purely local state, see [WISDOM §11](./WISDOM.md))

**Control**: these patterns are in `.gitignore`, AND `hyperlane guard` **errors (exit non-zero)** if any such file is *tracked* or *staged*. `install.sh` wires `guard` into a pre-commit hook so the mistake is caught before it leaves the machine. `guard` also runs as part of `lane doctor` workflows and the `%` close-out audit.
**Three-way sync invariant**: the project-local set is declared in **three** places that must stay identical — the `.gitignore` patterns, the `cmd_guard` regex in `hyperlane`, and this list. Adding a new local file (as `.lane-pids` was) means updating all three in the same change; a file ignored but not guarded (or vice-versa) is a latent leak.
**Proof path**: `git ls-files | grep -E '<the guard patterns>'` returns nothing; a deliberate `git add -f hyperlane.conf` followed by `hyperlane guard` exits 1 with a clear message.
**Why fail-closed, not documented-only**: a comment that says "don't commit this" is advisory; under deadline pressure, advisory loses. The guard makes the dangerous thing *fail*, not *warn*.

### 2.2 General Secret Hygiene
- Never commit secrets, API tokens, credentials, absolute machine paths, or personal/local config to tracked files. They belong in the gitignored config.
- Report security issues through private reporting (see [SECURITY.md](./SECURITY.md)), never in a public issue or PR.
- Assume every commit is permanent: a secret pushed and later removed is still in history and must be rotated.

---

## 3. Project Invariants

These are hyperlane's load-bearing design rules. Violating one is a bug even if a quick test looks green.

### 3.1 The Engine Ships No Project Strings
`hyperlane` and `lane.sh` must contain **zero** project-specific values — no clone names, no paths, no service names, no ports beyond the neutral default *bases the user supplies via config*. Everything project-specific comes from the sourced config. A hardcoded `~/Sites/...`, a literal app name, or a baked-in service is a regression: it re-couples the public tool to one project (the exact thing the genericization undid). Grep the engine for any non-generic string before shipping.

### 3.2 Lane Assignment Is Deterministic and Collision-Free
A checkout's lane (port offset) must be stable forever and never collide with another's:
- primary = 0; single-letter suffixes `a`–`z` = 1–26 (reserved, never registered);
- any other name = the next free offset ≥27, **persisted** in the `.lanes` registry so it survives restarts and never reassigns.
Any change to `lane_of()` must preserve: same name → same lane, and two distinct names → two distinct lanes. A scheme that hashes into a fixed range (and can therefore collide) is forbidden — the registry exists precisely to make assignment unbounded and collision-free.

### 3.3 Launch Is Fail-Closed
`hyperlane launch` (and the `lane` wrapper's launchers) must **refuse to start** a service if its lane port is held by a *different* checkout, and exit non-zero. "Free" or "already owned by this checkout" may proceed; a foreign owner must stop the launch with a message pointing at `reap`. A launcher without this guard is how a checkout ends up squatting another lane — the original sin this tool exists to prevent. `check` is the preflight primitive; keep `launch` built on it.

### 3.4 Zero Runtime Dependencies; Bash 3.2 Floor
The tool must run on a stock macOS box with no installs: bash 3.2 + the POSIX userland. No bash-4-only syntax (`${x^^}`, `declare -A`, `mapfile`, associative arrays). No language runtime. A new dependency on an external command must degrade gracefully when absent (skip with a note, don't crash) and earn its place.

### 3.5 Callbacks Must Not Trip `errexit`
The engine runs under `set -euo pipefail`. Helpers that iterate services via a callback (`each_service`) invoke the callback with `|| true`, because callbacks use their exit status to signal "did this entry match?" — not to report an error. A bare callback returning non-zero would abort the loop mid-iteration. Preserve this. (See [WISDOM.md](./WISDOM.md) — this bug shipped once and silently broke `launch`/`openurl`.)

### 3.6 Port Backends: lsof Path Unchanged; Windows Degrades Fail-Closed
hyperlane resolves listeners/ownership through one of two backends, chosen once by
OS (`HL_PORT_BACKEND`): `lsof` on macOS/Linux, `netstat`+`taskkill` on Windows
(Git Bash/MSYS/Cygwin). Two rules are load-bearing:
- **The lsof path must stay byte-for-byte the behavior it always had.** Backend
  selection is by `uname -s`, *not* by probing whether `lsof` is on PATH — a stray
  MSYS `lsof` on Windows can read neither winpids nor cwd and would mislead the
  doctor. macOS/Linux must never silently switch backends.
- **The Windows degradation must be fail-closed and one-sided.** Without a
  per-process cwd, ownership comes from the launch registry ([WISDOM §11](./WISDOM.md));
  a miss must report **CONFLICT**, never a false "OK", and `reap` must **under**-kill
  (skip anything it can't attribute), never over-kill — preserving §1.4. A change
  that makes an unknown owner read as OK, or that signals across the MSYS/Windows
  PID boundary with `kill` instead of `taskkill` ([WISDOM §12](./WISDOM.md)), is a
  bug even if a quick test looks green.

> Add new project invariants here as they are discovered. Each should state what
> must hold, why it's load-bearing, and how a violation manifests.

---

## 4. Verification Is Fail-Closed
A change is not "done" until the local gate passes — `shellcheck hyperlane lane.sh install.sh`, `bash -n` on each, and a manual end-to-end run against a throwaway `HYPERLANE_CONFIG` (CI runs the same on Linux and macOS). Missing or skipped sources of truth must **error, not warn**: a silent skip reads as "covered everything" when it didn't. If a step was skipped or a check failed, say so plainly with the output — never report success you haven't proven.
