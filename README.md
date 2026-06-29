# hyperlane

**Give every parallel git checkout its own lane.**

You keep several checkouts of the same repo side by side — one per branch, one per
agent, one per experiment. They all run the same dev stack, so they all default to
the same ports. Boot two at once and they collide: the second can't bind, or it
binds a *stale* leftover and now one checkout's frontend is quietly talking to
another's backend. Nothing errors. It just lies — and you lose an afternoon to a
bug that was really a port collision.

hyperlane fixes that. Each checkout gets a **deterministic port lane** (a fixed
offset) derived from its name, so two checkouts can never contend for the same
port. Plus a conflict **doctor**, **fail-closed launchers** that refuse to start
on someone else's lane, and a one-command teardown.

```console
$ lane
CLONE              LANE     API($)            WEB($)            WORKER($)
──────────────────────────────────────────────────────────────────────────
myapp              primary  8080 OK pid=4121  3000 OK pid=4144  9000 free
myapp-a            a        8081 OK pid=8830  3001 OK pid=8﻿852  9001 free
myapp-b            b        8082 free         3002 CONFLICT ⚠   9002 free
                                              └─ squatted by myapp-c — `lane reap c`
```

- 🛣️ **Deterministic lanes** — `myapp-a` is *always* `+1` (api 8081, web 3001…); `myapp-b` is `+2`. No mental math, no surprises.
- 🩺 **Conflict doctor** — one glance shows who owns what and who's squatting whose ports.
- 🚦 **Fail-closed launch** — `lane start b` *refuses* to boot onto a port another checkout holds, instead of silently cross-wiring.
- 🧹 **Surgical cleanup** — `lane reap` kills only a checkout's *out-of-lane* strays, never another session's work.
- 🪶 **Zero dependencies** — pure bash (3.2+, stock macOS) and the POSIX userland. No runtime, no package manager, nothing to install but the scripts.
- 🔒 **Public-safe by design** — the engine is generic; *your* paths, services, and secrets live in a gitignored config the tool refuses to let you commit.

---

## Install

```sh
git clone https://github.com/justinjkline/hyperlane ~/.hyperlane
~/.hyperlane/install.sh        # wires the `lane` command into your shell + a pre-commit guard
exec $SHELL                    # reload your profile (or open a new terminal)
```

Then tell hyperlane about your project (this file is **gitignored** — it holds
your paths and possibly secrets):

```sh
cp ~/.hyperlane/hyperlane.conf.example ~/.hyperlane/hyperlane.conf
$EDITOR ~/.hyperlane/hyperlane.conf
```

---

## The lane model

A **lane** is a port offset, derived from a checkout's name:

| Checkout | Lane | Offset | api (base 8080) | web (base 3000) |
|---|---|---|---|---|
| `myapp` (primary) | `primary` | 0 | 8080 | 3000 |
| `myapp-a` | `a` | 1 | 8081 | 3001 |
| `myapp-b` | `b` | 2 | 8082 | 3002 |
| … `myapp-z` | `z` | 26 | 8106 | 3026 |
| `myapp-wip-auth` | `wip-auth` | 27+ | 8107 | 3027 |

For any service with port base **B** on lane **L**, its port is **B + L**.

- The **primary** checkout owns lane 0 — the default, un-offset ports — by design.
- Single-letter suffixes `a`–`z` get fixed offsets 1–26. Intuitive, stable forever.
- Any other name (worktrees, descriptive branches) gets the next free offset ≥27,
  recorded in a machine-local `.lanes` registry so it's **remembered and
  collision-free without limit**.

The database, Redis, and other shared backing services stay shared — lanes isolate
the per-checkout *service ports* (and any per-lane on-disk state you set up), which
is exactly what collides.

---

## Commands

The `lane` command wraps the engine with friendly verbs. `<c>` is a lane letter
(`a`), a full name (`myapp-c`), `primary`, or a path.

```
lane                      lane table (ports + conflicts)        [doctor | status | ls]
lane setup <c|all>        generate <c>/.lane.env (+ per-lane setup hook)
lane env <c>              load <c>'s lane ports into THIS shell
lane cd <c>               cd into checkout c
lane ports <c>            echo "PORT PORT PORT" for c's services
lane verify <c>           read-only isolation assertion (safe to run anytime)
lane guard                fail if a project-local file got tracked/staged

# launch — foreground, one service per terminal (services come from your config):
lane <service> <c>        e.g.  lane api c   ·   lane web c

# launch — background, all services at once:
lane start <c>            run every service, logs → <c>/.lane-logs/
lane logs  <c> [service]  tail those logs
lane stop  <c>            kill whatever holds c's lane ports
lane open  <c>            open c's web service in the browser
lane reap  <c>            kill ONLY c's out-of-lane strays (safe; never another checkout)
```

### A typical session

```sh
lane setup c          # one-time: write c's .lane.env (+ any per-lane setup)
lane start  c         # boot api+web+worker in the background on lane c (8083/3003/9003)
lane open   c         # → http://localhost:3003
lane logs   c         # watch them
lane stop   c         # tear it down
```

Prefer separate panes? Run `lane api c`, `lane web c`, `lane worker c` in three
terminals instead of `lane start c`.

---

## Configuration

Everything project-specific lives in `hyperlane.conf` — a **sourced bash file**
(which is why the tool needs no config parser and your hooks can be plain shell
functions). The full, commented schema is in
[`hyperlane.conf.example`](./hyperlane.conf.example). The essentials:

```sh
HYPERLANE_ROOT="$HOME/Sites/myapp-multi"   # where the parallel checkouts live
HYPERLANE_PRIMARY="$HOME/Sites/myapp"      # the primary checkout (owns lane 0)
HYPERLANE_PREFIX="myapp"                    # clones are named myapp-<label>

HYPERLANE_SERVICES=( "api:8080" "web:3000" "worker:9000" )   # name:portbase
HYPERLANE_OPEN_SERVICE="web"                                 # what `lane open` opens

# one launch function per service — runs with the lane env sourced ($API_PORT etc.)
hyperlane_launch_api() { cd "$LANE_CLONE/api" && exec ./run-server --port "$API_PORT"; }
hyperlane_launch_web() { cd "$LANE_CLONE/web" && exec ./node_modules/.bin/vite --port "$WEB_PORT"; }

# OPTIONAL hooks: hyperlane_env_hook (extra per-lane env/secrets), hyperlane_setup_hook
# (one-time per-lane on-disk state), hyperlane_verify_hook (extra isolation checks).
```

Each service's lane port is exported into `<c>/.lane.env` as `<NAME>_PORT`
(uppercased, `-`→`_`): `api` → `$API_PORT`, `web-ui` → `$WEB_UI_PORT`. See the
[`examples/`](./examples/) directory for ready-to-adapt Rails, Node, and
advanced-daemon configs.

---

## The one rule: project config is local, always

The engine you clone is **generic and public**. Your `hyperlane.conf` (and
`.lanes`, `.lane.env`, anything `*.local.*`) is **gitignored by mandate** — it
carries machine paths and possibly secrets, and must never reach a public repo.

This isn't just a `.gitignore` entry you can forget. `hyperlane guard` **fails**
if any project-local file is tracked or staged, and `install.sh` wires it into a
**pre-commit hook**, so the mistake is caught before it ever leaves your machine.

```console
$ git add -f hyperlane.conf && git commit -m "oops"
✗ hyperlane guard: project-LOCAL files are STAGED for commit:
    hyperlane.conf
  These files carry machine paths and possibly secrets. They must stay LOCAL.
```

That's what makes hyperlane safe to open-source *and* safe to use on a private
product in the same breath: the secrets structurally cannot live in the shared
artifact.

---

## How it works (under the hood)

- **`hyperlane`** — the engine. All the lane math, the conflict `doctor`, the
  fail-closed `launch`/`check`, `reap`, `verify`, per-checkout `env` generation,
  and the `guard`. Reads your config; ships no project strings of its own.
- **`lane.sh`** — a small sourced shell function (`lane`) that wraps the engine
  with friendlier verbs, background launchers, and tab-completion (bash + zsh).
- **`install.sh`** — wires `lane` into your profile and installs the pre-commit guard.

Ownership is resolved honestly: the doctor finds *who* holds a port by walking the
listening PID back to its working directory, so "CONFLICT" means a genuinely
foreign checkout — not just "something's on the port."

---

## Contributing

Issues and PRs welcome. hyperlane stays small, fast, and dependency-light. The
local gate (which CI mirrors on Linux and macOS) is `shellcheck` + `bash -n` + a
smoke test — see [CONTRIBUTING.md](./CONTRIBUTING.md). Security issues go through
[private reporting](./SECURITY.md), never a public issue.

The project's reasoning is documented in its pillars —
[WISDOM](./WISDOM.md) (the *why*), [PROTECTION](./PROTECTION.md) (the invariants),
[GUIDANCE](./GUIDANCE.md) (the *how*) — and [CLAUDE.md](./CLAUDE.md) is the
operating contract for working in the repo.

## License

[MIT](./LICENSE) © 2026 Justin Kline
