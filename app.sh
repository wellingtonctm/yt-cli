#!/bin/bash

app_name='YouTube CLI'
cli_name='yt-cli'
icon_name='youtube'

base_dir=$(dirname "$(readlink -f "$(which "$0")")")
conf_dir="$(getent passwd "$(logname)" | cut -d: -f6)/.config/${cli_name}"
playlists_dir="$conf_dir/.playlists"

main_pid_file="$conf_dir/main.pid"
main_log_file="$conf_dir/main.log"
song_pid_file="$conf_dir/song.pid"
nofication_pid_file="$conf_dir/notification.pid"
song_info_file="$conf_dir/song.info"
list_info_file="$conf_dir/list.info"

if [[ ! -d "$conf_dir" ]]; then
    mkdir -p "$conf_dir"
fi

if [[ ! -d "$playlists_dir" ]]; then
    mkdir -p "$playlists_dir"
fi

function cleanup() {
    if [[ -f $song_pid_file ]] && kill -0 "$(cat $song_pid_file)" &> /dev/null; then
        kill $(cat $song_pid_file)
    fi

    notification_id=$(cat $nofication_pid_file 2> /dev/null)
    rm "$main_pid_file" "$song_info_file" "$song_pid_file" "$nofication_pid_file" "$list_info_file" "$main_log_file" &> /dev/null
    notify-send -h int:transient:1 -p -r ${notification_id:-0} -i "$icon_name" "$app_name" "Stopped" &> /dev/null
    exit 0
}

function send-message() {
	local text="$1"
	local notification_id="$(cat $nofication_pid_file 2> /dev/null)"
	notify-send -p -r ${notification_id:-0} -i "$icon_name" "$app_name" "$text" > $nofication_pid_file
}

function send-error() {
	local text="$1"
	local notification_id="$(cat $nofication_pid_file 2> /dev/null)"
	notify-send -h int:transient:1 -p -r ${notification_id:-0} -i 'error' "$app_name" "$text" > $nofication_pid_file
}

function show-error() {
    local text="$1"
    echo "$text" >&2

    if [[ "$2" != '-n' ]]; then
        send-error "$text"
    fi
}

function add-playlist() {
	url="$1"
	playlist_id=$(grep -Po "^(https://)?(www.)?(music.)?(youtube.com/playlist\?list=)?\K[A-Za-z0-9_-]+" <<< "$url")
	content=$(yt-dlp --flat-playlist --print "%(playlist_title)s" --print "%(title)s" --print "%(channel)s" --print "%(url)s" "https://www.youtube.com/playlist?list=$playlist_id" | sed '5~4d')

	if [[ $? -eq 0 ]]; then
		echo "$content" > "$playlists_dir/$playlist_id"
	else
		show-error 'Invalid Playlist!'
	fi
}

function get-songs() {
    playlists=( $(ls -t1  "$playlists_dir") )

    if [[ ! -f "$playlists_dir/${playlists[$1]}" ]]; then
        echo "Playlist not found."
        exit 1;
    fi

    IFS=$'\n'
    playlist=( $(cat "$playlists_dir/${playlists[$1]}" | head -n 1) )
    songs=( $(cat "$playlists_dir/${playlists[$1]}" | sed -n '2~3p') )
    channels=( $(cat "$playlists_dir/${playlists[$1]}" | sed -n '3~3p') )
    urls=( $(cat "$playlists_dir/${playlists[$1]}" | sed -n '4~3p') )

    echo "$playlist" > "$list_info_file"
}

function shuffle-songs() {
    indexes=( $(shuf -i 0-$((${#songs[@]}-1))) )

    shuffled_songs=()
    shuffled_channels=()
    shuffled_urls=()

    for index in "${indexes[@]}"; do
        shuffled_songs+=("${songs[$index]}")
        shuffled_channels+=("${channels[$index]}")
        shuffled_urls+=("${urls[$index]}")
    done

    songs=("${shuffled_songs[@]}")
    channels=("${shuffled_channels[@]}")
    urls=("${shuffled_urls[@]}")
}

function show-playlists() {
    playlists=( $(ls -t1  "$playlists_dir") )

    if [[ ${#playlists[@]} -eq 0 ]]; then
        show-error 'No playlist found!' -n
        return 0
    fi

    for i in "${!playlists[@]}"; do
        echo "${i}: $(cat ${playlists_dir}/${playlists[$i]} | head -n 1)"
    done
}

function kill-song() {
    [[ -f $song_pid_file ]] && kill -0 "$(cat $song_pid_file)" &> /dev/null && kill $(cat $song_pid_file)
    return 0
}

function pause-song() {
    [[ -f $song_pid_file ]] && kill -0 "$(cat $song_pid_file)" &> /dev/null && kill -STOP $(cat $song_pid_file)
    return 0
}

function resume-song() {
    [[ -f $song_pid_file ]] && kill -0 "$(cat $song_pid_file)" &> /dev/null && kill -CONT $(cat $song_pid_file)
    return 0
}

function play-song() {
    trap kill-song RETURN

    mpv --audio-device=pulse --no-terminal --no-video --cache-secs=60 ${urls[$1]} &
    song_pid=$! && echo $song_pid > $song_pid_file

    echo -e "${songs[$1]}\n${channels[$1]}" | tee $song_info_file
    send-message "${songs[$1]} - ${channels[$1]}"

    while kill -0 "$song_pid" &> /dev/null; do
        sleep 1s;
    done;

    echo
    return 0
}

function get-info() {
    [[ -f "$song_info_file" ]] && cat "$list_info_file"
    [[ -f "$song_info_file" ]] && cat "$song_info_file"
    return 0
}

function help-menu() {
    echo "Usage: $cli_name [OPTIONS]"
    echo
    echo "Options:"
    echo "  -a, --add URL     Add a new YouTube playlist."
    echo "  -d, --daemon      Run in background mode detached."
    echo "  -p, --play INDEX  Play the playlist at the specified index."
    echo "  -l, --list        List all available playlists."
    echo "  -n, --next        Skip to the next song."
    echo "  -z, --pause       Pause the currently playing song."
    echo "  -r, --resume      Resume the paused song."
    echo "  -i, --info        Display info about the current status."
    echo "  -s, --shuffle     Shuffle the songs in the playlist."
    echo "  -k, --kill        Kill the currently running instance."
    echo "  -h, --help        Display this help message."
    echo
}

function main() {
    trap cleanup EXIT HUP

    if [[ ! "$playlist_index" =~ ^[0-9]+$ ]]; then
        show-error "Select a valid playlist with: ${cli_name} --play [INDEX]" -n
        show-error "Use ${cli_name} -h for help" -n
        exit 1
    fi

    get-songs "$playlist_index"

    echo "PLAYLIST: $playlist"
    if [[ $shuffle -eq 1 ]]; then
        echo "SHUFFLE: ON"
        shuffle-songs
    else
        echo "SHUFFLE: OFF"
    fi

    echo

    for index in "${!songs[@]}"; do
        play-song "$index"
    done

    echo "PLAYLIST ENDED!"
    return 0
}

if [[ "$1" == "" ]]; then
    show-error 'Wrong usage!' -n
    show-error "Use ${cli_name} -h for help" -n
    exit 1
fi

while [[ "$1" != "" ]]; do
    case "$1" in
        -a | --add)
            shift
            add-playlist "$1"
            exit 0
            ;;
        -d | --daemon)
            daemon=1
            ;;
        -p | --play)
            shift
            playlist_index="$1"
            ;;
        -l | --list)
            show-playlists
            exit 0
            ;;
        -n | --next)
            kill-song
            exit 0
            ;;
        -z | --pause)
            pause-song
            exit 0
            ;;
        -r | --resume)
            resume-song
            exit 0
            ;;
        -i | --info)
            get-info
            exit 0
            ;;
        -s | --shuffle)
            shuffle=1
            ;;
        -k | --kill)
            [[ -f $main_pid_file ]] && kill -0 "$(cat $main_pid_file)" && kill "$(cat $main_pid_file)"
            exit 0
            ;;
        -h | --help)
            help-menu
            exit 0
            ;;
        *)
            show-error 'Invalid oprion!' -n
            show-error "Use ${cli_name} -h for help" -n
            exit 1
            ;;
    esac

    shift
done

if [[ -f $main_pid_file ]] && kill -0 $(cat $main_pid_file) &> /dev/null; then
    echo "There is an instance already running ($(cat $main_pid_file))."
    exit 1
fi

if [[ $daemon -eq 1 ]]; then
    main &>"$main_log_file" & disown
    echo $! > $main_pid_file
else
    echo $$ > $main_pid_file
    main | tee "$main_log_file"
fi

exit 0