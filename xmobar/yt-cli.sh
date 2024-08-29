#!/bin/bash

PID='.config/yt-cli/song.pid'
SOCKET='.config/yt-cli/song.socket'
SONG_INFO='.config/yt-cli/song.info'
SONG_STATUS='.config/yt-cli/song.status'
MAX=50

function is_paused() {
    local data
    data=$(echo '{ "command": ["get_property", "pause"] }' | socat - "$SOCKET" | jq -r .data)
    [[ "$data" == "true" ]]
}

if [[ -f "$PID" ]] && kill -0 $(cat "$PID") &> /dev/null; then
    echo -n " "
    
    IFS= read -r TITLE < "$SONG_INFO"

    if is_paused; then
        TITLE="[$TITLE]"
    fi

    if [[ ${#TITLE} -le $MAX ]]; then
        echo -n "$TITLE"
    else
        echo -n "${TITLE:0:MAX-3}..."
    fi

    echo " <fc=#000000> | </fc>"
fi

