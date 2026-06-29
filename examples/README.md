# hyperlane examples

These are **complete, ready-to-adapt** `hyperlane.conf` files for common stacks.
They exist so you don't start from a blank schema: copy the one closest to your
project, then edit the paths, service ports, and launch commands.

## How to use one

The live config is **`hyperlane.conf` at the repo root**, which is **gitignored
by mandate** (it carries machine paths and secrets — see `.gitignore` and
`PROTECTION.md §2`). To use an example, copy it into place and edit it:

```sh
cp examples/rails-postgres.conf hyperlane.conf
$EDITOR hyperlane.conf
```

Every file here is plain bash that the tool `source`s — the same schema as
`hyperlane.conf.example`. Start there if you want the annotated field-by-field
reference; the files below are worked, opinionated instances of it.

## The examples

- **`rails-postgres.conf`** — a Rails monolith with a `web` (rails server) and a
  `vite` (jsbundling) service. Demonstrates the **env hook** giving each lane its
  own Postgres database (`myapp_lane_<lane>`) so parallel checkouts never share
  migrations or fixtures, plus a per-lane `RAILS_ENV`. Good starting point for any
  single-app-plus-asset-bundler stack.

- **`node-fullstack.conf`** — a pnpm monorepo with three workspace packages:
  `api`, `web`, and a `worker`. Demonstrates launch hooks that `cd` into each
  workspace package and run its dev server **directly on the lane port** (the
  footgun being a `dev` script that hardcodes the default port), and an env hook
  that wires `PORT`/`VITE_PORT` and a per-lane `REDIS_URL`.

- **`advanced-daemon.conf`** — the full-power example: a `api` backend, a `web`
  frontend, and a long-lived `daemon` that keeps an **on-disk home directory**.
  Demonstrates **all four hooks** — a `setup` hook that clones a per-lane daemon
  home, an `env` hook with a CORS allowlist and a shared-encryption-key read from
  a gitignored shared file, and a `verify` hook that curls each lane's health
  endpoint and asserts the daemon's call-home points at **this** lane's backend.
  It's the genericized distillation of a real 12-clone production setup.
