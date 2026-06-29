# GUIDANCE.md — hyperlane Nervous System

> **Scope**: How intent becomes behavior in this repository — protocols and patterns.
> **Pillars**: [CLAUDE.md](./CLAUDE.md) | [WISDOM.md](./WISDOM.md) | [PROTECTION.md](./PROTECTION.md)

---

GUIDANCE answers "**how should I do this?**" — the repeatable procedures that keep
work congruent with the design. WISDOM is the *why*, PROTECTION is *what must not
break*, and this file is the *how*.

---

## 1. The Pillar Update Protocol

### When to Update
Update the pillars proactively whenever:
- A surprising failure reveals a non-obvious truth (a bash gotcha, a lane edge case).
- A new guardrail or invariant is discovered.
- A pattern proves effective (or harmful).
- A recurring confusion is resolved.
- A correction from the user reveals a gap in documented knowledge.

### What to Include
Every pillar entry carries four elements:
1. **Trigger** — what happened that prompted this.
2. **Decision/Pattern** — what was decided, or the pattern identified.
3. **Evidence** — concrete file paths, function names, commit/PR links, or repro steps that anchor it.
4. **Expected effect** — how behavior should change going forward.

### Which Pillar Gets the Update
- **WISDOM.md** — "Why is it built this way?" Design decisions, the rationale behind a lane rule, past incidents.
- **PROTECTION.md** — "What could go wrong?" Boundaries, invariants, guards, safety rules.
- **GUIDANCE.md** — "How should behavior be directed?" Protocols, procedures, repeatable patterns.
- **CLAUDE.md** — Cross-session operating rules: workflow, shorthand, core principles.

### Multi-Pillar Rule
One event can teach several lessons. Update every relevant pillar and cross-link between them — e.g. a near-miss might add a PROTECTION invariant, a WISDOM entry on why it happened, and a GUIDANCE procedure to avoid it.

### Hygiene
Before adding to any pillar: (1) read the relevant section, (2) check for redundancy and merge rather than duplicate, (3) place it in the right section, (4) update or remove obsolete entries, (5) keep it tight — these are curated reference, not a changelog.

---

## 2. Adding a Feature Congruently

1. **Survey first** (CLAUDE.md Workflow §3): read the engine end to end — it's small — grep the domain nouns (`lane`, `port_status`, `each_service`, `resolve_checkout`), and find the existing helper before writing a new one.
2. **Respect the invariants** in [PROTECTION.md §3](./PROTECTION.md): the engine ships no project strings, lane assignment stays deterministic/collision-free, launch stays fail-closed, bash-3.2 floor, callbacks don't trip `errexit`.
3. **Thread config, don't hardcode**: a new project-tunable value is a new `HYPERLANE_*` key or hook — add it to `hyperlane.conf.example` with a comment explaining the *why*, and document the default. Never bake it into the engine.
4. **Match the idiom**: same naming, structure, and comment density as the surrounding shell — comment the *why*, especially for any non-obvious bash (quoting, `set -e` interactions, scope).
5. **Wire both surfaces**: most user-facing capability touches the engine (`hyperlane`) *and* the `lane` wrapper (`lane.sh`) — and often completion and `lane help`. Update all the surfaces a feature implies in the same change.
6. **Run the full local gate** before pushing (CLAUDE.md Workflow §5). It *is* the CI.

---

## 3. Testing Shell Changes

There is no unit-test framework — the tool is small bash. Verify behaviorally:
- **Static**: `shellcheck hyperlane lane.sh install.sh` (treat warnings as failures) and `bash -n` on each.
- **Behavioral**: drive the real engine against a **throwaway** `HYPERLANE_CONFIG` pointing at `mktemp -d` directories — never a real setup, because the tool reads live ports and can signal real processes ([PROTECTION §1.4](./PROTECTION.md), §3.3). Assert the observable contract: `doctor` shows the right lanes, `ports a` returns `base+1`, `env a` emits the right `*_PORT` exports, `launch a <svc>` refuses on a foreign squatter, `guard` fails on a tracked `hyperlane.conf`.
- **Edge cases to keep covered**: a multi-character checkout name (registry assignment ≥27), the primary (lane 0), a service whose name contains a `-` (the `tr`-uppercased `*_PORT` stem), and the fail-closed launch path.

---

## 4. Subagent Briefing Contract

When delegating to a subagent, the brief must convey more than the diff:
1. **The vision** — what the finished change looks like when it's done well.
2. **The fit** — how this shard connects to the rest of the system.
3. **The constraints** — the governing principles and invariants it must not violate (point at the relevant pillar sections, especially the gitignore mandate and the no-project-strings rule).
4. **The lane** — exactly which files it owns, so no two agents collide.

Cold-review your own output: a fresh, adversarial pass (your own or a subagent's) catches real blockers that a quick green run misses.

---

## 5. Open-Source Contribution Flow

This repo welcomes outside contributors; mirror their contract when you work here.
- Larger ideas (a new subcommand, a new config surface, hosted/companion tooling) start as a **proposal issue**, not a surprise PR.
- PRs run `shellcheck`, `bash -n`, and a smoke test in CI on Linux and macOS — green locally is the precondition, not the finish line.
- Never commit project-local config; `hyperlane guard` is the gate ([PROTECTION §2](./PROTECTION.md)).
- Security-sensitive findings go through private reporting (see [SECURITY.md](./SECURITY.md)).
- Keep the [CHANGELOG.md](./CHANGELOG.md) current for user-visible changes.
