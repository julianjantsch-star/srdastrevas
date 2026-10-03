#!/bin/sh
# run.sh plano.lua pasta [extra mame args]
cd "$(dirname "$0")"; P=$1; D=$2; shift 2; rm -rf "$D"; mkdir -p "$D"
PLAN=$P SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy /usr/games/mame odyssey2 -rompath roms -cart cart/o2_45.bin -skip_gameinfo -nothrottle -video soft -window -snapshot_directory "$D" -snapname '%i' -autoboot_script drive.lua -cfg_directory cfg -nvram_directory nv -sound none "$@" 2>&1 | grep -v ALSA
