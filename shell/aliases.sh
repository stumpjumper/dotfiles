# Shared aliases and functions. Sourced from bashrc and zshrc.
# POSIX-ish; works in bash and zsh. No bash-only [[ ]] / ==.

alias rm='rm -i'
alias up='cd ..'
alias u='cd ..'
alias home='cd'
alias ut='uptime'

# GNU ls vs BSD ls
case "$(uname -s)" in
  Darwin) COLOR_OPT="-G" ;;
  *)      COLOR_OPT="--color=auto" ;;
esac
lsopt="-aFh"
alias l="ls $lsopt -C $COLOR_OPT"
alias lf="ls $lsopt -C $COLOR_OPT"
alias ls="ls $lsopt $COLOR_OPT"
alias ll="ls $lsopt -l $COLOR_OPT"
alias lt="ls $lsopt -tr $COLOR_OPT"
alias llt="ls $lsopt -ltr $COLOR_OPT"
alias ltl="ls $lsopt -ltr $COLOR_OPT"
alias lt_nr="ls $lsopt -t $COLOR_OPT"
alias llt_nr="ls $lsopt -lt $COLOR_OPT"
alias ltl_nr="ls $lsopt -lt $COLOR_OPT"

########################################################################
# Process management
########################################################################
if [ "x$PS_FLAGS" = x ]; then
  PS_FLAGS="-ef"
  export PS_FLAGS
fi
if [ "x$PS_CMD" = x ]; then
  PS_CMD=ps
  export PS_CMD
fi

psg() {
  if [ "x$PS_CMD" = x ]; then
    PS_CMD=ps
  fi
  if [ $# -le 0 ]; then
    $PS_CMD $PS_FLAGS | grep -E "$USER" | grep -Eiv " grep.*$USER"
  else
    $PS_CMD $PS_FLAGS | grep -Ei "$*" | grep -Eiv " grep -Ei $*"
  fi
}

psgdo() {
  if [ "x$PS_CMD" = x ]; then
    PS_CMD=ps
  fi
  do_sudo=""
  do_sudo_msg=""
  if [ "$1" = "-s" ]; then
    shift
    do_sudo=sudo
    do_sudo_msg="*using sudo*"
  fi
  command=$1
  shift
  STRING=$($PS_CMD $PS_FLAGS | grep -Ei "$*" | grep -Eiv " grep -Ei $*")
  PID=$(echo "$STRING" | awk '{print $2}')
  if [ -z "$PID" ]; then
    echo "No matching process found"
  else
    echo "$STRING"
    echo "Execute command $command $do_sudo_msg on: $PID"
    echo -n "Y or N? "
    read ans
    if [ "$ans" = "Y" ] || [ "$ans" = "y" ] || [ "$ans" = "Yes" ] || [ "$ans" = "yes" ]; then
      $do_sudo $command $PID
    fi
  fi
}

psgkill() {
  sudo_flag=""
  if [ "$1" = "-s" ]; then
    sudo_flag="-s"
    shift
  fi
  psgdo $sudo_flag "kill -9" "$@"
}

psm() {
  if [ "x$PS_CMD" = x ]; then
    PS_CMD=ps
  fi
  $PS_CMD $PS_FLAGS | more
}

########################################################################
# Directory stack
########################################################################
dir_list_helper() {
  awk '{
    for (i=1; i<=NF; i++)
      printf(" d%d  %s\n", i, $i)
  }'
}

d0() {
  dirs | dir_list_helper
}

sd() {
  dirs | dir_list_helper
  echo -n 'Directory? '
  read ans
  if [ "x$ans" = x ]; then return; fi
  ans=$(expr "$ans" - 1)
  if [ "$ans" -lt 1 ]; then return; fi
  pushd +$ans
}

pd() {
  eval $(pds $*) > /dev/null
  d0
}

sw() {
  pushd
}

i=2
while [ "$i" -le 9 ]; do
  j=$(expr "$i" - 1)
  alias d$i="pd +$j"
  i=$(expr "$i" + 1)
done
unset i j

pds() {
  case $# in
    0) echo popd ;;
    *) echo pushd "$*" ;;
  esac
}

########################################################################
# Working directory history (last 6 dirs via back / backs / goback)
########################################################################
cd() {
  OLDPWD6="$OLDPWD5"
  OLDPWD5="$OLDPWD4"
  OLDPWD4="$OLDPWD3"
  OLDPWD3="$OLDPWD2"
  OLDPWD2="$OLDPWD"
  if [ "x$*" = x ]; then
    builtin cd
  else
    builtin cd "$*"
  fi
  pwd
}

alias backs='echo "1: $OLDPWD (1)"; echo "2: $OLDPWD2 (2)"; echo "3: $OLDPWD3 (3)"; echo "4: $OLDPWD4 (4)"; echo "5: $OLDPWD5 (5)"; echo "6: $OLDPWD6 (6)"'

back() {
  case $1 in
    2) cd "$OLDPWD2" ;;
    3) cd "$OLDPWD3" ;;
    4) cd "$OLDPWD4" ;;
    5) cd "$OLDPWD5" ;;
    6) cd "$OLDPWD6" ;;
    *) cd "$OLDPWD"  ;;
  esac
}

goback() {
  backs
  echo -n "Back to: "
  read backno
  if [ -n "$backno" ]; then
    back $backno
  fi
}

pushd() {
  if [ "x$*" = x ]; then
    builtin pushd
  else
    builtin pushd "$*"
  fi
}

popd() {
  builtin popd
}
