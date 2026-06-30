# WISDOM.md — hyperlane Institutional Memory

> The accumulated **why** behind design decisions, incidents, and hard-won
> principles in this repository. Each entry records: **what happened**, **what we
> decided**, **why**, and **what to do differently**.
>
> **Pillars**: [CLAUDE.md](./CLAUDE.md) | [PROTECTION.md](./PROTECTION.md) | [GUIDANCE.md](./GUIDANCE.md)

---

## How to Use This File

- **Stuck?** Search here before forming a theory — someone may have already paid for this lesson.
- **Adding an entry?** Use the next free `§N`, place it in the right section, and follow the four-part shape from [GUIDANCE.md](./GUIDANCE.md) "Pillar Update Protocol": trigger, decision/pattern, evidence, expected effect.
- **Cross-referencing?** Write `WISDOM §N` so references stay greppable.

---

## Foundational Principles

> These evergreen principles apply to every task in this repo.

### §1. The Three-Pillar System
Three living documents capture institutional knowledge:
- **WISDOM** — institutional memory: the accumulated *why*.
- **PROTECTION** — immune system: boundaries, invariants, fail-closed guards.
- **GUIDANCE** — nervous system: how intent becomes behavior.

AI agents and human contributors both lose context between sessions. The pillars are the mechanism for compounding knowledge across that gap — without them every session starts from zero. **Every significant change should sharpen at least one pillar.** If a PR ships and no pillar got better, institutional learning was lost.

### §2. Why Port Lanes Exist
hyperlane exists because **parallel checkouts of the same repo silently collide**. Every checkout's dev stack defaults to the same ports (the backend on 8080, the frontend on 3000, a daemon on some fixed port). Run two at once and the second's process can't bind, or worse — it binds a stale leftover, and now one checkout's frontend is talking to another's backend, or a daemon is serving the wrong workspace. *Nothing errors.* It just lies, and you lose hours chasing a bug that is really a port collision. The fix is to give each checkout a **deterministic port offset** derived from its name, so two checkouts can never contend for the same port. Determinism is the point: the same checkout always gets the same lane, so muscle memory and tooling stay stable. (See [README.md](./README.md).)

### §3. Fail Closed, Don't Warn
The tool's value is *preventing silent cross-talk*. A guard that warns instead of refusing is theater: under deadline pressure, a warning is ignored and the collision happens anyway. So the load-bearing controls **exit non-zero and stop the action**: `launch` refuses to start on a foreign lane's port ([PROTECTION §3.3](./PROTECTION.md)); `guard` fails the commit when project-local config is tracked ([PROTECTION §2](./PROTECTION.md)). Make the dangerous thing *fail*, not *warn*.

### §4. The Engine Is Generic; Config Is Local
The engine (`hyperlane`, `lane.sh`) is public and ships **zero project strings**. Everything project-specific — paths, clone names, services, launch commands, secrets — lives in a **sourced bash config** that is gitignored by mandate. This split is what lets the same tool serve any multi-checkout project *and* be safely open-sourced: the public artifact can never leak a path or a secret because those structurally live in a file that `hyperlane guard` refuses to let you commit. A hardcoded project value in the engine breaks both properties at once ([PROTECTION §3.1](./PROTECTION.md)).

### §5. Lean Beats Clever — Zero Dependencies Is a Feature
hyperlane is pure bash (3.2+) plus the POSIX userland. No runtime, no package manager, no install step beyond copying scripts. The cost of a dependency is paid forever (supply-chain surface, version skew, "works on my machine"); a tool that runs on a stock macOS box with nothing installed is one you can drop into any repo instantly. Default to "no new dependency" and justify "yes." A config is *sourced bash* precisely so hooks can be plain functions with no parser or schema library.

### §6. Reproduce Before You Theorize
Wrong root-cause diagnoses come from reasoning off symptoms and stale state. Pull first, reproduce the failing call against a throwaway config, read the real error — *then* form a hypothesis. Bash especially punishes guessing (see §7–§9). (CLAUDE.md Workflow §1, §6.)

---

## Lane Model & Incidents

### §7. Silent Cross-Lane Bleed Is the Failure Mode to Hunt
**Trigger**: the multi-hour debugging spiral that motivated this tool — two checkouts on the same default ports, where a stale process on `:8080`/`:3000` made one checkout's stack quietly serve or talk to another's, and a background daemon dialed a *shared* fixed port so a config push from checkout B landed on checkout A's daemon.
**Decision**: port-ownership alone isn't enough; isolation is end-to-end. `verify` exists to assert the *whole* chain — this checkout owns its lane ports, no foreign process squats the primary's defaults, and (via the project's `hyperlane_verify_hook`) the project's own call-home/daemon actually points at *this* lane. A bonus hazard for projects sharing one backing store across checkouts: divergent per-checkout secrets (e.g. an encryption key) silently corrupt shared rows — so such projects force one shared key from a gitignored file in their env hook (see `examples/advanced-daemon.conf`).
**Expected effect**: never trust a cross-service test in a lane you haven't `verify`'d. Treat "it works but talks to the wrong thing" as the default suspicion, not an edge case.

### §8. `set -e` + a Callback That Returns Non-Zero Aborts the Loop
**Trigger**: during the initial build, `hyperlane openurl` and `hyperlane launch` silently found *no* service. Root cause: under `set -euo pipefail`, `each_service` called a callback as a bare command; the callback ended in `[ "$1" = "$want" ] && base=$2`, which returns 1 when the test fails (the non-matching iterations). A bare command returning non-zero trips `errexit` and **aborted the loop on the first non-match**, so it never reached the wanted service.
**Decision/Evidence**: `each_service` now invokes the callback with `|| true` (see the engine's `each_service`), because callbacks use exit status to signal "did this entry match?", not to report an error. The internal `[ ] && …` is protected by being part of an AND-list, but the *function's overall return value* propagates to the call site where it is a bare command — that's what aborts.
**Expected effect**: any helper that fans a callback over a list under `set -e` must tolerate callback exit codes (`|| true`), or the callback must always `return 0`. Codified as [PROTECTION §3.5](./PROTECTION.md).

### §9. Bash Dynamic Scope: `local` in a Loop Helper Shadows the Caller
**Trigger**: same build, related symptom. An early `each_service` declared `local base` (to split `name:base`). A callback that did `base=$2` to hand a result back to its caller was instead writing `each_service`'s *own* local `base`, because bash uses **dynamic scope** — the nearest `local base` in the call chain wins.
**Decision/Evidence**: `each_service`'s internals are `__`-prefixed (`__es_cb`, `__es_entry`) so they can't shadow a caller's variables, and callbacks pass results back through plainly-named caller locals.
**Expected effect**: in any function whose internals are visible to a callback it invokes, give the internals obscure names. Don't reuse common names (`name`, `base`, `port`, `dir`) as a helper's locals when a callback might want to write them. Related: macOS ships **bash 3.2**, so no `${x^^}`/`declare -A` — uppercase via `tr`, keep service lists as indexed `name:base` arrays ([PROTECTION §3.4](./PROTECTION.md)).

### §10. Source the Project's Own Env First, Then Override With Lane Values
**Trigger**: a lane's stack booted "usable but subtly broken" — secrets/flags the app needs live in the *project's* own `.env`-style files, not in hyperlane. Loading only the lane overrides left those unset; loading them *after* the lane overrides let a stale project value (e.g. an explicit URL pinned to a shared port) win and re-introduce the collision.
**Decision/Pattern**: the lane env is composed in a deliberate order — the project's own env hook may pull in the app's secrets/flags, then the lane's `*_PORT` / identity overrides are emitted so they **win last**. When a project pins an absolute URL/port that must be re-pointed per lane, the env hook overrides it explicitly rather than hoping the port-derived value takes precedence.
**Expected effect**: when wiring a project's `hyperlane_env_hook`, think in two layers — real project env first, lane overrides last — and override any project value that hardcodes a shared port. (Generic pattern shown in `examples/advanced-daemon.conf`.)

---

## Portability

### §11. Windows Has No Per-Process CWD — Ownership Falls Back to a Launch Registry
**Trigger**: porting hyperlane to Windows (Git Bash/MSYS). The whole conflict
model rests on `owner_checkout_of_pid` reading a listening PID's **working
directory** (via `lsof -d cwd`) to decide which checkout owns a port. Windows
exposes no supported way to read an arbitrary process's cwd — not via `netstat`,
`tasklist`, or `Get-CimInstance Win32_Process` (which surfaces command line and
exe path, but not cwd). So the cwd-based attribution simply cannot be ported.
**Decision/Pattern**: on the netstat backend, substitute cwd-reading with a
**launch-time PID registry** (`$HYPERLANE_ROOT/.lane-pids`, `winpid<TAB>dir`).
`cmd_launch` can't know the eventual listener PID up front — the launch hook
`exec`s, usually into a child-spawning runner (`npm run dev` → node, `vite`,
`puma`) — so a **detached watcher** (`_record_owner_async`) polls the lane port
until it binds and records *whoever actually bound it*. This is correct for exec,
non-exec, and child-spawning hooks uniformly, because it observes the real
listener rather than guessing. A registry **miss** returns empty owner →
`port_status` reports CONFLICT. That degradation is **fail-closed and one-sided**:
the only error it can make is over-reporting CONFLICT (and under-killing in
`reap`), never a false "OK" or killing a process it can't attribute. The cost is
that a service started *outside* hyperlane on Windows reads as a foreign squatter
(`owner=?`) rather than being recognized — acceptable, because the safe failure
is "investigate," not "silently cross-wire."
**Evidence**: verified on a real Windows box — `lane launch` records the bound
PID, `doctor` then shows `OK pid=N` for the owning checkout, and a raw
(non-hyperlane) listener on another lane's port shows `CONFLICT pid=N owner=?`.
**Expected effect**: never expect Windows to attribute a process hyperlane didn't
launch. On macOS/Linux the lsof cwd path is unchanged and still attributes *any*
listener. Codified as [PROTECTION §3.6](./PROTECTION.md).

### §12. MSYS and Windows Live in Different PID Namespaces — Signal via `taskkill`
**Trigger**: the first Windows ownership design recorded `$$` at launch. It never
matched. Two reasons, the second fatal: (1) the launch hook `exec`s into a
child-spawning runner, so the listener isn't `$$`; and (2) **Git Bash `$$` is an
MSYS PID, while `netstat`/`taskkill` speak Windows PIDs** — measured on this box,
`$$`=892 vs the Windows PID 9304 for the same shell. A recorded MSYS PID can
*never* equal a netstat-derived Windows PID, so the registry would always miss.
**Decision/Pattern**: on the netstat backend, **everything that identifies or
signals a process goes through the Windows tools** and the Windows PID namespace:
discovery via `netstat -ano`, termination via `taskkill //PID <winpid> //F`. MSYS
`kill`/`kill -0` must not touch a netstat PID. Two Git Bash gotchas: a leading
`/PID` gets POSIX-path-mangled into `C:/...`, so use the **double slash**
(`//PID`, `//F`); and `//F` (force) is the pragmatic TERM-equivalent because
console dev servers ignore a graceful close. The watcher records the Windows PID
naturally because it reads it back from `_pids_on_port` (netstat), not from `$$`.
**Evidence**: `_pids_on_port` returns the same PID `netstat`/Task Manager show;
`killport` stops it where an MSYS `kill` silently no-ops.
**Expected effect**: when adding any Windows process op, source the PID from
`netstat` and signal with `taskkill //…`; never cross the MSYS/Windows PID
boundary. Locale note: don't match the word "LISTENING" (Windows localizes it) —
identify a listener by its foreign address ending in `:0`.

---

## Section Number Registry

| §N | Title | Section |
|----|-------|---------|
| §1 | The Three-Pillar System | Foundational Principles |
| §2 | Why Port Lanes Exist | Foundational Principles |
| §3 | Fail Closed, Don't Warn | Foundational Principles |
| §4 | The Engine Is Generic; Config Is Local | Foundational Principles |
| §5 | Lean Beats Clever — Zero Dependencies | Foundational Principles |
| §6 | Reproduce Before You Theorize | Foundational Principles |
| §7 | Silent Cross-Lane Bleed Is the Failure Mode | Lane Model & Incidents |
| §8 | `set -e` + Non-Zero Callback Aborts the Loop | Lane Model & Incidents |
| §9 | Bash Dynamic Scope Shadows the Caller | Lane Model & Incidents |
| §10 | Source Project Env First, Lane Overrides Last | Lane Model & Incidents |
| §11 | Windows Has No CWD — Launch Registry for Ownership | Portability |
| §12 | MSYS vs Windows PID Namespaces — Signal via `taskkill` | Portability |

> Add new entries below with the next free `§N` and register them above.
