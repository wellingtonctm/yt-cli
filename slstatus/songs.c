/* See LICENSE file for copyright and license details. */
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <signal.h>
#include <stdlib.h>

#include "../slstatus.h"
#include "../util.h"

#define MAX_TITLE_LEN 50
#define PATH_PID    ".config/yt-cli/song.pid"
#define PATH_SOCKET ".config/yt-cli/song.socket"
#define PATH_INFO   ".config/yt-cli/song.info"

static int
read_pid(const char *path)
{
	FILE *f = fopen(path, "r");
	if (!f)
		return -1;
	int pid;
	if (fscanf(f, "%d", &pid) != 1) {
		fclose(f);
		return -1;
	}
	fclose(f);
	return pid;
}

static int
check_paused(const char *sockpath)
{
	int fd, paused = 0;
	struct sockaddr_un addr;
	char buf[256];

	if ((fd = socket(AF_UNIX, SOCK_STREAM, 0)) < 0)
		return 0;

	memset(&addr, 0, sizeof(addr));
	addr.sun_family = AF_UNIX;
	strncpy(addr.sun_path, sockpath, sizeof(addr.sun_path) - 1);

	if (connect(fd, (struct sockaddr *)&addr, sizeof(addr)) == -1) {
		close(fd);
		return 0;
	}

	const char *cmd = "{ \"command\": [\"get_property\", \"pause\"] }\n";
	if (write(fd, cmd, strlen(cmd)) < 0) {
		close(fd);
		return 0;
	}

	ssize_t len = read(fd, buf, sizeof(buf) - 1);
	close(fd);
	if (len <= 0)
		return 0;

	buf[len] = '\0';
	if (strstr(buf, "\"data\":true"))
		paused = 1;

	return paused;
}

const char *
songs(const char *unused)
{
	char title[256], path[512];
	const char *home;
	int pid;

	home = getenv("HOME");
	if (!home)
		return NULL;

	snprintf(path, sizeof(path), "%s/%s", home, PATH_PID);
	if ((pid = read_pid(path)) < 0 || kill(pid, 0) != 0)
		return "";

	snprintf(path, sizeof(path), "%s/%s", home, PATH_INFO);
	FILE *f = fopen(path, "r");
	if (!f)
		return "";
	if (!fgets(title, sizeof(title), f)) {
		fclose(f);
		return "";
	}
	fclose(f);
	title[strcspn(title, "\n")] = '\0';

	int paused;
	snprintf(path, sizeof(path), "%s/%s", home, PATH_SOCKET);
	paused = check_paused(path);

	if (paused)
		snprintf(buf, sizeof(buf), "[%.47s] ", title);
	else
		snprintf(buf, sizeof(buf), "%.50s ", title);

	return buf;
}