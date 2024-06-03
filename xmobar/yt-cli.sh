#!/bin/bash

SONG_INFO='.config/yt-cli/song.info'
SONG_STATUS='.config/yt-cli/song.status'
MAX=50

if [[ -f "$SONG_INFO" ]]; then
    [[ -f $SONG_STATUS ]] && [[ "$(cat $SONG_STATUS)" == 'PAUSED' ]] && STATUS='[PAUSED] '
    TITLE="${STATUS}$(sed ':a;N;$!ba;s/\n/ - /g' "$SONG_INFO")"

    if [[ $(echo -n "$TITLE" | wc -m) -le $MAX ]]; then
        echo -n "${TITLE}"
    else
        echo -n "$TITLE" | head -c $((MAX - 3))
        echo -n "..."
    fi

    echo " |"
fi

