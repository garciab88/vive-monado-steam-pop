#!/usr/bin/env bash
# Compat alias. Standalone path is ./build.sh (and ./install.sh).
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/build.sh" "$@"
