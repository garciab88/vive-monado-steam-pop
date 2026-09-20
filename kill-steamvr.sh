#!/usr/bin/env bash
# Kill Valve's compositor stack. SteamVR may remain INSTALLED for lighthouse
# room-setup data. It must NOT run as the compositor.
set -u

names=(
  vrcompositor
  vrcompositor-launcher
  vrserver
  vrmonitor
  vrwebhelper
  vrdashboard
  vrstartup
  vrmonitor.bin
)

for n in "${names[@]}"; do
  pkill -x "$n" >/dev/null 2>&1 || true
done

# Broader match for Proton/Steam helper paths that include the binary name.
for n in vrcompositor vrserver vrmonitor vrwebhelper vrdashboard vrstartup; do
  pkill -f "/${n}" >/dev/null 2>&1 || true
done

# Belt and suspenders — the original one-liner, ignored if pkill rejects extras.
pkill vrcompositor >/dev/null 2>&1 || true
pkill vrserver >/dev/null 2>&1 || true
pkill vrmonitor >/dev/null 2>&1 || true
pkill vrwebhelper >/dev/null 2>&1 || true
pkill vrdashboard >/dev/null 2>&1 || true

sleep 0.3

still=""
for n in vrcompositor vrserver vrmonitor; do
  if pgrep -x "$n" >/dev/null 2>&1; then
    still="${still} ${n}"
    pkill -9 -x "$n" >/dev/null 2>&1 || true
  fi
done

if pgrep -x vrcompositor >/dev/null 2>&1 || pgrep -x vrserver >/dev/null 2>&1; then
  printf 'vive-monado: warn: SteamVR still running after kill:%s\n' "$still" >&2
  printf 'vive-monado: a desktop preview with black Vive panels means vrcompositor stole HDMI.\n' >&2
  exit 1
fi

printf 'vive-monado: SteamVR compositor stack is down (vrcompositor/vrserver/vrmonitor not running).\n'
exit 0
