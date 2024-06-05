# YouTube CLI

A simple script to play YouTube playlists in the Linux terminal using yt-dlp and mpv.

## Requirements

To use this application, you need to install the following dependencies:

- yt-dlp
- mpv
- libnotify

You can install them using the following commands (for Debian-based distributions like Ubuntu):

```bash
sudo apt update
sudo apt install yt-dlp mpv libnotify-bin
```

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

## Available Commands

| Command            | Description                                  |
|--------------------|----------------------------------------------|
| `-a, --add URL`    | Add a new YouTube playlist.                  |
| `--delete INDEX`   | Delete the playlist at the specified index.  |
| `-d, --daemon`     | Run in background mode.                      |
| `-p, --play INDEX` | Play the playlist at the specified index.    |
| `-l, --list`       | List all available playlists.                |
| `-n, --next`       | Skip to the next song.                       |
| `-b, --prev`       | Play the previous song.                      |
| `-z, --pause`      | Pause the currently playing song.            |
| `-r, --resume`     | Resume the paused song.                      |
| `-i, --info`       | Display information about the current status.|
| `-s, --shuffle`    | Shuffle the songs in the playlist.           |
| `-k, --kill`       | Kill the currently running instance.         |
| `--notify`         | Enable desktop notifications.                |
| `-h, --help`       | Display this help message.                   |


## Example

1. Add a Playlist:

```bash
./main.sh -a <PLAYLIST_URL>
```

2. List Playlists:

```bash
./main.sh -l
```

3. Play a Playlist:

```bash
./main.sh -p 0
```

4. Pause and Resume:

```bash
./main.sh -z  # Pause
./main.sh -r  # Resume
```

4. Shuffle and Play:

```bash
./main.sh -s -p 0
```

## Configuration

The script creates configuration and playlist directories in your home folder:

- Configuration directory: ~/.config/yt-cli
- Playlists directory: ~/.config/yt-cli/.playlists

## Cleanup

To stop the script and cleanup:

```bash
./main.sh -k
```