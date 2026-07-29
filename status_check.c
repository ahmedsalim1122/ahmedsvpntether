#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <ifaddrs.h>
#include <arpa/inet.h>
#include <net/if.h>
#include <sys/sysctl.h>
#include <sys/proc.h>

static int have_ip(const char *ifname) {
    struct ifaddrs *ifa0 = NULL;
    if (getifaddrs(&ifa0) < 0) return 0;
    int found = 0;
    for (struct ifaddrs *i = ifa0; i; i = i->ifa_next) {
        if (strcmp(i->ifa_name, ifname) != 0) continue;
        if (i->ifa_addr && i->ifa_addr->sa_family == AF_INET) {
            found = 1; break;
        }
    }
    freeifaddrs(ifa0);
    return found;
}

static int relay_running(void) {
    int mib[4] = { CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0 };
    size_t size = 0;
    if (sysctl(mib, 4, NULL, &size, NULL, 0) < 0) return 0;
    struct kinfo_proc *p = malloc(size);
    if (!p) return 0;
    if (sysctl(mib, 4, p, &size, NULL, 0) < 0) { free(p); return 0; }
    int n = size / sizeof(struct kinfo_proc), running = 0;
    for (int i = 0; i < n; i++) {
        if (strcmp(p[i].kp_proc.p_comm, "vpntether_nat") == 0) { running = 1; break; }
    }
    free(p);
    return running;
}

static int license_file_ok(void) {
    FILE *f = fopen("/var/db/vpntether_license", "r");
    if (!f) return 0;
    char buf[64] = {0};
    if (!fgets(buf, sizeof(buf), f)) { fclose(f); return 0; }
    fclose(f);
    return 1;
}

int main(void) {
    printf("VPN=%d\n", have_ip("utun5"));
    printf("HOTSPOT=%d\n", have_ip("bridge100"));
    printf("RELAY=%d\n", relay_running());
    printf("LICENSE=%d\n", license_file_ok());
    return 0;
}
