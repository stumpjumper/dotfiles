# Homebrew must win over path_helper (which appends it) and over
# MacPorts ~/.profile (which prepends dead /opt/local/bin/python).
# Call only on Darwin. Safe to source from bash or zsh.

_dotfiles_path_front() {
  _p="$1"
  [ -d "$_p" ] || return 0
  PATH=":${PATH}:"
  while [ "${PATH#*:${_p}:}" != "$PATH" ]; do
    PATH="${PATH%%:${_p}:*}:${PATH#*:${_p}:}"
  done
  PATH="${PATH#:}"
  PATH="${PATH%:}"
  PATH="${_p}:${PATH}"
  unset _p
}

_dotfiles_path_front /opt/homebrew/bin
_dotfiles_path_front /opt/homebrew/sbin
_dotfiles_path_front /usr/local/bin
# Unversioned `python` / `pip` next to Homebrew's python3.
[ -d /opt/homebrew/opt/python3/libexec/bin ] && \
  _dotfiles_path_front /opt/homebrew/opt/python3/libexec/bin

export PATH
unset -f _dotfiles_path_front
