#!/bin/bash

app_name='YouTube CLI'
cli_name='yt-cli'
icon_name='youtube'

base_dir=$(dirname "$(readlink -f "$(which "$0")")")
home_dir="$(getent passwd "$(logname)" | cut -d: -f6)"
conf_dir="${home_dir}/.config/${cli_name}"
cache_dir="${home_dir}/.cache/yt-cli"
playlists_dir="$conf_dir/.playlists"

main_pid_file="$conf_dir/main.pid"
main_log_file="$conf_dir/main.log"
song_pid_file="$conf_dir/song.pid"
song_socket_file="$conf_dir/song.socket"
nofication_pid_file="$conf_dir/notification.pid"
song_info_file="$conf_dir/song.info"
list_info_file="$conf_dir/list.info"
current_index_file="$conf_dir/current.info"
download_pid_file="$conf_dir/download.pid"

if [[ ! -d "$conf_dir" ]]; then
    mkdir -p "$conf_dir"
fi

if [[ ! -d "$cache_dir" ]]; then
    mkdir -p "$cache_dir"
fi

if [[ ! -d "$playlists_dir" ]]; then
    mkdir -p "$playlists_dir"
fi

function refresh-slstatus() {
    local slstatus_pid=$(pgrep -n slstatus)
    kill -SIGRTMIN+1 $slstatus_pid &> /dev/null
}

function cleanup() {
    if [[ -f $song_pid_file ]] && kill -0 "$(cat $song_pid_file)" &> /dev/null; then
        kill $(cat $song_pid_file)
    fi

    rm "$main_pid_file" "$current_index_file" "$song_info_file" "$song_socket_file" "$song_pid_file" "$nofication_pid_file" "$list_info_file" "$main_log_file" &> /dev/null
    
    refresh-slstatus

    if [[ $notifications -eq 1 ]]; then
        local notification_id=$(cat $nofication_pid_file 2> /dev/null)
        notify-send -h int:transient:1 -p -r ${notification_id:-0} -i "$icon_name" "$app_name" "Stopped" &> /dev/null
    fi
    
    exit 0
}

function send-message() {
    [[ $notifications -eq 0 ]] && return 0

	local text="$1"
	local notification_id="$(cat $nofication_pid_file 2> /dev/null)"
	notify-send -p -r ${notification_id:-0} -i "$icon_name" "$app_name" "$text" > $nofication_pid_file
}

function send-error() {
    [[ $notifications -eq 0 ]] && return 0

	local text="$1"
	local notification_id="$(cat $nofication_pid_file 2> /dev/null)"
	notify-send -h int:transient:1 -p -r ${notification_id:-0} -i "$icon_name" "$app_name" "$text" > $nofication_pid_file
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
	content=$(yt-dlp --flat-playlist --print "%(playlist_title)s" --print "%(title)s" --print "%(channel)s" --print "%(url)s" "https://www.youtube.com/playlist?list=$playlist_id")

	if [[ $? -eq 0 ]]; then
		echo "$content" | sed '5~4d' > "$playlists_dir/$playlist_id"
        send-message 'Playlist added!'
	else
		show-error 'Invalid playlist!'
	fi
}

function delete-playlist() {
    local playlist_index="$1"

    if [[ ! "$playlist_index" =~ ^[0-9]+$ ]]; then
        show-error "Select a valid playlist with: ${cli_name} --delete [INDEX]" -n
        show-error "Use ${cli_name} -h for help" -n
        exit 1
    fi

    playlists=( $(ls -t1  "$playlists_dir") )

    if [[ ! -f "$playlists_dir/${playlists[$playlist_index]}" ]]; then
        echo "Playlist not found."
        exit 1;
    fi

    if [[ -d "${cache_dir}/${playlists[$playlist_index]}" ]]; then
        rm -rf "${cache_dir}/${playlists[$playlist_index]}"
    fi

    rm -f "$playlists_dir/${playlists[$playlist_index]}"

    send-message 'Playlist deleted!'
}

function delete-download() {
    local playlist_index="$1"

    if [[ ! "$playlist_index" =~ ^[0-9]+$ ]]; then
        show-error "Select a valid playlist with: ${cli_name} --delete-download [INDEX]" -n
        show-error "Use ${cli_name} -h for help" -n
        exit 1
    fi

    playlists=( $(ls -t1  "$playlists_dir") )

    if [[ ! -f "$playlists_dir/${playlists[$playlist_index]}" ]]; then
        echo "Playlist not found."
        exit 1;
    fi

    if [[ ! -d "${cache_dir}/${playlists[$playlist_index]}" ]]; then
        exit 0
    fi

    rm -rf "${cache_dir}/${playlists[$playlist_index]}"
    send-message 'Download deleted!'
}

function get-songs() {
    playlists=( $(ls -t1  "$playlists_dir") )

    if [[ ! -f "$playlists_dir/${playlists[$1]}" ]]; then
        echo "Playlist not found."
        exit 1;
    fi

    IFS=$'\n'
    playlist_id="${playlists[$1]}"
    playlist=$(cat "$playlists_dir/${playlists[$1]}" | head -n 1)
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
    refresh-slstatus
    return 0
}

function pause-song() {
    [[ -S "$song_socket_file" ]] && echo '{ "command": ["set_property", "pause", true] }' | socat - "$song_socket_file" &> /dev/null
    refresh-slstatus
    return 0
}

function resume-song() {
    [[ -S "$song_socket_file" ]] && echo '{ "command": ["set_property", "pause", false] }' | socat - "$song_socket_file" &> /dev/null
    refresh-slstatus
    return 0
}

function toggle-song() {
    [[ -S "$song_socket_file" ]] && echo '{ "command": ["cycle", "pause"] }' | socat - "$song_socket_file" &> /dev/null
    refresh-slstatus
    return 0
}

function download-song() {
    local playlist_dir=$1
    local song_index=$2
    local total_songs=$3
    local song_id=$(grep -Po "^(https://)?(www.)?(music.)?(youtube.com/watch\?v=)?\K[A-Za-z0-9_-]+" <<< "${urls[$song_index]}")
    local download_failed=false
    local log_file=$(mktemp "${playlist_dir}/${song_id}.XXXXXX.log")

    if [[ ! -f "${playlist_dir}/${song_id}" ]]; then
        yt-dlp -f bestaudio -o "${playlist_dir}/%(id)s" "${urls[$song_index]}" &> "$log_file"

        if [[ $? == 0 ]]; then
            rm -f "$log_file"
        else
            rm -f "${playlist_dir}/${song_id}"
            download_failed=true
        fi
    fi
    
    local success_count_file="${playlist_dir}/download_count.txt"
    local failure_count_file="${playlist_dir}/fail_count.txt"
    local lock_file="${playlist_dir}/download_lock"

    {
        flock 200

        success_count=$(<"$success_count_file")
        failure_count=$(<"$failure_count_file")

        if [[ $download_failed == true ]]; then 
            failure_count=$((failure_count + 1))
            echo "$failure_count" > "$failure_count_file"
        else
            success_count=$((success_count + 1))
            echo "$success_count" > "$success_count_file"
        fi

        send-message "Downloading...\nSuccess: ${success_count}\nFail: ${failure_count}\nTotal: ${total_songs}"
    } 200>"$lock_file"
}

function download-playlist() {
    if [[ -f $download_pid_file ]] && kill -0 "$(cat $download_pid_file)" &> /dev/null; then
        return 0
    fi

    echo $$ > $download_pid_file
    local selected_playlist_index="$1"

    if [[ ! "$selected_playlist_index" =~ ^[0-9]+$ ]]; then
        show-error "Select a valid playlist with: ${cli_name} --delete [INDEX]" -n
        show-error "Use ${cli_name} -h for help" -n
        exit 1
    fi

    playlists=( $(ls -t1 "$playlists_dir") )

    if [[ ! -f "$playlists_dir/${playlists[$selected_playlist_index]}" ]]; then
        echo "Playlist not found."
        exit 1
    fi

    local playlist_dir="${cache_dir}/${playlists[$selected_playlist_index]}"
    mkdir -p "$playlist_dir"
    get-songs "$selected_playlist_index"
    send-message 'Downloading...'

    echo "0" > "${playlist_dir}/download_count.txt"
    echo "0" > "${playlist_dir}/fail_count.txt"

    rm -f "${playlist_dir}/"*.log

    local total_songs=${#songs[@]}
    local max_parallel_downloads=10
    local active_downloads=0

    for song_index in "${!songs[@]}"; do
        download-song "$playlist_dir" "$song_index" "$total_songs" &
        ((active_downloads++))

        if [[ $active_downloads -ge $max_parallel_downloads ]]; then
            wait -n
            ((active_downloads--))
        fi
    done

    wait

    local final_success_count
    [[ -f "${playlist_dir}/download_count.txt" ]] && read -r final_success_count < "${playlist_dir}/download_count.txt"

    local final_failure_count
    [[ -f "${playlist_dir}/fail_count.txt" ]] && read -r final_failure_count < "${playlist_dir}/fail_count.txt"

    send-message "Downloaded!\nSuccess: ${final_success_count}\nFail: ${final_failure_count}\nTotal: ${total_songs}"

    local urls_str="${urls[@]}"
    local video_ids=()

    for url in "${urls[@]}"; do
        video_ids+=( $(grep -Po "^(https://)?(www.)?(music.)?(youtube.com/watch\?v=)?\K[A-Za-z0-9_-]+" <<< "${url}") )
    done

    for file_name in $(ls -1 "$playlist_dir"); do
        local is_valid_video_id=false
        
        for video_id in "${video_ids[@]}"; do
            if [[ "$video_id" == "$file_name" || "${video_id}.log" == "$file_name" ]]; then
                is_valid_video_id=true
                break
            fi
        done

        if ! $is_valid_video_id; then
            rm -f "${playlist_dir}/${file_name}"
        fi
    done
    
    return 0
}

function play-song() {
    trap kill-song RETURN
    song_index="$1"

    song_id=$(grep -Po "^(https://)?(www.)?(music.)?(youtube.com/watch\?v=)?\K[A-Za-z0-9_-]+" <<< "${urls[$song_index]}")

    if [[ -f "${cache_dir}/${playlist_id}/${song_id}" ]]; then
        song="${cache_dir}/${playlist_id}/${song_id}"
    else
        song="${urls[$song_index]}"
    fi

    mpv --audio-device=pulse --no-terminal --no-video --input-ipc-server="$song_socket_file" --cache-secs=60 "$song" &
    song_pid=$! && echo $song_pid > $song_pid_file

    echo -e "${songs[$song_index]}\n${channels[$song_index]}\n$((song_index + 1))/${#songs[@]}" | tee $song_info_file
    refresh-slstatus
    send-message "${songs[$song_index]} - ${channels[$song_index]}"

    wait $song_pid
    exit_code=$?

    echo
    return $exit_code
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
    echo "  --delete INDEX    Delete the playlist at the specified index."
    echo "  -d, --daemon      Run in background mode detached."
    echo "  -p, --play INDEX  Play the playlist at the specified index."
    echo "  -l, --list        List all available playlists."
    echo "  -n, --next        Skip to the next song."
    echo "  -b, --prev        Play the previous song."
    echo "  -t, --toggle      Pause/resume the currently song."
    echo "  -z, --pause       Pause the currently playing song."
    echo "  -r, --resume      Resume the paused song."
    echo "  -i, --info        Display info about the current status."
    echo "  -s, --shuffle     Shuffle the songs in the playlist."
    echo "  -k, --kill        Kill the currently running instance."
    echo "  --notify          Enable desktop notifications."
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

    if [[ -d "${cache_dir}/${playlist_id}" ]]; then
        echo "DOWNLOADED: YES"
    else
        echo "DOWNLOADED: NO"
    fi

    echo

    echo 0 > "$current_index_file"

    total=${#songs[@]}

    while true; do
        index=$(cat "$current_index_file")

        if [[ $index -ge $total ]]; then
            break;
        fi

        play-song "$index" &&
        echo $(( index + 1 )) > "$current_index_file"
    done

    echo "PLAYLIST ENDED!"
    return 0
}

function next-song() {
    if [[ -f "$current_index_file" ]]; then
        index=$(cat "$current_index_file")
        echo $(( index + 1 )) > "$current_index_file"
        kill-song
    fi

    return 0
}

function prev-song() {
    if [[ -f "$current_index_file" ]]; then
        index=$(cat "$current_index_file")

        if [[ $index -gt 0  ]]; then
            echo $(( index - 1 )) > "$current_index_file"
            kill-song
        fi
    fi

    return 0
}

playlist_index=0

while [[ "$1" != "" ]]; do
    case "$1" in
        -a | --add)
            shift
            add-playlist "$1"
            exit 0
            ;;
        --delete)
            shift
            delete-playlist "$1"
            exit 0
            ;;
        --download)
            shift
            download-playlist "$1"
            exit 0
            ;;
        --delete-download)
            shift
            delete-download "$1"
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
            next-song
            exit 0
            ;;
        -b | --prev)
            prev-song
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
        -t | --toggle)
            toggle-song
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
            if [[ ! -f $main_pid_file ]]; then
                show-error "No running instance found!" -n
                exit 1
            fi

            kill "$(cat $main_pid_file)" &> /dev/null
            exit 0
            ;;
        --notify)
            notifications=1
            ;;
        -h | --help)
            help-menu
            exit 0
            ;;
        *)
            show-error 'Invalid option!' -n
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
    main
fi

exit 0