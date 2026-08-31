#!/usr/bin/env bash
# install.sh — symlink this repo into $HOME. Never chsh.
# Usage: ./install.sh [--home|--work]
#   --work  ssh/config.work (also auto if hostname matches ^s[0-9])
#   --home  ssh/config.home (default)

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./install.sh [--home|--work]

Clone to ~/.dotfiles, then run this script.

  --home   ssh config for Tailscale/MagicDNS (default)
  --work   ssh config with ProxyJump via condor
           (also selected when hostname matches ^s[0-9])

Existing real files are moved to *.pre-dotfiles.YYYY-MM-DD.
Keeps a real ~/.bashrc and will not add ~/.bash_profile if
~/.profile exists (Debian/Ubuntu login). Never chsh. Does not
brew bundle, load crontab, or touch SSH keys.
EOF
}

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
DATE="$(date +%Y-%m-%d)"
SSH_KIND=home

hostname_short="$(hostname -s 2>/dev/null || hostname)"

while [ $# -gt 0 ]; do
  case "$1" in
    --home) SSH_KIND=home ;;
    --work) SSH_KIND=work ;;
    -h|--help) usage; exit 0 ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

if [ "$SSH_KIND" = home ] && echo "$hostname_short" | grep -Eq '^s[0-9]+'; then
  SSH_KIND=work
  echo "Hostname $hostname_short looks like a work Mac; using ssh/config.work"
fi

echo "Installing from: $REPO_DIR"
echo "SSH profile:     $SSH_KIND"
echo "Login shell:     $SHELL  (unchanged)"
echo

backup_if_needed() {
  dest="$1"
  src="$2"
  if [ -L "$dest" ]; then
    current="$(readlink "$dest")"
    if [ "$current" = "$src" ]; then
      return 1
    fi
  elif [ ! -e "$dest" ]; then
    return 0
  fi
  backup="${dest}.pre-dotfiles.${DATE}"
  if [ -e "$backup" ]; then
    backup="${dest}.pre-dotfiles.$(date +%Y-%m-%dT%H%M%S)"
  fi
  echo "  backup $dest -> $backup"
  mv "$dest" "$backup"
  return 0
}

relink() {
  src="$1"
  dest="$2"
  mkdir -p "$(dirname "$dest")"
  if backup_if_needed "$dest" "$src"; then
    :
  else
    echo "  $dest already -> $src"
    return 0
  fi
  ln -sfn "$src" "$dest"
  echo "  $dest -> $src"
}

# --- shells (both; unused rc files are harmless) ---
# Debian/Ubuntu: keep the distro ~/.bashrc (completion, histappend) and
# wire aliases through ~/.bash_aliases. Do not create ~/.bash_profile
# when ~/.profile exists — bash would skip .profile.
if [ -f "$HOME/.bashrc" ] && [ ! -L "$HOME/.bashrc" ]; then
  echo "  keeping existing ~/.bashrc (distro/login); wiring ~/.bash_aliases"
else
  relink "$REPO_DIR/shell/bashrc" "$HOME/.bashrc"
fi
relink "$REPO_DIR/shell/bash_aliases" "$HOME/.bash_aliases"

if [ -L "$HOME/.bash_profile" ]; then
  # Includes dangling links after retargeting ~/.dotfiles.
  relink "$REPO_DIR/shell/bash_profile" "$HOME/.bash_profile"
elif [ -f "$HOME/.bash_profile" ]; then
  echo "  keeping existing ~/.bash_profile"
elif [ -f "$HOME/.profile" ]; then
  echo "  skipping ~/.bash_profile so ~/.profile still runs on login"
else
  relink "$REPO_DIR/shell/bash_profile" "$HOME/.bash_profile"
fi

relink "$REPO_DIR/shell/zshrc"        "$HOME/.zshrc"
relink "$REPO_DIR/shell/zshenv"       "$HOME/.zshenv"
relink "$REPO_DIR/emacs/emacs.el"     "$HOME/.emacs"
relink "$REPO_DIR/tmux/tmux.conf"     "$HOME/.tmux.conf"

# --- gitconfig: copy once, never overwrite ---
if [ ! -f "$HOME/.gitconfig" ]; then
  cp "$REPO_DIR/git/gitconfig" "$HOME/.gitconfig"
  echo "  ~/.gitconfig copied from template"
else
  echo "  ~/.gitconfig already exists, leaving it"
fi

if command -v gh >/dev/null 2>&1; then
  gh_bin="$(command -v gh)"
  git config --global --replace-all credential.https://github.com.helper "!$gh_bin auth git-credential"
  git config --global --replace-all credential.https://gist.github.com.helper "!$gh_bin auth git-credential"
  echo "  git credential helper -> $gh_bin"
fi

# --- ssh ---
# nano is a NanoClaw sandbox: never install Host aliases or keys.
# Inbound is sshd + authorized_keys (aal docker context). Outbound stays off.
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
if [ "$(id -un)" = nano ]; then
  echo "  skipping shared ssh config (nano sandbox: no passwordless outbound)"
  if [ -L "$HOME/.ssh/config" ]; then
    rm -f "$HOME/.ssh/config"
    echo "  removed ssh config symlink"
  fi
  if [ ! -f "$HOME/.ssh/config" ]; then
    umask 077
    cp "$REPO_DIR/ssh/config.sandbox" "$HOME/.ssh/config"
    chmod 600 "$HOME/.ssh/config"
    echo "  wrote fail-closed ~/.ssh/config (copy, not symlink)"
  fi
else
  if [ ! -f "$HOME/.ssh/config.local" ]; then
    umask 077
    touch "$HOME/.ssh/config.local"
    echo "  ~/.ssh/config.local created (empty; keys/overrides go here)"
  fi
  relink "$REPO_DIR/ssh/config.$SSH_KIND" "$HOME/.ssh/config"
fi

# --- herdr: Darwin only; never track sockets/logs/session.json ---
if [ "$(uname -s)" = Darwin ]; then
  mkdir -p "$HOME/.config/herdr"
  relink "$REPO_DIR/herdr/config.toml" "$HOME/.config/herdr/config.toml"
else
  echo "  skipping herdr (not Darwin)"
fi

# --- overlay ---
mkdir -p "$HOME/.config/dotfiles"
if [ ! -f "$HOME/.config/dotfiles/local.sh" ]; then
  cp "$REPO_DIR/shell/local.sh.example" "$HOME/.config/dotfiles/local.sh"
  echo "  ~/.config/dotfiles/local.sh created from example (edit for PATH extras)"
else
  echo "  ~/.config/dotfiles/local.sh already exists, leaving it"
fi

# --- bin ---
mkdir -p "$HOME/bin"
relink "$REPO_DIR/bin/git_commit.py" "$HOME/bin/git_commit"
relink "$REPO_DIR/bin/get_temps"     "$HOME/bin/get_temps"
relink "$REPO_DIR/bin/dynu_update.sh" "$HOME/bin/dynu_update.sh"

echo
echo "Done. Open a new shell."
echo "Did not chsh. Did not brew bundle. Did not load crontab."
if [ "$(uname -s)" = Darwin ]; then
  echo "Optional: brew bundle --file=\"$REPO_DIR/Brewfile\""
  echo "          (work Mac: Brewfile.work)"
fi
