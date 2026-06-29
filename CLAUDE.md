# CLAUDE.md — hyperlane Operating Principles

> **Scope**: Cross-cutting principles for working in this repository.
> **Pillars**: [WISDOM.md](./WISDOM.md) | [PROTECTION.md](./PROTECTION.md) | [GUIDANCE.md](./GUIDANCE.md)
> **Doc map**: see [Project Documentation](#project-documentation) below.

---

# What This Is

hyperlane gives every parallel git checkout of the same repo its own
deterministic **port lane**, so you can run several checkouts at once — different
branches, different agents — without their dev stacks colliding on the same
ports. It is a **small, fast, zero-dependency bash CLI** and a **public,
MIT-licensed open-source project**.

Two values shape every decision here: keep it lean (pure bash, no runtime, no
package manager — just the POSIX userland), and keep the *why* legible. The code
is heavily commented because the reasoning — every lane rule, every fail-closed
guard — was paid for in real debugging time and matters more than the mechanism.

This file is the canonical operating contract. `AGENTS.md`, if present, is a
compatibility shim that points here — no split-brain docs.

---

# Project Documentation

Read the relevant doc before working in its area — don't reconstruct what's
already written down.

**The engine & its contract:**

| Doc | What it is |
|---|---|
| [README.md](./README.md) | What hyperlane is, the lane model, and the quickstart. The front door. |
| [hyperlane.conf.example](./hyperlane.conf.example) | The **config schema** — the documented, sourced-bash contract a consuming project fills in. The source of truth for what a config may declare (`HYPERLANE_*` vars, the `hyperlane_launch_*`/`_env_hook`/`_setup_hook`/`_verify_hook` functions). If you add or change a config key, update this template in the same change. |
| [examples/](./examples/) | Worked example configs (Rails, Node, an advanced daemon stack). Keep them valid and current. |

**The four pillars:**

| Doc | What it is |
|---|---|
| [WISDOM.md](./WISDOM.md) | Institutional memory — the accumulated *why* behind the lane model and its guards. |
| [PROTECTION.md](./PROTECTION.md) | Immune system — boundaries, invariants, and fail-closed rules (including the gitignore mandate). |
| [GUIDANCE.md](./GUIDANCE.md) | Nervous system — how intent becomes behavior: the repeatable procedures. |

**Process & policy:**

| Doc | What it is |
|---|---|
| [CONTRIBUTING.md](./CONTRIBUTING.md) | Build/test/lint commands and the PR contract. The local gate. |
| [CHANGELOG.md](./CHANGELOG.md) | Keep current for any user-visible change. |
| [SECURITY.md](./SECURITY.md) | Private vulnerability reporting — never a public issue/PR. |
| [CODE_OF_CONDUCT.md](./CODE_OF_CONDUCT.md) | Community standards for contributors. |

**Doc maintenance is part of the change.** The README, `hyperlane.conf.example`,
and the pillars describe observable contracts — if your change alters behavior
they describe, update them in the same PR (PROTECTION's silent-skip ban applies
to docs too: a stale contract doc is a latent bug).

---

# Core Principles

- **Root-Cause Fixes, No Band-Aids**: Find the real cause. No temporary patches, no TODOs left behind, no "file an issue and move on." Senior-engineer standards. The only exception is genuinely multi-phase work that is non-critical to the current task.
- **Small, Fast, Lean — No Fluff**: Production-grade, but hyperlane stays minimal. **Zero dependencies is a feature, not an accident**: pure bash (3.2+, the macOS system bash) plus the standard POSIX userland (`lsof`, `awk`, `sed`, `find`). A new external command dependency needs a clear justification and a graceful absence path — prefer what's already there. No language runtime, ever.
- **Match the Surrounding Code**: Write shell that reads like its neighbors — same idiom, naming, and **comment density**. This codebase comments the *why*; keep doing that. A guard or lane rule a reviewer can't trace back to a reason is incomplete.
- **The Engine Ships No Project Strings**: `hyperlane` and `lane.sh` are generic and public. Everything project-specific (paths, clone names, services, secrets) lives in the **gitignored** config. A hardcoded project value in the engine is a bug (see PROTECTION §2, §3).
- **Fail Closed Where Collisions Bite**: The whole point is preventing silent cross-talk. A launcher that *might* start on a foreign lane's port, a guard that *warns* instead of *errors* — those defeat the purpose. When safety is at stake, refuse and exit non-zero.
- **Sub-Two-Minute Rule**: If a fix takes under two minutes, do it now. Don't file an issue. Stay alert for adjacent small wins while you're in the file.
- **Bugs Found In Flight**: When you spot an unrelated bug mid-task, fix it immediately (or spawn a subagent to) with a tight briefing — don't let it evaporate.
- **Issue Hygiene — Net-Negative Filing**: Before opening an issue, search existing issues for the same symptom/area and close or squash duplicates, stale, or already-fixed ones in the same pass. When you fix something, sweep open issues for related keywords and close what the fix resolved, linking the PR/commit. Close only what is *genuinely* resolved, with evidence — never to hit a quota.
- **Public Repo Discipline**: This is open source. Never commit secrets, tokens, machine-specific paths, clone names, or local config — those belong in the gitignored `hyperlane.conf` and friends. Run `hyperlane guard` (the pre-commit hook runs it for you). Security issues go through private reporting (see [SECURITY.md](./SECURITY.md)), never a public issue or PR. Assume every commit is permanent and world-readable.

**Shorthand**:
- `~` = "Did you follow CLAUDE.md?" — re-check this file against what you just did.
- `#` = "Harvest wisdom from this context window into WISDOM.md (and the other pillars as relevant)."
- `%` = "Safe to close this session? Anything dangling?" — audit uncommitted changes, unpushed commits, running background processes/subagents, incomplete tasks, unharvested wisdom, half-applied edits, and **any project-local file that slipped into tracking** (`hyperlane guard`). Report a punch list; say "clean — safe to close" only if truly nothing remains. As the final step of `%`, `git pull --rebase` the latest `main`.

---

# Workflow

## 1. Pull Before You Build
`git pull --rebase` before any task — coding *or* diagnosis. Stale local state produces wrong root-cause diagnoses and merge pain. Subagents working in worktrees: pull there too.

## 2. Plan Mode for Non-Trivial Work
Enter plan mode for anything that is 3+ steps or carries a design decision (a new lane rule, a change to how ports are derived, a new config key). If the work goes sideways mid-stream, stop and re-plan rather than pushing through a broken approach.

## 3. Survey Before You Build
Before any substantial change, survey the codebase for what already exists. The engine is small — read it end to end. Grep the domain nouns (`lane`, `port`, `checkout`, `each_service`, `port_status`), find the existing helper, read the config schema and the examples, and check the three pillars. Don't reinvent a helper that's already there.

## 4. Subagent Strategy
- Default to parallelism: one focused task per subagent, dispatched together when independent.
- Brief the vision, not just the diff: (1) what the finished change looks like, (2) how this shard fits the whole, (3) the governing principles it must respect (point at pillar sections).
- Lane discipline: no two agents touch the same file at once.

## 5. Verification Before Done — Local Checks ARE the Gate
Never mark a task complete without proving it works. Before pushing **any** branch, run the full local gate that CI runs:

```sh
shellcheck hyperlane lane.sh install.sh      # static analysis
bash -n hyperlane lane.sh install.sh         # parse check
```

Then drive the real engine end-to-end against a throwaway config (CLAUDE-safe — never touches a real setup):

```sh
H="$(mktemp -d)"
mkdir -p "$H/root/app-a" "$H/primary"
cat > "$H/cfg" <<EOF
HYPERLANE_ROOT="$H/root"
HYPERLANE_PRIMARY="$H/primary"
HYPERLANE_PREFIX="app"
HYPERLANE_SERVICES=( "api:8080" "web:3000" )
hyperlane_launch_api() { exec echo "api on \$API_PORT"; }
EOF
HYPERLANE_CONFIG="$H/cfg" ./hyperlane doctor
HYPERLANE_CONFIG="$H/cfg" ./hyperlane env a
HYPERLANE_CONFIG="$H/cfg" ./hyperlane ports a   # → 8081 3001
rm -rf "$H"
```

CI runs `shellcheck` + `bash -n` + a smoke test on Linux and macOS — a green local run is the contract. See [CONTRIBUTING.md](./CONTRIBUTING.md).

## 6. Consult WISDOM When Stuck
Before spinning wheels, check WISDOM.md. Reproduce the failing call and read the actual error *before* forming a theory. Bash has sharp edges (dynamic scope, `set -e` + non-zero callbacks, bash 3.2 vs 4+) — several are already documented there.

## 7. Self-Improvement Loop
After any correction or hard-won insight: update the relevant pillar (see [GUIDANCE.md](./GUIDANCE.md) "Pillar Update Protocol"). Proactively capture non-obvious truths — WISDOM (the *why*), PROTECTION (what can fail), GUIDANCE (how behavior is directed). Harvest before context is compressed.

---

# The Three Pillars

- **WISDOM** (`WISDOM.md`) = institutional memory — the accumulated *why*.
- **PROTECTION** (`PROTECTION.md`) = immune system — boundaries, invariants, guards, fail-closed rules.
- **GUIDANCE** (`GUIDANCE.md`) = nervous system — how intent becomes behavior: protocols and patterns.

**When to consult**: WISDOM for "why is it built this way?", PROTECTION for "what can fail?", GUIDANCE for "how should I do this?".

---

# Auto-Memory Taxonomy

Persistent memory files carry `priority: system | frequent | contextual` (default `contextual`):
- **system**: invariant truth for every task — inline a 1–2 line summary in the memory index.
- **frequent**: applies to most non-trivial work — read proactively at session start.
- **contextual**: read on demand when the index hook matches. The default; pick this when unsure.

---

# Environment

Pure bash, no toolchain to install.

- **Shell**: targets bash 3.2 (the macOS system bash) and up — avoid bash-4-only features (`${x^^}`, `declare -A`, `mapfile`). Uppercasing goes through `tr`; service lists are indexed arrays of `name:base` strings.
- **The pieces**: `hyperlane` (the engine CLI — all lane math, the doctor, fail-closed launch/reap/verify, the guard), `lane.sh` (the sourced `lane` shell function + completion), `install.sh` (profile wiring + pre-commit guard), `hyperlane.conf.example` (the config template).
- **Isolate every manual run** with a throwaway config via `HYPERLANE_CONFIG=…` pointing at `mktemp -d` directories, so you never touch a real operator's checkouts or send signals to real processes. Clean it up after.
- Lint/test: see Workflow §5 and [CONTRIBUTING.md](./CONTRIBUTING.md).

---

# Git Commits

- Author commits as **Justin Kline**. Do **not** add a "Co-Authored-By: Claude" trailer.
- Thoroughly comment and document *how it works and why it matters* — in the code and in the commit message.
- Create feature branches for non-trivial changes; never force-push `main`; never skip hooks with `--no-verify` (the pre-commit hook runs `hyperlane guard` — bypassing it risks pushing project-local config). Pull requests require maintainer review before merging (see [CONTRIBUTING.md](./CONTRIBUTING.md)).
