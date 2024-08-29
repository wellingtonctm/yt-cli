#!/bin/bash

SOCKET='.config/yt-cli/song.socket'
PID='.config/yt-cli/song.pid'

function is_paused() {
    data=$(echo '{ "command": ["get_property", "pause"] }' | socat - "$SOCKET" | jq -r .data)

    if [[ "$data" == "true" ]]; then
        return 0
    fi

    return 1
}

options=()

if [[ -f "$PID" ]] && kill -0 $(cat "$PID") &> /dev/null; then
    if is_paused; then
        options+=("Resume")
    else
        options+=("Pause")     
        options+=("Next")
        options+=("Prev")
    fi

    options+=("Stop")
else
    options+=("Play")
    options+=("Shuffle")
fi

options+=("Add")
options+=("Download")
options+=("Delete")
options+=("Clear")

options=$(printf "%s\n" "${options[@]}")

selected_option=$(echo -e "$options" | dmenu-mod -p "YouTube CLI:")

echo $selected_option

case $selected_option in
    "Add")
        yt-cli --notify -a "$(xclip -selection clipboard -o | head -n 1)"
        ;;
    "Delete")
        selected_playlist=$(yt-cli -l | dmenu-mod -p "Choose a playlist:" | grep -Po '^[0-9]+')
        yt-cli --notify --delete $selected_playlist
        ;;
    "Download")
        selected_playlist=$(yt-cli -l | dmenu-mod -p "Choose a playlist:" | grep -Po '^[0-9]+')
        yt-cli --notify --download $selected_playlist
        ;;
    "Clear")
        selected_playlist=$(yt-cli -l | dmenu-mod -p "Choose a playlist:" | grep -Po '^[0-9]+')
        yt-cli --notify --delete-download $selected_playlist
        ;;
    "Play")
        selected_playlist=$(yt-cli -l | dmenu-mod -p "Choose a playlist:" | grep -Po '^[0-9]+')
        yt-cli -p $selected_playlist -d 
        ;;
    "Shuffle")
        selected_playlist=$(yt-cli -l | dmenu-mod -p "Choose a playlist:" | grep -Po '^[0-9]+')
        yt-cli -p $selected_playlist -s -d 
        ;;
    "Next")
        yt-cli -n
        ;;
    "Prev")
        yt-cli -b
        ;;
    "Pause")
        yt-cli -z
        ;;
    "Resume")
        yt-cli -r
        ;;
    "Stop")
        yt-cli -k        
        ;;
    *)
        echo "Invalid option"
        ;;
esac
