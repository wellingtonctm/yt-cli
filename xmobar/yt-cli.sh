#!/bin/bash

FILE='.config/yt-cli/song.info'
MAX=50

if [[ -f "$FILE" ]]; then
    TITLE=$(head -n 1 "$FILE")

    if [[ $(echo -n "$TITLE" | wc -m) -le $MAX ]]; then
        echo -n "${TITLE}"
    else
        echo -n "$TITLE" | head -c $((MAX - 3))
        echo -n "..."
    fi

    echo " |"
fi
