# shellcheck shell=bash
# (No shebang on purpose — this file is SOURCED, and it supports both bash and
# zsh. The `shell=bash` directive only tells shellcheck which dialect to lint.)
#
# lane.sh — the friendly `lane` command for hyperlane.
#
# Source this from your shell profile (bash or zsh):
#     [ -f "$HOME/path/to/hyperlane/lane.sh" ] && . "$HOME/path/to/hyperlane/lane.sh"
# (install.sh adds that line for you.) It wraps the `hyperlane` engine with
# intuitive verbs and adds background launchers + tab-completion. The engine does
# all the lane math, conflict-doctoring, and fail-closed launching; this is sugar.
#
# Works in bash (3.2+) and zsh. Pure functions — no state beyond the engine.
# See hyperlane.conf.example for the project config; `lane help` for commands.

# Locate the engine (this file's own directory) in BOTH bash and zsh, then point
# HYPERLANE_BIN at the sibling `hyperlane`. Override HYPERLANE_BIN to relocate.
# In bash, ${BASH_SOURCE[0]} is the sourced path; in zsh it's unset, so we fall
# back to ${(%):-%x} (zsh's "current script"). bash never *evaluates* that zsh
# token (BASH_SOURCE[0] is set), it only parses past it — which is safe.
# shellcheck disable=SC2296  # ${(%):-%x} is the intentional zsh-only fallback
: "${HYPERLANE_BIN:=$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")" 2>/dev/null && pwd)/hyperlane}"

lane() {
  local sub="${1:-doctor}"; [ "$#" -gt 0 ] && shift
  local bin="$HYPERLANE_BIN"
  if [ ! -x "$bin" ]; then echo "lane: engine not found/executable at $bin" >&2; return 1; fi

  case "$sub" in
    doctor|status|ls|"")  "$bin" doctor ;;
    guard)                "$bin" guard ;;
    help|-h|--help)       _lane_help ;;

    setup)   # `lane setup <c>` | `lane setup all`
      if [ "${1:-}" = "all" ]; then
        local n
        for n in $("$bin" list); do "$bin" setup "$n"; done
        echo "— all checkouts set up —"; "$bin" doctor
      else
        "$bin" setup "${1:?usage: lane setup <checkout>|all}"
      fi ;;

    env)     # load this checkout's lane env INTO the current shell
      local cdir; cdir="$("$bin" dir "${1:?usage: lane env <checkout>}")" || return 1
      "$bin" env "$1" >/dev/null   # (re)generate <dir>/.lane.env (cheap, idempotent)
      [ -f "$cdir/.lane.env" ] && { . "$cdir/.lane.env"; echo "loaded lane '$LANE' ($LANE_CLONE)"; } ;;

    cd)      local d; d="$(_lane_dir "${1:?usage: lane cd <checkout>}")"; [ -d "$d" ] && cd "$d" || echo "lane cd: no such checkout: $1" >&2 ;;
    ports)   "$bin" ports "${1:?usage: lane ports <checkout>}" ;;
    verify)  "$bin" verify "${1:?usage: lane verify <checkout>}" ;;
    reap)    "$bin" reap "${1:?usage: lane reap <checkout>}" ;;
    check)   "$bin" check "${1:?usage: lane check <checkout> [service]}" "${2:-all}" ;;

    # ── foreground launch (one service per terminal) ──
    # `lane <service> <checkout>` — e.g. `lane api c`, `lane web c`.
    start)   _lane_start "${1:?usage: lane start <checkout>}" ;;   # background ALL
    stop)    _lane_stop  "${1:?usage: lane stop <checkout>}" ;;
    logs)    _lane_logs  "${1:?usage: lane logs <checkout> [service]}" "${2:-}" ;;
    open)    local u; u="$("$bin" openurl "${1:?usage: lane open <checkout>}")" && { open "$u" 2>/dev/null || xdg-open "$u" 2>/dev/null || echo "GUI: $u"; } ;;

    *)
      # Is `sub` a declared service?  `lane <service> <checkout>` → foreground launch.
      if "$bin" services 2>/dev/null | grep -qxF "$sub"; then
        "$bin" launch "${1:?usage: lane $sub <checkout>}" "$sub"
      else
        echo "lane: unknown command '$sub' (try: lane help)" >&2; return 2
      fi ;;
  esac
}

# Resolve a checkout arg (letter/name/path) to its absolute dir via the engine.
_lane_dir() { "$HYPERLANE_BIN" dir "$1" 2>/dev/null; }

_lane_start() {
  local bin="$HYPERLANE_BIN" c="$1" d; d="$(_lane_dir "$c")" || { echo "lane start: unknown checkout: $c" >&2; return 1; }
  "$bin" check "$c" all || { echo "lane start: aborted — a lane port is taken (above)." >&2; return 1; }
  local logs="$d/.lane-logs"; mkdir -p "$logs"
  local svc
  for svc in $("$bin" services); do
    nohup "$bin" launch "$c" "$svc" >"$logs/$svc.log" 2>&1 &
    echo "started $svc → $logs/$svc.log (pid $!)"
  done
  echo "tail:  lane logs $c    ·    stop:  lane stop $c"
}

_lane_stop() {
  local bin="$HYPERLANE_BIN" c="$1" killed=0 p pid
  for p in $("$bin" ports "$c"); do
    for pid in $(lsof -nP -iTCP:"$p" -sTCP:LISTEN -t 2>/dev/null); do
      kill "$pid" 2>/dev/null && { echo "stopped pid $pid on :$p"; killed=1; }
    done
  done
  [ "$killed" = 0 ] && echo "nothing listening on lane ports ($("$bin" ports "$c"))"
}

_lane_logs() {
  local d; d="$(_lane_dir "$1")" || { echo "lane logs: unknown checkout: $1" >&2; return 1; }
  if [ -n "$2" ]; then tail -f "$d/.lane-logs/$2.log"; else tail -f "$d"/.lane-logs/*.log; fi
}

_lane_help() {
  local bin="$HYPERLANE_BIN" svcs; svcs="$("$bin" services 2>/dev/null | tr '\n' ' ')"
  cat <<H
lane — hyperlane multi-checkout dev environment

  lane                       lane table (ports + conflicts)   [alias: doctor, status, ls]
  lane setup <c|all>         generate .lane.env (+ per-lane setup hook)
  lane env <c>               load checkout c's lane env into THIS shell
  lane cd <c>                cd into checkout c
  lane ports <c>             echo this checkout's service ports
  lane verify <c>            read-only isolation assertion
  lane guard                 error if a project-local file is tracked/staged

  Launch (foreground, one terminal each) — your services: ${svcs:-<none configured>}
  lane <service> <c>         e.g. lane ${svcs%% *} c

  Launch (background, all services):
  lane start <c>             run all services, logs → <c>/.lane-logs/
  lane logs  <c> [service]   tail those logs
  lane stop  <c>             kill whatever holds checkout c's lane ports
  lane open  <c>             open checkout c's GUI in the browser
  lane reap  <c>             kill ONLY c's OUT-OF-LANE strays (safe)

  <c> = a lane letter (a,b,c…), "<prefix>-c", "primary", or a path.
H
}

# ── completion (bash + zsh): subcommands + service names + checkout letters ──
_lane_complete_words() {
  local bin="$HYPERLANE_BIN"
  echo "doctor status ls setup env cd ports verify reap check guard start stop logs open help"
  "$bin" services 2>/dev/null
  "$bin" list 2>/dev/null | sed "s/^${HYPERLANE_PREFIX:-x}-//"
}
if [ -n "${ZSH_VERSION:-}" ]; then
  # Word-splitting the candidate list into compadd args is intended here.
  # shellcheck disable=SC2046
  _lane_zsh() { compadd $(_lane_complete_words); }
  compdef _lane_zsh lane 2>/dev/null
elif [ -n "${BASH_VERSION:-}" ]; then
  # The classic `COMPREPLY=( $(compgen …) )` idiom relies on word-splitting.
  # shellcheck disable=SC2207
  _lane_bash() { COMPREPLY=( $(compgen -W "$(_lane_complete_words)" -- "${COMP_WORDS[COMP_CWORD]}") ); }
  complete -F _lane_bash lane 2>/dev/null
fi
