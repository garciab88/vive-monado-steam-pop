#!/usr/bin/env bash
# Backward-compat alias. Any title: ./launch-game.sh <appid|slug>
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/launch-game.sh" beat-saber
