#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

int main(int argc, char *argv[]) {
    if (argc < 2) {
        fprintf(stderr, "Usage: vpntether_activate <key>\n");
        return 1;
    }
    setuid(0);
    setgid(0);
    char *args[] = {
        "/var/jb/usr/bin/bash",
        "/var/jb/usr/libexec/vpntether/vpntether_manager",
        "activate",
        argv[1],
        NULL
    };
    execv(args[0], args);
    perror("execv");
    return 1;
}
