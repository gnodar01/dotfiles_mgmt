# yadmize test harness — fresh Ubuntu box for exercising the dotfiles bring-up.
#
# Scope: git + zsh + neovim (+ their direct deps). Deps installed via
# "apt where it's good enough, manual otherwise" — mirroring a real fresh host.
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
# Grouped: base tooling, the scope CLIs available in apt, and the nvim/mason
# toolchain (node + python + a C toolchain so mason can build/fetch servers).
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl wget gnupg locales openssh-client \
      git zsh \
      yadm \
      ripgrep fd-find bat jq silversearcher-ag \
      build-essential make gcc g++ unzip tar \
      python3 python3-pip python3-venv \
      nodejs npm \
      luarocks \
    && rm -rf /var/lib/apt/lists/*

# best-effort extras (present in universe; don't fail the build if absent)
RUN apt-get update \
    && (apt-get install -y --no-install-recommends hexyl || true) \
    && rm -rf /var/lib/apt/lists/*

# generate the UTF-8 locale so zsh/nvim glyphs and completion behave
RUN sed -i 's/^# *en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen && locale-gen

# --- apt binary-name fixups --------------------------------------------------
# Ubuntu ships fd as `fdfind` and bat as `batcat`; the dotfiles' aliases call
# bare `fd` and `bat`. Provide the expected names on PATH.
RUN ln -sf "$(command -v fdfind)" /usr/local/bin/fd \
    && ln -sf "$(command -v batcat)" /usr/local/bin/bat

# --- manual installs (apt versions too old / absent) -------------------------
ARG TARGETARCH=amd64

# neovim — apt's is too old for lazy/plugins; grab latest stable release.
RUN set -eux; \
    case "$(uname -m)" in \
      x86_64)  NV=nvim-linux-x86_64 ;; \
      aarch64) NV=nvim-linux-arm64  ;; \
      *) echo "unsupported arch $(uname -m)"; exit 1 ;; \
    esac; \
    curl -fsSL -o /tmp/nvim.tar.gz \
      "https://github.com/neovim/neovim/releases/latest/download/${NV}.tar.gz"; \
    tar -C /opt -xzf /tmp/nvim.tar.gz; \
    ln -sf "/opt/${NV}/bin/nvim" /usr/local/bin/nvim; \
    rm -f /tmp/nvim.tar.gz; \
    nvim --version | head -1

# tree-sitter CLI — REQUIRED by nvim-treesitter's `main` branch to compile parsers
# (the `master` branch didn't need it). Not in the user's original dep list.
RUN set -eux; \
    case "$(uname -m)" in \
      x86_64)  TS=x64 ;; \
      aarch64) TS=arm64 ;; \
      *) echo "unsupported arch $(uname -m)"; exit 1 ;; \
    esac; \
    curl -fsSL -o /tmp/ts.gz \
      "https://github.com/tree-sitter/tree-sitter/releases/latest/download/tree-sitter-linux-${TS}.gz"; \
    gunzip -c /tmp/ts.gz > /usr/local/bin/tree-sitter; \
    chmod +x /usr/local/bin/tree-sitter; \
    rm -f /tmp/ts.gz; \
    tree-sitter --version

# fzf — apt's lacks `fzf --zsh` (needs >=0.48). Official installer gives latest.
RUN git clone --depth 1 https://github.com/junegunn/fzf.git /opt/fzf \
    && /opt/fzf/install --bin \
    && ln -sf /opt/fzf/bin/fzf /usr/local/bin/fzf \
    && fzf --version

# eza — not in apt. Release asset name is version-stable, so latest/download works.
RUN set -eux; \
    case "$(uname -m)" in \
      x86_64)  EZ=eza_x86_64-unknown-linux-gnu.tar.gz ;; \
      aarch64) EZ=eza_aarch64-unknown-linux-gnu.tar.gz ;; \
      *) echo "unsupported arch $(uname -m)"; exit 1 ;; \
    esac; \
    curl -fsSL -o /tmp/eza.tar.gz \
      "https://github.com/eza-community/eza/releases/latest/download/${EZ}"; \
    tar -C /usr/local/bin -xzf /tmp/eza.tar.gz; \
    rm -f /tmp/eza.tar.gz; \
    eza --version | head -1

# starship — not in apt. Official installer.
RUN curl -fsSL https://starship.rs/install.sh | sh -s -- -y \
    && starship --version

# delta — optional (git pager). Best-effort pinned .deb; don't fail build.
ARG DELTA_VERSION=0.18.2
RUN set -eux; \
    case "$(uname -m)" in x86_64) DA=amd64 ;; aarch64) DA=arm64 ;; *) DA= ;; esac; \
    if [ -n "$DA" ]; then \
      curl -fsSL -o /tmp/delta.deb \
        "https://github.com/dandavison/delta/releases/download/${DELTA_VERSION}/git-delta_${DELTA_VERSION}_${DA}.deb" \
        && dpkg -i /tmp/delta.deb || echo "delta install skipped"; \
      rm -f /tmp/delta.deb; \
    fi; \
    (delta --version || echo "delta not installed")

# --- report what we ended up with -------------------------------------------
RUN echo "=== installed tool versions ===" \
    && for t in git zsh yadm nvim tree-sitter fzf starship eza bat fd rg ag jq hexyl delta node npm python3; do \
         printf '%-10s ' "$t"; (command -v "$t" >/dev/null && "$t" --version 2>/dev/null | head -1) || echo "MISSING"; \
       done

WORKDIR /root
CMD ["/bin/zsh", "-l"]
