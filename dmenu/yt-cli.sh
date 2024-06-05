#!/bin/bash

SOCKET='.config/yt-cli/song.socket'

function is_paused() {
    data=$(echo '{ "command": ["get_property", "pause"] }' | socat - "$SOCKET" | jq -r .data)

    if [[ "$data" == "true" ]]; then
        return 0
    fi

    return 1
}

options=()

if [[ -S "$SOCKET" ]]; then
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
options+=("Delete")

options=$(printf "%s\n" "${options[@]}")

selected_option=$(echo -e "$options" | dmenu -nb '#000000' -nf '#595959' -sb '#4d94ff' -sf '#000000'  -fn 'MesloLGS NF-10' -p "YouTube CLI:")

case $selected_option in
    "Add")
        yt-cli -a "$(xclip -selection clipboard -o | head -n 1)"
        ;;
    "Delete")
        selected_playlist=$(yt-cli -l | dmenu -nb '#000000' -nf '#595959' -sb '#4d94ff' -sf '#000000'  -fn 'MesloLGS NF-10' -p "Choose a playlist:" | grep -Po '^[0-9]+')
        yt-cli --delete $selected_playlist
        ;;
    "Play")
        selected_playlist=$(yt-cli -l | dmenu -nb '#000000' -nf '#595959' -sb '#4d94ff' -sf '#000000'  -fn 'MesloLGS NF-10' -p "Choose a playlist:" | grep -Po '^[0-9]+')
        yt-cli -p $selected_playlist -d 
        ;;
    "Shuffle")
        selected_playlist=$(yt-cli -l | dmenu -nb '#000000' -nf '#595959' -sb '#4d94ff' -sf '#000000'  -fn 'MesloLGS NF-10' -p "Choose a playlist:" | grep -Po '^[0-9]+')
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
