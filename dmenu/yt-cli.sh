#!/bin/bash

options=()

if [[ ! -f ~/.config/yt-cli/main.pid ]]; then
    options+=("Play")
    options+=("Shuffle")
else
    options+=("Next")
    options+=("Pause")
    options+=("Resume")
    options+=("Stop")
fi

options+=("Add")

options=$(printf "%s\n" "${options[@]}")

selected_option=$(echo -e "$options" | dmenu -nb '#000000' -nf '#595959' -sb '#4d94ff' -sf '#000000'  -fn 'MesloLGS NF-10' -p "YouTube CLI:")

case $selected_option in
    "Add")
        yt-cli -a "$(xclip -selection clipboard -o)"
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
