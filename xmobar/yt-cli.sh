#!/bin/bash

SOCKET='.config/yt-cli/song.socket'
SONG_INFO='.config/yt-cli/song.info'
SONG_STATUS='.config/yt-cli/song.status'
MAX=50

function is_paused() {
    data=$(echo '{ "command": ["get_property", "pause"] }' | socat - "$SOCKET" | jq -r .data)

    if [[ "$data" == "true" ]]; then
        return 0
    fi

    return 1
}

if [[ -S "$SOCKET" ]]; then
    TITLE=$(head -n 1 "$SONG_INFO")

    is_paused && TITLE="[$TITLE]"

    if [[ $(echo -n "$TITLE" | wc -m) -le $MAX ]]; then
        echo -n "${TITLE}"
    else
        echo -n "$TITLE" | head -c $((MAX - 3))
        echo -n "..."
    fi

    echo " |"
fi

