#!/usr/bin/env bash
# install.sh — set up hyperlane on this machine. Idempotent; safe to re-run.
#
# What it does:
#   1. makes the engine + scripts executable
#   2. wires the `lane` command into your shell profile (zsh/bash)
#   3. installs a pre-commit hook that runs `hyperlane guard` (blocks committing
#      project-local config to the public repo — see PROTECTION.md §2)
#   4. if no hyperlane.conf exists yet, seeds one from the example
#   5. shows the current lane table
#
# Run once after cloning, then `source` your profile (or open a new shell).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
chmod +x "$HERE/hyperlane" "$HERE/install.sh" 2>/dev/null || true

# ── 1. wire `lane` into the shell profile (idempotent) ──────────────────────
SRC_LINE="[ -f \"$HERE/lane.sh\" ] && . \"$HERE/lane.sh\""
MARK="# hyperlane: lane command"
case "${SHELL##*/}" in
  zsh)  PROFILE="$HOME/.zshrc" ;;
  bash) PROFILE="$HOME/.bashrc"; [ -f "$HOME/.bash_profile" ] && PROFILE="$HOME/.bash_profile" ;;
  *)    PROFILE="$HOME/.profile" ;;
esac
touch "$PROFILE"
if grep -qF "$MARK" "$PROFILE"; then
  echo "lane command already wired into $PROFILE ✓"
else
  printf '\n%s\n%s\n' "$MARK" "$SRC_LINE" >> "$PROFILE"
  echo "wired lane command → $PROFILE"
fi

# ── 2. pre-commit guard (only inside this repo's git checkout) ───────────────
if git -C "$HERE" rev-parse --git-dir >/dev/null 2>&1; then
  HOOK="$(git -C "$HERE" rev-parse --git-path hooks)/pre-commit"
  if [ -f "$HOOK" ] && ! grep -qF "hyperlane guard" "$HOOK"; then
    echo "note: existing $HOOK present — add a 'hyperlane guard' line to it yourself." >&2
  elif [ ! -f "$HOOK" ]; then
    cat > "$HOOK" <<EOF
#!/usr/bin/env bash
# Installed by hyperlane install.sh — block committing project-local config.
exec "$HERE/hyperlane" guard
EOF
    chmod +x "$HOOK"
    echo "installed pre-commit guard → $HOOK"
  fi
fi

# ── 3. seed a config if there is none ───────────────────────────────────────
if [ ! -f "$HERE/hyperlane.conf" ]; then
  cp "$HERE/hyperlane.conf.example" "$HERE/hyperlane.conf"
  echo "seeded hyperlane.conf from the example — EDIT IT for your project (it is gitignored)."
fi

# ── 4. make it available in THIS shell + report ─────────────────────────────
. "$HERE/lane.sh" 2>/dev/null || true
echo
echo "Current lanes / conflicts:"
"$HERE/hyperlane" doctor 2>/dev/null || echo "(edit hyperlane.conf first, then run: lane)"
cat <<TXT

Next:
    source "$PROFILE"      # or open a new terminal — enables the \`lane\` command
    \$EDITOR "$HERE/hyperlane.conf"
    lane help              # all commands
    lane setup all         # generate .lane.env for every checkout
    lane start a           # launch a checkout's full stack

Docs: README.md · the lane model & rationale live in the four pillars.
TXT
