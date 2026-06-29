<!--
Thanks for contributing to hyperlane! Keep it zero-dependency and comment the WHY.
Fill in the summary and tick the checklist below before requesting review.
-->

## Summary

<!-- What does this change, and why? What failure mode does it fix or prevent? -->

## Checklist

- [ ] Ran `shellcheck hyperlane lane.sh install.sh` — clean.
- [ ] Ran `bash -n hyperlane lane.sh install.sh` — every script parses.
- [ ] Did a manual end-to-end check against a throwaway `HYPERLANE_CONFIG`
      (temp dirs / fake checkouts) — see CONTRIBUTING.md.
- [ ] No project-local config committed — `./hyperlane guard` is clean
      (`hyperlane.conf`, `*.local.*`, `.lanes`, `.lane.env` stay gitignored).
- [ ] Stayed zero-dependency — no new runtime, and any new external command is
      justified with a graceful fallback when it's absent.
- [ ] Matched the heavy comment-the-WHY style — non-obvious blocks explain the
      failure mode they prevent.
- [ ] Updated docs / the pillars (`CLAUDE.md`, `PROTECTION.md`, `GUIDANCE.md`,
      `WISDOM.md`) if behavior or a guarantee changed.
- [ ] Updated `CHANGELOG.md` under `## [Unreleased]`.
