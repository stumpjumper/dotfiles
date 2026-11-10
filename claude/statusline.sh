#!/usr/bin/env bash
# Claude Code status line (home Mac edition).
# Renders:  ctx:6% cache:33% 5h:23%(2h10m) wk:41% Opus 5 ⚰️ my_project ~$1.81 ~/my_project
#
#   ctx:6%       percent of the context window used (green; yellow at 70; red at 90)
#   cache:33%    share of the LAST request's input read from the prompt cache (green at 50%+,
#                yellow below). Absent before the first reply.
#   5h:23%(2h10m) Pro/Max plan: share of the 5-hour session limit used + time to reset
#   wk:41%       Pro/Max plan: share of the weekly limit (reset time added from 70%).
#                Both from .rate_limits (Claude Code 2.1.300+), the figures /usage shows.
#                Absent with an API key, or until the first reply of a session.
#   Opus 5       model display name (dim)
#   ⚰️ my_project  project name (cyan) = basename of the project dir; optional emoji before it
#                from <project>/.claude/project-emoji (first line; ignored if it holds control
#                bytes or is over 32 bytes)
#   ~$1.81       Claude Code's own estimate for this session (.cost.total_cost_usd), computed
#                locally from its price table -- NOT your bill. Absent at $0. To drop the "~",
#                edit the two printf "~$..." lines below.
#   +$0.31       how much ~$ rose at its last change (roughly: the last API request). Yellow
#                when cache hit is under 50% (cache misses), green otherwise (context reads).
#   ..·¯....     the last 8 rises, oldest left: each vs the cheapest of the 8 (ignoring
#                under $0.01). "." under 1.5x, "·" 1.5-2x, "¯" 2x+. Coloured like +$, per rise.
#                State: ~/.claude/statusline-state/<session_id> = "<last cost> <delta>:<hit>...";
#                written only when the cost changes; files older than 7 days are pruned.
#   ~/x         cwd basename; "~/x" under $HOME, ".../x" outside it (dim)
#
# Needs jq (brew install jq). Portable to macOS's bash 3.2 and BSD tools.
# Safe by design: read-only, no network, prints exactly one line. NO_COLOR disables colour.

set -uo pipefail

input=$(cat)

# Single jq pass, tab-separated. Every field has a non-empty default; dir is last because
# a tab-separated `read` collapses an EMPTY field and shifts the rest.
IFS=$'\t' read -r pct h5 h5r wk wkr model c_in c_new c_read cost sid proj dir < <(
  printf '%s' "$input" | jq -r '
    [ (.context_window.used_percentage // 0)
    , (.rate_limits.five_hour.used_percentage // "-")
    , (.rate_limits.five_hour.resets_at // "-")
    , (.rate_limits.seven_day.used_percentage // "-")
    , (.rate_limits.seven_day.resets_at // "-")
    , (.model.display_name // "?")
    , (.context_window.current_usage.input_tokens // 0)
    , (.context_window.current_usage.cache_creation_input_tokens // 0)
    , (.context_window.current_usage.cache_read_input_tokens // 0)
    , (.cost.total_cost_usd // 0)
    , (.session_id // "-")
    , (.workspace.project_dir // .workspace.current_dir // .cwd // "-")
    , (.workspace.current_dir // .cwd // "")
    ] | @tsv' 2>/dev/null
) || true
: "${pct:=0}" "${h5:=-}" "${h5r:=-}" "${wk:=-}" "${wkr:=-}" "${model:=?}" "${c_in:=0}" "${c_new:=0}" "${c_read:=0}" "${cost:=0}" "${sid:=-}" "${proj:=-}" "${dir:=}"
[ -n "$dir" ] || dir="$PWD"
[ "$proj" != "-" ] || proj="$dir"

# --- context percent, rounded and clamped 0..100 ---------------------------
case "$pct" in
  ''|*[!0-9.]*) pct_disp=0 ;;
  *) pct_disp=$(awk -v v="$pct" 'BEGIN{ v=v+0; if (v<0) v=0; if (v>100) v=100; printf "%.0f", v }') ;;
esac
case "$pct_disp" in ''|*[!0-9]*) pct_disp=0 ;; esac

# --- project name + optional emoji -----------------------------------------
who=$(printf '%s' "${proj##*/}" | tr -cd 'A-Za-z0-9._ -' | cut -c1-64)
[ -n "$who" ] || who="?"
ef="$proj/.claude/project-emoji"
if [ -r "$ef" ]; then
  emo=$(head -n1 "$ef" 2>/dev/null | tr -d '\r' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
  if [ -n "$emo" ] && [ "$(printf '%s' "$emo" | LC_ALL=C wc -c | tr -d ' ')" -le 32 ] &&
     ! printf '%s' "$emo" | LC_ALL=C grep -q "$(printf '[\001-\037\177]')" &&
     ! printf '%s' "$emo" | LC_ALL=C grep -q "$(printf '\302[\200-\237]')"; then
    who="$emo $who"
  fi
fi

# --- plan usage (Pro/Max only; null with an API key) -------------------------
# "5h:23%(2h10m)" = share of the 5-hour session limit used, and time until it resets.
# "wk:41%" = share of the weekly limit. Each coloured: green, yellow at 70, red at 90.
now=$(date +%s)
num() { case "$1" in ''|-|*[!0-9.]*) return 1 ;; esac; awk -v v="$1" 'BEGIN{ printf "%.0f", v+0 }'; }
left() {  # seconds-since-epoch -> "2h10m" / "45m" / "3d4h"; empty if unknown or past
  case "$1" in ''|-|*[!0-9.]*) return ;; esac
  s=$(( ${1%.*} - now )); [ "$s" -gt 0 ] || return
  if   [ "$s" -ge 86400 ]; then printf '%dd%dh' $(( s / 86400 )) $(( s % 86400 / 3600 ))
  elif [ "$s" -ge 3600 ];  then printf '%dh%02dm' $(( s / 3600 )) $(( s % 3600 / 60 ))
  else printf '%dm' $(( s / 60 )); fi
}
h5p=$(num "$h5"); wkp=$(num "$wk")
h5t=$(left "$h5r"); wkt=$(left "$wkr")

# --- session cost estimate ---------------------------------------------------
ccost=""
case "$cost" in ''|*[!0-9.e-]*) ;; *)
  ccost=$(awk -v v="$cost" 'BEGIN{ v=v+0; if (v<=0) exit; if (v<10) printf "~$%.2f", v; else printf "~$%.0f", v }')
esac

# --- cache hit on the last request ------------------------------------------
cache=""; hit=0
case "$c_in$c_new$c_read" in *[!0-9]*) ;; *)
  tot=$(( c_in + c_new + c_read ))
  if [ "$tot" -gt 0 ]; then hit=$(( c_read * 100 / tot )); cache="cache:${hit}%"; fi
esac

# --- spend rate: +$ for the last cost rise, and a plot of the last 8 ---------------
# State file: "<last cost> <delta>:<hit%> ..." (oldest first, at most 8 entries). It is
# rewritten only when the cost moves, so redraws between requests show the same values.
# No baseline (new file, or a session already running at install): record, show nothing.
# A drop (a resumed session restarting its tally) clears the history.
# Plot: each request vs the cheapest of the window (ignoring ones under $0.01):
#   .  under 1.5x     ·  1.5x to 2x     ¯  2x or more
# Each character is yellow if that request's cache hit was under 50%, green otherwise.
dcost=""; dplot=""
sid=$(printf '%s' "$sid" | tr -cd 'A-Za-z0-9_-' | cut -c1-80)
if [ -n "$ccost" ] && [ -n "$sid" ] && [ "$sid" != "-" ]; then
  sdir="${HOME:-/tmp}/.claude/statusline-state"; sf="$sdir/$sid"
  prev=""; hist=""
  if [ -r "$sf" ]; then read -r prev hist < "$sf" 2>/dev/null || true
  else
    mkdir -p "$sdir" 2>/dev/null && find "$sdir" -type f -mtime +7 -delete 2>/dev/null
  fi
  upd=0; [ "$cost" != "$prev" ] && upd=1
  { read -r hist; read -r last; read -r dplot; } < <(
    awk -v c="$cost" -v p="$prev" -v h="${cache:+$hit}" -v hist="$hist" -v upd="$upd" \
        -v nc="${NO_COLOR:+1}" -v Y="$(printf '\033[33m')" -v G="$(printf '\033[32m')" \
        -v D="$(printf '\033[2m')" -v R="$(printf '\033[0m')" '
    BEGIN {
      n = split(hist, a, " ")
      if (upd) {
        if (p !~ /^[0-9.]+(e-?[0-9]+)?$/ || c - p <= 0) n = 0
        else a[++n] = sprintf("%.6f:%s", c - p, (h == "" ? "-" : h))
        if (n > 8) { for (i = 1; i <= 8; i++) a[i] = a[i + n - 8]; n = 8 }
      }
      min = 0
      for (i = 1; i <= n; i++) {
        k = split(a[i], e, ":"); d[i] = e[1] + 0; hh[i] = (k >= 2 ? e[2] : "-")
        if (d[i] >= 0.01 && (min == 0 || d[i] < min)) min = d[i]
      }
      out = ""; plot = ""
      for (i = 1; i <= n; i++) {
        out = out (i > 1 ? " " : "") a[i]
        g = "."
        if (min > 0 && d[i] >= 0.01) { r = d[i] / min; g = (r >= 2 ? "¯" : (r >= 1.5 ? "·" : ".")) }
        if (!nc) g = (hh[i] == "-" ? D : (hh[i] + 0 < 50 ? Y : G)) g R
        plot = plot g
      }
      print out; print (n ? d[n] : ""); print plot
    }')
  if [ "$upd" = 1 ]; then
    printf '%s %s\n' "$cost" "$hist" > "$sf.$$" 2>/dev/null && mv -f "$sf.$$" "$sf" 2>/dev/null
  fi
  [ -n "$last" ] && dcost=$(awk -v v="$last" 'BEGIN{ printf "+$%.2f", v+0 }')
  [ -n "$dcost" ] || dplot=""
fi

# --- working directory -------------------------------------------------------
home="${HOME:-}"
if   [ -n "$home" ] && [ "$dir" = "$home" ]; then dir_disp="~"
elif [ -n "$home" ] && [ "${dir#"$home"/}" != "$dir" ]; then dir_disp="~/${dir##*/}"
elif [ "$dir" = "/" ]; then dir_disp="/"
else dir_disp=".../${dir##*/}"
fi

# --- output --------------------------------------------------------------------
plan=""; planc=""
D=$'\033[2m'; R=$'\033[0m'; G=$'\033[32m'; Y=$'\033[33m'; P=$'\033[36m'
lvl() { if [ "$1" -ge 90 ]; then printf '\033[31m'; elif [ "$1" -ge 70 ]; then printf '%s' "$Y"; else printf '%s' "$G"; fi; }
if [ -n "$h5p" ]; then
  t="5h:${h5p}%${h5t:+($h5t)}"; plan="$plan $t"; planc="$planc $(lvl "$h5p")$t$R"
fi
if [ -n "$wkp" ]; then
  t="wk:${wkp}%"; [ "$wkp" -ge 70 ] && t="$t${wkt:+($wkt)}"   # reset time only when it matters
  plan="$plan $t"; planc="$planc $(lvl "$wkp")$t$R"
fi

if [ -n "${NO_COLOR:-}" ]; then
  printf 'ctx:%s%%%s%s %s %s%s %s\n' "$pct_disp" "${cache:+ $cache}" "$plan" "$model" "$who" "${ccost:+ $ccost}${dcost:+ $dcost}${dplot:+ $dplot}" "$dir_disp"
  exit 0
fi
if   [ "$pct_disp" -ge 90 ]; then C=$'\033[31m'
elif [ "$pct_disp" -ge 70 ]; then C=$Y
else C=$G; fi
H=""
if [ -n "$cache" ]; then
  if [ "$hit" -ge 50 ]; then H=" $G$cache$R"; else H=" $Y$cache$R"; fi
fi
# With plan usage shown, ~$ is notional (Pro/Max), so it goes dim; with an API key it stays green.
E=""; if [ -n "$ccost" ]; then if [ -n "$plan" ]; then E=" $D$ccost$R"; else E=" $G$ccost$R"; fi; fi
# +$ is coloured by why it rose: yellow = cache misses, green = cache reads of a big context.
if [ -n "$dcost" ]; then if [ -n "$cache" ] && [ "$hit" -lt 50 ]; then E="$E $Y$dcost$R"; else E="$E $G$dcost$R"; fi; fi
[ -n "$dplot" ] && E="$E $dplot"   # already coloured per character
printf '%sctx:%s%%%s%s%s %s%s%s %s%s%s%s %s%s%s\n' \
  "$C" "$pct_disp" "$R" "$H" "$planc" "$D" "$model" "$R" "$P" "$who" "$R" "$E" "$D" "$dir_disp" "$R"
