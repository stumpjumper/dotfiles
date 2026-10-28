# Short directory for the prompt. Home is ~.
# Two components or fewer stay whole: ~, ~/src, /usr/bin.
# Deeper paths keep only the last name: .../grok_mac_care.
_dotfiles_prompt_dir() {
  p=$PWD
  case $p in
    "$HOME"|"$HOME"/*) p="~${p#"$HOME"}" ;;
  esac
  if [ "$p" = / ]; then
    printf '/'
    return
  fi
  rest=$p
  case $rest in
    /*) rest=${rest#/} ;;
  esac
  n=0
  tmp=$rest
  while [ -n "$tmp" ]; do
    n=$((n + 1))
    case $tmp in
      */*) tmp=${tmp#*/} ;;
      *) break ;;
    esac
  done
  if [ "$n" -le 2 ]; then
    printf '%s' "$p"
  else
    printf '.../%s' "${rest##*/}"
  fi
}
