# yadmize test harness — fresh Ubuntu box for exercising the dotfiles bring-up.
#
# Scope: git + zsh + neovim (+ their direct deps). Strategy: apt provides only the
# base OS tooling and the C toolchain mason needs; every user-facing CLI comes from
# `pixi global install` (conda-forge) so versions are current and arch-independent.
# Runs as root so a read-only bind-mount of the host ~/.ssh (owned by your uid,
# which maps to container-root under rootless podman) is readable with 0600 perms.
#
# Build:  podman build -t yadmize -f Containerfile .
# Run:    ./run.sh   (see that script for the clone+bootstrap+verify flow)

FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    HOME=/root

# --- core apt deps -----------------------------------------------------------
# Only the base OS bits and the build toolchain: mason (nvim) needs a C/C++
# compiler + make + unzip/tar to build/fetch language servers. zsh is the login
# shell. Everything else comes from pixi below. yadm is vendored from upstream
# (next block) rather than apt — see the note there.
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl wget gnupg locales openssh-client \
      build-essential make gcc g++ unzip tar \
      zsh \
    && rm -rf /var/lib/apt/lists/*

# generate the UTF-8 locale so zsh/nvim glyphs and completion behave
RUN sed -i 's/^# *en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen && locale-gen

# --- pixi --------------------------------------------------------------------
# Package/env manager (not in apt). Official installer drops the binary in
# $HOME/.pixi/bin; `pixi global install` also exposes tool shims there. Put that
# first on PATH so pixi-provided tools shadow anything from the base image.
ENV PATH=/root/.pixi/bin:$PATH
RUN curl -fsSL https://pixi.sh/install.sh | sh \
    && pixi --version

# --- pixi global tools -------------------------------------------------------
# Every user-facing CLI (from conda-forge). Each package gets its own isolated
# environment; binaries are exposed onto /root/.pixi/bin. Name notes:
#   ripgrep      -> rg
#   fd-find      -> fd
#   git-delta    -> delta
#   tree-sitter-cli -> tree-sitter   (required by nvim-treesitter's `main` branch)
#   nvim         -> neovim itself (the `neovim` package is the python client, not the editor)
#   nodejs       -> node + npm        (mason's JS-based servers)
#   python=3.13  -> python / python3  (mason's Python-based servers)
RUN pixi global install \
      less \
      file \
      git \
      ripgrep \
      fd-find \
      bat \
      jq \
      "python=3.13" \
      nodejs \
      luarocks \
      hexyl \
      tree-sitter-cli \
      fzf \
      eza \
      starship \
      git-delta \
      nvim \
      yazi

# --- yadm (vendored from upstream, NOT apt) ----------------------------------
# apt's yadm on Ubuntu 24.04 is 3.2.2, whose `alt` stage links with `ln -nfs` and
# thus FORCE-OVERWRITES any pre-existing real file at a symlink target during
# `yadm clone` — silently discarding the user's file (e.g. a hand-written ~/.zshrc).
# The non-destructive behavior ("skip alt if the target already exists", mirroring
# clone's own conflict-protection) landed post-3.5.0 and is not in a tagged release
# yet, so we pin the single-file yadm script at the commit that introduced it.
# yadm is a self-contained bash script; runs after pixi so its deps (git, bash,
# awk) are on PATH. `yadm version` shells out to git, hence the ordering.
ARG YADM_REF=4214de8d91746ca7f7690ebe1fd500c365b3d1b7
RUN curl -fLo /usr/local/bin/yadm \
      "https://github.com/yadm-dev/yadm/raw/${YADM_REF}/yadm" \
    && chmod a+x /usr/local/bin/yadm \
    && yadm version

# --- git version floor -------------------------------------------------------
# The dotfiles' .gitconfig sets `merge.conflictstyle = zdiff3`, which only exists
# in git >= 2.35 (Jan 2022). On older git, *submodule* checkouts abort with
# `fatal: unknown style 'zdiff3'`, silently breaking the only two submodule-bearing
# nvim plugins (luasnip -> deps/jsregexp*, yazi.nvim -> yazi-plugin/yazi-plugins).
# conda-forge's git is well past the floor — this assertion just fails the build
# loudly if that ever regresses.
RUN set -eux; \
    gv="$(git --version | grep -oE '[0-9]+\.[0-9]+' | head -1)"; req=2.35; \
    [ "$(printf '%s\n%s\n' "$req" "$gv" | sort -V | head -1)" = "$req" ] \
      || { echo "FATAL: git $gv < $req — dotfiles need >= $req for zdiff3 (see README)"; exit 1; }; \
    echo "git $gv >= $req OK"

# --- verify expected binary names are on PATH --------------------------------
# Several conda-forge packages expose a binary whose name differs from the package
# (rg, fd, delta, tree-sitter) or bundle a second one (npm). Fail loudly if any
# expected command is missing rather than discovering it at dotfiles-bootstrap time.
RUN set -eux; \
    for c in file git rg fd bat jq python python3 node npm luarocks hexyl \
             tree-sitter fzf eza starship delta nvim yazi zsh yadm; do \
      command -v "$c" >/dev/null || { echo "FATAL: missing command: $c"; exit 1; }; \
    done; \
    echo "all expected commands present"

# --- report what we ended up with -------------------------------------------
RUN echo "=== installed tool versions ===" \
    && for t in file git zsh yadm nvim tree-sitter fzf starship pixi yazi eza bat fd rg jq hexyl delta node npm python luarocks; do \
         printf '%-12s ' "$t"; (command -v "$t" >/dev/null && "$t" --version 2>/dev/null | head -1) || echo "MISSING"; \
       done

WORKDIR /root
CMD ["/bin/zsh", "-l"]
