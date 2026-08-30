# dotfiles

One public repo, one `install.sh`, every machine and every user.

Absorbs [`stumpjumper/pi-dots`](https://github.com/stumpjumper/pi-dots) (emacs, bash aliases, `bin/`, host crontabs). Adds tmux, zsh, herdr, ssh config, and a thin bashrc.

This is **not** a dump of `/Users/alfred/.dotfiles`. No Sandia, no X11, no SSH keys, no tokens.

## Install

```bash
git clone https://github.com/stumpjumper/dotfiles.git ~/.dotfiles
~/.dotfiles/install.sh
```

Work Mac (or any hostname matching `^s[0-9]`):

```bash
~/.dotfiles/install.sh --work
```

`install.sh` will:

- Symlink bash, zsh, emacs, tmux, and `~/bin` scripts
- Copy `git/gitconfig` only if `~/.gitconfig` does not exist
- Add the `gh` credential helper if `gh` is on PATH
- Symlink `~/.ssh/config` to `ssh/config.home` or `ssh/config.work`
- Touch `~/.ssh/config.local` for keys and overrides
- On Darwin, symlink herdr `config.toml` (not sockets, logs, or `session.json`)
- Create `~/.config/dotfiles/local.sh` from the example if missing

Existing real files are backed up as `*.pre-dotfiles.YYYY-MM-DD`.

It does **not** `chsh`, `brew bundle`, or load crontab.

## Overlay

Machine- and user-only env lives in `~/.config/dotfiles/local.sh` (not in git).

Put bun, pnpm, grok, nanoclaw, and nano’s `/usr/local/bin` (docker CLI for non-interactive ssh) there. Shared aliases stay in `shell/aliases.sh`.

## SSH

| Profile | When | condor | others |
|---|---|---|---|
| `config.home` | Tailscale up | MagicDNS | MagicDNS (`turbo`, `buzon`, `b29`, `dynamo`, `ben`; `nano` → localhost) |
| `config.work` | work Mac, no Tailscale | public IP `74.208.212.14` | MagicDNS via `ProxyJump condor` |

No private keys. Identity files go in `~/.ssh/config.local`.

## Darwin packages

Optional, not run by `install.sh`:

```bash
brew bundle --file=~/.dotfiles/Brewfile        # turbo / home
brew bundle --file=~/.dotfiles/Brewfile.work   # work Mac
```

## Layout

```
install.sh
Brewfile  Brewfile.work
shell/    aliases.sh bashrc bash_profile zshrc zshenv local.sh.example
emacs/    emacs.el          ← pi-dots .emacs_simple
tmux/     tmux.conf         ← Ctrl-T prefix, OSC 52, truecolor
herdr/    config.toml       ← Darwin only
git/      gitconfig
ssh/      config.home  config.work
bin/      from pi-dots
hosts/    reference crontabs; not auto-applied
```

## Machines

| Host | OS | Notes |
|---|---|---|
| turbo | macOS | users `aal` (bash, do not chsh yet) and `nano` (zsh; first live install) |
| ben | macOS | home Mac |
| work Mac | macOS | hostname `^s[0-9]+`; SSH out only; `--work` |
| condor | Ubuntu 24.04 | jump host; bash; tmux 3.4, no herdr |
| buzon, b29, dynamo | Raspberry Pi | already on pi-dots emacs/aliases |

## Login shell

`aal` stays bash until that is its own theme. `install.sh` never calls `chsh`.
