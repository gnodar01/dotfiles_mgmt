#!/usr/bin/env bash
# yadmize test harness.
#
# Spins up a fresh Ubuntu container from the `yadmize` image, clones the dotfiles
# from GitHub over SSH (key bind-mounted read-only), runs the yadm bootstrap, and
# runs a verification pass for git / zsh / neovim.
#
# Usage:
#   ./run.sh build          # build the image (deps are baked + cached)
#   ./run.sh up             # (re)create a fresh container, detached
#   ./run.sh clone          # yadm clone -b <branch> --bootstrap  (inside container)
#   ./run.sh verify         # run the git/zsh/nvim verification pass
#   ./run.sh test           # non-destructive alt regression: seed real dotfiles,
#                           #   clone, assert they're preserved (not clobbered)
#   ./run.sh log            # show the unified bootstrap log from the container
#   ./run.sh shell          # drop into an interactive login zsh in the container
#   ./run.sh exec <cmd...>  # run an arbitrary command in the container
#   ./run.sh clean          # remove the container
#   ./run.sh                # = build (if needed) + up + clone + verify
#
# Env overrides:
#   BRANCH   (default: yadmize-test)   branch to clone
#   REPO     (default: git@github.com:gnodar01/dotfiles.git)
#   IMAGE    (default: yadmize)
#   CTR      (default: yadmize-run)    container name

set -euo pipefail

IMAGE="${IMAGE:-yadmize}"
CTR="${CTR:-yadmize-run}"
BRANCH="${BRANCH:-yadmize-test}"
REPO="${REPO:-git@github.com:gnodar01/dotfiles.git}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# unified bootstrap log inside the container (see .config/yadm/bootstrap)
BOOTSTRAP_LOG='${XDG_STATE_HOME:-$HOME/.local/state}/yadm/bootstrap.log'

# ssh command used inside the container: accept new host keys, use the mounted
# known_hosts (github.com is already trusted there), and the mounted key.
SSH_CMD='ssh -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/root/.ssh/known_hosts -i /root/.ssh/id_ed25519'

image_exists() { podman image exists "$IMAGE"; }
ctr_running()  { podman container exists "$CTR" && [ "$(podman inspect -f '{{.State.Running}}' "$CTR")" = "true" ]; }

cmd_build() {
  echo ">>> building image '$IMAGE'"
  podman build -t "$IMAGE" -f "$HERE/Containerfile" "$HERE"
}

cmd_up() {
  image_exists || cmd_build
  echo ">>> (re)creating fresh container '$CTR'"
  podman rm -f "$CTR" >/dev/null 2>&1 || true
  if [ ! -d "$HOME/.ssh" ]; then
    echo "!!! $HOME/.ssh not found on host — SSH clone will fail" >&2
  fi
  podman run -d --name "$CTR" \
    -v "$HOME/.ssh:/root/.ssh:ro" \
    -e "GIT_SSH_COMMAND=$SSH_CMD" \
    "$IMAGE" sleep infinity >/dev/null
  echo ">>> container up. tools:"
  podman exec "$CTR" bash -lc 'for t in git zsh yadm nvim tree-sitter fzf starship yazi eza bat fd rg jq hexyl delta node npm python luarocks; do printf "%-12s " "$t"; command -v "$t" >/dev/null && "$t" --version 2>/dev/null | head -1 || echo MISSING; done'
}

cmd_clone() {
  ctr_running || cmd_up
  echo ">>> yadm clone -b $BRANCH $REPO --bootstrap"
  podman exec -e "GIT_SSH_COMMAND=$SSH_CMD" "$CTR" \
    yadm clone -b "$BRANCH" "$REPO" --bootstrap || {
      echo "!!! clone/bootstrap returned non-zero (continuing to verify)" >&2
    }
}

cmd_verify() {
  ctr_running || { echo "no container; run ./run.sh up && ./run.sh clone" >&2; exit 1; }
  echo
  echo "==================== VERIFY ===================="
  podman exec "$CTR" bash -lc '
    set +e
    echo "----- yadm status -----"
    yadm status 2>&1 | head -30
    echo
    echo "----- ~/.config/nvim link -----"
    ls -ld ~/.config/nvim 2>&1; readlink -f ~/.config/nvim 2>&1
    echo
    echo "----- zsh interactive startup (stderr shown) -----"
    zsh -i -c "print -r -- zsh-startup-ok" 2>&1 | tail -40
    echo
    echo "----- zsh plugins cloned -----"
    ls ~/.config/zsh/plugins 2>&1
    echo
    echo "----- git config sanity -----"
    git config --get-regexp "^(user|core|include)" 2>&1 | head -20
    echo
    echo "----- nvim version -----"
    nvim --version | head -1
    echo
    echo "----- lazy plugins installed -----"
    ls ~/.local/share/nvim/lazy 2>/dev/null | head -40; echo "count: $(ls ~/.local/share/nvim/lazy 2>/dev/null | wc -l)"
    echo
    echo "----- :checkhealth nodar -----"
    nvim --headless "+checkhealth nodar" "+w! /tmp/health.txt" +qa 2>/dev/null
    sed -n "1,60p" /tmp/health.txt 2>&1
  '
  echo "================== END VERIFY =================="
  echo ">>> full bootstrap log: ./run.sh log"
}

cmd_log() {
  ctr_running || { echo "no container; run ./run.sh up && ./run.sh clone" >&2; exit 1; }
  podman exec "$CTR" bash -lc "cat \"$BOOTSTRAP_LOG\" 2>/dev/null || echo \"no bootstrap log at $BOOTSTRAP_LOG\""
}

cmd_test() {
  # Non-destructive alt regression test. Old yadm's `alt` force-overwrites existing
  # real files at symlink targets during clone, discarding them. Seed sentinel files
  # BEFORE cloning, then assert that after clone the dotfile symlink was applied AND
  # the original content survived in the bootstrap's backup dir (nothing discarded).
  echo ">>> non-destructive alt regression test (fresh container)"
  cmd_clean
  cmd_up
  echo ">>> seeding pre-existing real dotfiles with sentinels"
  podman exec "$CTR" bash -lc '
    set -e
    printf "SENTINEL-zshrc\n"     > "$HOME/.zshrc"
    printf "SENTINEL-gitconfig\n" > "$HOME/.gitconfig"
    ls -l "$HOME/.zshrc" "$HOME/.gitconfig"
  '
  cmd_clone
  echo
  echo "============== NON-DESTRUCTIVE ALT TEST =============="
  podman exec "$CTR" bash -lc '
    set +e
    rc=0
    backup="${XDG_STATE_HOME:-$HOME/.local/state}/yadm/preexisting"
    check() { # $1=file  $2=expected-sentinel
      local f="$1" want="$2"
      echo "----- ~/$f -----"
      if [ -L "$HOME/$f" ]; then
        echo "  symlink -> $(readlink "$HOME/$f")   [dotfile applied]"
      else
        echo "  FAIL: ~/$f is not a symlink (alt did not apply)"; rc=1
      fi
      if [ -f "$backup/$f" ] && grep -q "$want" "$backup/$f"; then
        echo "  original preserved in $backup/$f   [non-destructive OK]"
      else
        echo "  FAIL: sentinel \"$want\" not found under $backup/$f (data lost!)"; rc=1
      fi
    }
    check .zshrc     SENTINEL-zshrc
    check .gitconfig SENTINEL-gitconfig
    echo
    if [ "$rc" -eq 0 ]; then
      echo "RESULT: PASS — dotfiles applied, no pre-existing data discarded"
    else
      echo "RESULT: FAIL — see failures above"
    fi
    exit "$rc"
  '
  echo "============ END NON-DESTRUCTIVE ALT TEST ============"
}

cmd_shell() { ctr_running || cmd_up; exec podman exec -it "$CTR" /bin/zsh -l; }
cmd_exec()  { ctr_running || cmd_up; shift; exec podman exec -it "$CTR" "$@"; }
cmd_clean() { podman rm -f "$CTR" >/dev/null 2>&1 && echo "removed $CTR" || echo "nothing to remove"; }

case "${1:-all}" in
  build)  cmd_build ;;
  up)     cmd_up ;;
  clone)  cmd_clone ;;
  verify) cmd_verify ;;
  test)   cmd_test ;;
  log)    cmd_log ;;
  shell)  cmd_shell ;;
  exec)   cmd_exec "$@" ;;
  clean)  cmd_clean ;;
  all)    image_exists || cmd_build; cmd_up; cmd_clone; cmd_verify ;;
  *) echo "unknown command: $1" >&2; exit 1 ;;
esac
