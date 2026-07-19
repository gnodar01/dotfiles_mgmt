# yadmize — dotfiles bring-up test harness

## Purpose & scope
This repo is a **containerized test harness for exercising a fresh-host bring-up of
the user's dotfiles** (`git@github.com:gnodar01/dotfiles.git`). It is *not* the
dotfiles themselves — it's the disposable Ubuntu box + orchestration that clones
them over SSH, runs the `yadm` bootstrap, and verifies git / zsh / neovim come up
clean. Scope of tooling deliberately tracks what those dotfiles need: git, zsh,
neovim (+ mason's toolchain), and the CLIs the shell/editor config reference.

Key files:
- `Containerfile` — the image (Ubuntu 24.04 + tools).
- `run.sh` — the harness. **Everything goes through this** (see below).
- `dotfiles/` — a working copy / submodules of the dotfiles under test.
- `README.md` — human-facing overview.
- `nvim_debug.sh` — ad-hoc nvim provisioning/health probe used during debugging.

## Dotfiles-side fixes (made in the dotfiles repo, on `yadmize-test`)
For a clean fresh-host `yadm clone --bootstrap`, the *dotfiles* needed:
- a `.config/yadm/bootstrap` script, and
- an `nvim##default` relative-symlink alt (`../../../../superhome/config/nvim`),
  because the nvim alternates were hostname-only with no default — so a brand-new
  host got no nvim config at all.
- a tracked `.config/yadm/config` with `yadm.auto-alt = false`, plus a "safe alt"
  block at the top of the bootstrap. **Why:** yadm's automatic `alt` stage
  overwrites any pre-existing *real* file at a symlink target during `yadm clone`
  — on old yadm (`ln -nfs`) it silently discards it (e.g. a hand-written `~/.zshrc`).
  Disabling auto-alt makes clone never clobber on **any** yadm version; the
  bootstrap then backs up any conflicting real files (into
  `~/.local/state/yadm/preexisting/`), runs `yadm alt` itself, restores backups
  whose alt didn't apply, and reports the rest. Net: bring-up is non-destructive
  regardless of the host's yadm version. Regression-guarded by `./run.sh test`.
These live in the dotfiles repo, not this harness; details in `../plan.md`.

## Working conventions (learned the hard way)

- **Running podman via the Claude Bash tool needs the sandbox disabled.** Rootless
  podman (build/run/exec) fails under the default Bash sandbox with
  `failed to reexec: Permission denied` — the sandbox blocks the user-namespace
  reexec podman needs. Pass `dangerouslyDisableSandbox: true` on every podman
  Bash call (confirmed: podman 5.8.4, rootless, overlay driver). `run.sh` itself
  is fine; this only bites when a command shells out to podman.

- **The container runs as root on purpose.** Host `~/.ssh` is bind-mounted
  read-only for the SSH clone; the key is `0600` owned by your uid, which maps to
  container-root under rootless podman, so only root inside the container can read
  it. Don't "fix" this by adding a non-root user.

- **Never run `podman build` / `podman run` directly. Use the `run.sh` harness.**
  - `./run.sh build` — build the image
  - `./run.sh up` — fresh detached container (prints a tool-version banner)
  - `./run.sh clone` — `yadm clone --bootstrap` inside the container
  - `./run.sh verify` — git/zsh/nvim verification pass
  - `./run.sh test` — non-destructive alt regression (seeds real `~/.zshrc` +
    `~/.gitconfig`, clones, asserts they're preserved, not clobbered)
  - `./run.sh shell` / `./run.sh exec <cmd>` — interactive / one-off
  - `./run.sh clean` — remove the container
  - `./run.sh` (no arg) — build (if needed) + up + clone + verify

- **Do not install or run project tooling on the host.** No `pixi install`,
  no test binaries, nothing that mutates the developer machine. Verify tool
  availability/behavior **inside the container** (`./run.sh build` runs the
  in-image assertions; `./run.sh exec ...` for ad-hoc checks).

- When editing `Containerfile`, **also keep `run.sh`'s `up` banner (the tool loop
  in `cmd_up`) in sync** with the installed toolset.

- **Dotfiles fixes land on the `yadmize-test` branch, not `main`.** `run.sh`
  defaults `BRANCH=yadmize-test`, so `./run.sh clone` runs
  `yadm clone -b yadmize-test ...`. Keep the dotfiles' `main` clean; iterate on
  `yadmize-test`, then merge once bring-up is green. Override per-run with
  `BRANCH=... ./run.sh clone` (`REPO` is likewise overridable).

## Tooling strategy (Containerfile)

- **apt** provides only the base OS bits + the C toolchain mason needs:
  `ca-certificates curl wget gnupg locales openssh-client build-essential make
  gcc g++ unzip tar zsh`.
- **`yadm` is vendored from upstream**, not apt or pixi. apt's yadm (Ubuntu 24.04
  → 3.2.2) links alts with `ln -nfs`, force-clobbering pre-existing files during
  `alt`; the non-destructive "skip if target exists" fix is post-3.5.0 and
  unreleased, and yadm isn't on conda-forge. The `Containerfile` downloads the
  single-file yadm script at a pinned commit (`ARG YADM_REF`) into
  `/usr/local/bin/yadm`. Bump `YADM_REF` to a tag once one includes commit
  `4214de8`. (You can build against old yadm — `--build-arg YADM_REF=3.2.2` — to
  confirm the dotfiles-side safety net still keeps `./run.sh test` green.)
- **Everything else user-facing comes from `pixi global install`** (conda-forge),
  so versions are current and arch-independent. pixi is on `PATH` first
  (`/root/.pixi/bin`) so its tools shadow the base image.

### conda-forge package-name gotchas
These bit us; keep them straight:
- `nvim` is **neovim the editor**. The `neovim` package is the *Python client*, not
  the editor — do **not** use it.
- `ripgrep` → `rg`, `fd-find` → `fd`, `git-delta` → `delta`,
  `tree-sitter-cli` → `tree-sitter` (required by nvim-treesitter's `main` branch).
- **`luarocks`** is installed because mason builds the `luacheck` Lua linter with
  it — nvim fails to provision `luacheck` on a fresh host without it. Together with
  `tree-sitter`, these are two deps the dotfiles need that aren't in the user's
  usual toolset; both are regression-guarded by the Containerfile assertion.
- `nodejs` exposes both `node` and `npm`; `python=3.13` exposes `python`/`python3`.
- `pip` is intentionally **not** installed (mason's node/python servers work
  without it). Only add `pixi global install pip` if something genuinely needs it.
- The `Containerfile` has an explicit assertion step that fails the build loudly if
  any expected command name is missing — keep it updated when tools change.

### git version floor
The dotfiles' `.gitconfig` sets `merge.conflictstyle = zdiff3`, which needs
**git >= 2.35**. Below that, *submodule* checkouts abort with
`fatal: unknown style 'zdiff3'`, silently breaking the two submodule-bearing nvim
plugins (luasnip → jsregexp, yazi.nvim → yazi-plugins). conda-forge git is well
past this; the build asserts it as a regression guard.
