# Contributing to hyperlane

Thanks for your interest. hyperlane aims to stay small, fast, and
**zero-dependency** — pure bash (3.2+, the macOS system bash) plus the standard
POSIX userland (`lsof`, `awk`, `sed`, `find`); on Windows (Git Bash/MSYS), the
always-present `netstat`/`taskkill` stand in for `lsof`. No language runtime, no
package manager, nothing to install but the scripts themselves. Keep it that way.

## Lint & check

The local gate is `shellcheck` plus a parse check on every script:

```sh
shellcheck -S warning hyperlane lane.sh install.sh
bash -n hyperlane lane.sh install.sh
```

`lane.sh` is sourced into a bash-or-zsh profile, so it carries a
`# shellcheck shell=bash` directive and line-local disables for its intentional
dual-shell constructs. The repo's `.shellcheckrc` documents the handful of
info-level false positives (indirectly-invoked callback helpers, the generated
`.lane.env` source) so a plain `shellcheck` is quiet locally too; CI gates on
`-S warning` because info/style checks vary by shellcheck version. Don't add new
warning- or error-level findings.

CI runs this on Linux and macOS — see `.github/workflows/ci.yml`. Please run the
gate locally before opening a PR — the
[pull request template](.github/PULL_REQUEST_TEMPLATE.md) has the full checklist.

By participating you agree to the [Code of Conduct](CODE_OF_CONDUCT.md). Security
issues go through private reporting — see [SECURITY.md](SECURITY.md), not a
public issue. Pull requests require a maintainer review before merging.

## Manual end-to-end check

Drive the real engine against a throwaway config that points at temp dirs — never
your real machine layout. Set `HYPERLANE_CONFIG` and exercise the read-only verbs:

```sh
tmp="$(mktemp -d)"
mkdir -p "$tmp/myapp" "$tmp/myapp-multi/myapp-a"

cat > "$tmp/hyperlane.conf" <<EOF
HYPERLANE_ROOT="$tmp/myapp-multi"
HYPERLANE_PRIMARY="$tmp/myapp"
HYPERLANE_PREFIX="myapp"
HYPERLANE_SERVICES=( "api:8080" "web:3000" )
EOF

export HYPERLANE_CONFIG="$tmp/hyperlane.conf"
./hyperlane doctor          # the conflict table renders
./hyperlane ports  a        # lane a's ports: api 8081, web 3001
./hyperlane env    a        # writes myapp-a/.lane.env, source-able
./hyperlane verify a        # exit 0 = isolated

rm -rf "$tmp"
```

`doctor`/`ports`/`env`/`verify` are read-only or write-only-to-the-checkout; they
won't touch your live stacks. `launch`/`reap`/`stop` send signals and start
processes — exercise those only against the throwaway checkouts above.

## Principles

- **Stay zero-dependency.** The whole point is that hyperlane installs with a
  `git clone` and runs everywhere bash does. A new external command (anything
  beyond bash builtins + `lsof`/`awk`/`sed`/`find`) needs a clear justification
  and a graceful fallback when it's absent. New language runtimes are a non-starter.
- **Root-cause fixes, no band-aids.** Match the existing code's idiom and comment
  density. hyperlane is heavily commented because the *why* matters — every
  non-obvious block explains the failure mode it prevents. Keep that up.
- **The engine ships no project strings.** `hyperlane` and `lane.sh` are generic
  and public; everything project-specific lives in the sourced config. Don't leak
  a path, port, or hostname into the engine.
- **Fail closed, never silently wrong.** A port collision or a foreign-lane launch
  must error loudly — the whole reason this tool exists is that silent
  cross-wiring costs hours to debug.

## Never commit project-local config or secrets

Project-local files — `hyperlane.conf`, `*.local.*`, `.lanes`, `.lane.env` — are
**gitignored by mandate**. They carry machine paths and may carry secrets (an env
hook can emit tokens into `.lane.env`). They must never reach the public repo.

Before every push, run:

```sh
./hyperlane guard
```

It fails closed if any project-local file is tracked or staged. The installed
pre-commit hook runs the same check, but run it by hand too — a leaked secret or
a personal path in a PR is the one mistake we can't take back. See
[PROTECTION.md](PROTECTION.md) and [SECURITY.md](SECURITY.md).

## The pillars

This repo carries the four governance pillars — `CLAUDE.md` (operating
principles), `PROTECTION.md` (invariants and guards), `GUIDANCE.md` (how intent
becomes behavior), and `WISDOM.md` (the accumulated *why*). If your change alters
a guarantee or encodes a hard-won lesson, update the relevant pillar in the same
PR.

## Scope

Good first contributions: more shell completions (bash/zsh/fish), additional
example configs under `examples/`, and portability fixes for other shells and
OSes (BSD vs GNU `lsof`/`awk` differences, busybox userland, etc.). Larger ideas
are welcome as proposals first — open an issue describing the design before you
build it.
