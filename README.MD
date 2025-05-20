# YouTube CLI

A minimalist command-line tool to manage and play YouTube Music playlists with offline caching, mpv playback, download queuing, desktop notifications, and support for detached daemonized control. Built with Bash, yt-dlp, and mpv.

## Requirements

To use this application, you need to install the following dependencies:

- `yt-dlp`  
  A feature-rich command-line audio/video downloader.  
  Installation instructions: [yt-dlp Installation Guide](https://github.com/yt-dlp/yt-dlp/wiki/Installation)

- `mpv`  
  A free, open-source, and cross-platform media player.  
  Installation instructions: [mpv Installation Guide](https://mpv.io/installation/)

- `socat`  
  A command-line based utility that establishes two bidirectional byte streams and transfers data between them.  
  Installation instructions: [Socat Installation Guide](https://www.baeldung.com/linux/socat-command)

- `flock`  
  A utility to manage locks from shell scripts.  
  Installation instructions: [flock Installation Guide](https://formulae.brew.sh/formula/flock)

- `notify-send` (for notifications)  
  A command-line tool to send desktop notifications.  
  Installation instructions: [notify-send Installation Guide](https://linuxconfig.org/how-to-send-desktop-notifications-using-notify-send)

- `slstatus` (for status refresh via signal)  
  A status monitor for window managers that use WM_NAME or stdin to fill the status bar.  
  Installation instructions: [slstatus Installation Guide](https://tools.suckless.org/slstatus/)

- Standard Unix tools (`pgrep`, `grep`, `sed`, etc.)

## Usage

To use the application, clone this repository and navigate to the cloned directory:

```bash
git clone <REPOSITORY_URL>
cd <REPOSITORY_NAME>
```

Then, make the script executable and run it with the help option to see the available commands:

```bash
chmod +x main.sh
./main.sh -h
```

## Features

- Add and delete YouTube playlists by URL  
- Download playlists for offline use (with caching)
- Play audio with `mpv`, including pause/resume/skip  
- Supports shuffle mode  
- Track download success/failure stats  
- Show song info with `notify-send`  
- Fully daemonizable for background play  
- Integrates with `slstatus` via `SIGRTMIN\+1`  
- Unix socket and PID file management  

## Plugins

This project includes integration scripts/plugins for popular minimalist tools:

- **slstatus**: Custom `songs.c` module to show current playback status in the status bar. Listens for `SIGRTMIN\+1` signals to refresh the display.  
- **dmenu**: `yt-cli.sh` script to interactively select and manage playlists via `dmenu` menus.  
- **xmobar**: `yt-cli.sh` script to integrate with `xmobar` for displaying current song info and playback controls.

---

## Directory Structure

```  
.  
├── dmenu  
│   └── yt-cli.sh  
├── main.sh  
├── README.MD  
├── slstatus  
│   └── songs.c  
└── xmobar  
    └── yt-cli.sh
```

## Usage

```bash  
yt-cli [OPTIONS]
```

### Options

| Option                    | Description                                     |  
|------------------------   |-------------------------------------------------|  
| `-a`, `--add URL`         | Add a new YouTube playlist                      |  
| `--delete INDEX`          | Delete the playlist at the specified index      |  
| `--delete-download INDEX` | Delete cached downloads for the playlist        |  
| `-d`, `--daemon`          | Run in background mode (detached)               |  
| `-p`, `--play INDEX`      | Play the playlist at the specified index        |  
| `-s`, `--shuffle`         | Shuffle the playlist before playing             |  
| `-n`, `--next`            | Skip to the next song                           |  
| `-b`, `--prev`            | Play the previous song                          |  
| `-t`, `--toggle`          | Toggle pause/resume                             |  
| `-z`, `--pause`           | Pause the currently playing song                |  
| `-r`, `--resume`          | Resume the paused song                          |  
| `-i`, `--info`            | Show current playing info                       |  
| `-l`, `--list`            | List all available playlists                    |  
| `-k`, `--kill`            | Kill the currently running instance             |  
| `--notify`                | Enable desktop notifications                    |  
| `-h`, `--help`            | Show help menu                                  |  

## Usage Examples

Add a new playlist by URL:

```bash  
yt-cli --add https://www.youtube.com/playlist?list=PLxxxxxxx  
```

List all playlists:

```bash  
yt-cli --list  
```

Play a playlist by its index (from `--list` output):

```bash  
yt-cli --play 0  
```

Play a playlist shuffled:

```bash  
yt-cli --play 0 --shuffle  
```

Pause/resume playback:

```bash  
yt-cli --toggle  
```

Skip to next song:

```bash  
yt-cli --next  
```

Delete a playlist:

```bash  
yt-cli --delete 1  
```

Delete cached downloads for a playlist:

```bash  
yt-cli --delete-download 1  
```

Run the player in daemon mode:

```bash  
yt-cli --daemon --play 0  
```

Enable desktop notifications:

```bash  
yt-cli --notify --play 0  
```

## Playlist Format

Each playlist file contains:  
- Line 1: Playlist title  
- Every 3 lines after:  
  - Line: Song title  
  - Line: Channel  
  - Line: YouTube URL  

## Configuration & Files

yt-cli uses several directories and files to manage its internal state:

### Directories

- **\${base_dir}**  
  Absolute path of the script directory (resolved via `readlink -f`).

- **\${home_dir}**  
  User home directory (resolved via `getent` and `logname` to support use with sudo).

- **\${conf_dir}** ⇒ \${home_dir}/.config/${cli_name}  
  Stores runtime files and configurations.

- **\${cache_dir}** ⇒ \${home_dir}/.cache/yt-cli  
  Cache directory for downloaded songs.

- **\${playlists_dir}** ⇒ \${conf_dir}/.playlists  
  Stores playlist metadata files.

### Runtime Files

- **main.pid** ⇒ \${conf_dir}/main.pid  
  PID of the currently running playlist playback process.

- **main.log** ⇒ \${conf_dir}/main.log  
  Log file for the main playback loop and errors.

- **song.pid** ⇒ \${conf_dir}/song.pid  
  PID of the current song’s `mpv` process.

- **song.socket** ⇒ \${conf_dir}/song.socket  
  UNIX IPC socket for controlling `mpv` (pause/resume/etc).

- **notification.pid** ⇒ \${conf_dir}/notification.pid  
  Stores the notification ID used by `notify-send` to replace existing messages.

- **song.info** ⇒ \${conf_dir}/song.info  
  Temporary file with current song title, channel, and index.

- **list.info** ⇒ \${conf_dir}/list.info  
  Contains the playlist name currently being played.

- **current.info** ⇒ \${conf_dir}/current.info  
  Index of the currently playing song in the playlist.

- **download.pid** ⇒ \${conf_dir}/download.pid  
  PID of the background playlist download task (if any).

## Signals

- `SIGRTMIN\+1` is sent to `slstatus` after playback state changes.

## Notes

- Download queue supports up to 10 parallel downloads.  
- Plays either downloaded audio (preferred) or falls back to streaming.  
- Uses `mpv`'s IPC for pause/resume.

## Configuration

The script creates configuration and playlist directories in your home folder:

- Configuration directory: ~/.config/yt-cli
- Playlists directory: ~/.config/yt-cli/.playlists

## Cleanup

To stop the script and cleanup:

```bash
yt-cli -k
```

## License

MIT License. See [LICENSE](LICENSE) for details.