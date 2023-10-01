#!/usr/bin/env bash
#
# usage: ./scripts/update_terminfo.sh
#
# This script does:
#
#   1. Download Dickey's terminfo.src
#   2. Compile temporary terminfo database from terminfo.src
#   3. Use database to generate src/nvim/tui/terminfo_defs.h
#

set -e

url='https://invisible-island.net/datafiles/current/terminfo.src.gz'
wezterm_url='https://raw.githubusercontent.com/wez/wezterm/master/termwiz/data/wezterm.terminfo'
target='src/nvim/tui/terminfo_defs.h'

readonly -A entries=(
  [ansi]=ansi_terminfo
  [interix]=interix_8colour_terminfo
  [iterm2]=iterm_256colour_terminfo
  [linux]=linux_16colour_terminfo
  [putty-256color]=putty_256colour_terminfo
  [rxvt-256color]=rxvt_256colour_terminfo
  [screen-256color]=screen_256colour_terminfo
  [st-256color]=st_256colour_terminfo
  [tmux-256color]=tmux_256colour_terminfo
  [vte-256color]=vte_256colour_terminfo
  [xterm-256color]=xterm_256colour_terminfo
  [cygwin]=cygwin_terminfo
  [win32con]=win32con_terminfo
  [conemu]=conemu_terminfo
  [vtpcon]=vtpcon_terminfo
  [wezterm]=wezterm_terminfo
)

db="$(mktemp -du)"

print_bold() {
  printf "\\e[1m%b\\e[0m" "$*"
}

cd "$(git rev-parse --show-toplevel)"

#
# Get terminfo.src
#
print_bold '[*] Get terminfo.src\n'
curl -O "$url"
gunzip -f terminfo.src.gz

#
# Build terminfo database
#
print_bold '[*] Build terminfo database\n'
cat terminfo.src scripts/windows.ti <(curl "$wezterm_url") | tic -x -o "$db" -
rm -f terminfo.src

#
# Write src/nvim/tui/terminfo_defs.h
#
print_bold "[*] Writing $target... "
sorted_terms="$(echo "${!entries[@]}" | tr ' ' '\n' | sort | xargs)"

cat > "$target" <<EOF
// uncrustify:off

// Generated by scripts/update_terminfo.sh and $(tic -V)

#pragma once

#include <stdint.h>
EOF

for term in $sorted_terms; do
  path="$(find "$db" -name "$term")"
  if [ -z "$path" ]; then
    >&2 echo "Not found: $term. Skipping."
    continue
  fi
  printf '\n'
  infocmp -L -x -1 -A "$db" "$term" | sed -e '1d' -e 's#^#// #' | tr '\t' ' '
  printf 'static const int8_t %s[] = {\n' "${entries[$term]}"
  printf '  '
  od -v -t d1 < "$path" | cut -c9- | xargs | tr ' ' ','
  printf '};\n'
done >> "$target"

print_bold 'done\n'
