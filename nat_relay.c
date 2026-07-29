#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <signal.h>
#include <time.h>
#include <pthread.h>

#include <sys/types.h>
#include <sys/param.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <sys/sysctl.h>
#include <net/if.h>
#include <net/if_dl.h>
#include <net/if_types.h>
#include <net/ethernet.h>
#include <sys/ioccom.h>

#include <netinet/in.h>
#include <netinet/in_systm.h>
#include <netinet/ip.h>
#include <netinet/tcp.h>
#include <netinet/udp.h>
#include <netinet/ip_icmp.h>

#include <arpa/inet.h>
#include <ifaddrs.h>

// Inline BPF definitions (no net/bpf.h in iOS SDK)
#define DLT_NULL    0
#define DLT_EN10MB  1
#define DLT_RAW     12

struct bpf_hdr {
    uint32_t       bh_tstamp_sec;
    uint32_t       bh_tstamp_usec;
    uint32_t       bh_caplen;
    uint32_t       bh_datalen;
    uint16_t       bh_hdrlen;
} __attribute__((packed));

#define BPF_WORDALIGN(x) (((x) + 3) & ~3)

#define BIOCGBLEN      _IOR('B', 102, unsigned int)
#define BIOCSETIF      _IOW('B', 108, struct ifreq)
#define BIOCGDLT       _IOR('B', 106, unsigned int)
#define BIOCIMMEDIATE  _IOW('B', 112, unsigned int)
#define BIOCPROMISC    _IO('B', 105)

#ifndef SIOCGIFMAC
#define SIOCGIFMAC _IOWR('i', 132, struct ifreq)
#endif

// Anti-debug / anti-tamper
#include <sys/sysctl.h>
#include <sys/proc.h>
#include <mach/mach_time.h>

#ifndef PT_DENY_ATTACH
#define PT_DENY_ATTACH 31
#endif
extern int ptrace(int, pid_t, caddr_t, int);

static void anti_debug(void) {
    ptrace(PT_DENY_ATTACH, 0, 0, 0);

    struct kinfo_proc info;
    size_t size = sizeof(info);
    int mib[4] = { CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid() };
    if (sysctl(mib, 4, &info, &size, NULL, 0) == 0)
        if (info.kp_proc.p_flag & P_TRACED) _exit(1);

    uint64_t start = mach_absolute_time();
    for (int i = 0; i < 200000; i++) asm volatile("");
    if (mach_absolute_time() - start > 500000000ULL) _exit(1);
}

// String obfuscation: strings stored XOR'd (key 0xAA), decoded at runtime
#define XSTR(s) ({ static const unsigned char _x[] = s; obf(_x, sizeof(_x)); })
static char xbuf[4][256];
static int xidx;
static const char *obf(const unsigned char *s, int len) {
    char *b = xbuf[xidx % 4]; xidx++;
    for (int i = 0; i < len; i++) b[i] = s[i] ^ 0xAA;
    b[len] = 0;
    return b;
}
// Pre-XOR'd strings (generated: python -c "print(','.join(f'0x{b^0xAA:02x}' for b in b'string'))")
#define S_BRIDGE  {0xc8,0xd8,0xc3,0xce,0xcd,0xcf,0x9b,0x9a,0x9a}
#define S_UTUN    {0xdf,0xde,0xdf,0xc4}
#define S_INET    {0xc3,0xc4,0xcf,0xde,0x8a}
#define S_VPNTH   {0xdc,0xda,0xc4,0xde,0xcf,0xde,0xc2,0xcf,0xd8}

// Obfuscated string output (clear-text after runtime XOR)
#define BRIDGE XSTR(S_BRIDGE)
#define UTUN   XSTR(S_UTUN)
#define INET   XSTR(S_INET)
#define VPNTH  XSTR(S_VPNTH)

// NAT table
#define NAT_HASH_SZ 4096
#define MAX_NAT_ENTRIES 8192
#define NAT_TCP_IDLE 3600
#define NAT_UDP_IDLE 120
#define NAT_ICMP_IDLE 30
#define NAT_PORT_START 30000
#define NAT_PORT_END 60000

struct nat_entry {
    struct nat_entry *next_in;
    struct nat_entry *next_out;
    time_t last_seen;
    uint32_t client_ip;
    uint16_t client_port;
    uint32_t dest_ip;
    uint16_t dest_port;
    uint8_t proto;
    uint32_t nat_ip;
    uint16_t nat_port;
    uint8_t client_mac[6];
    uint8_t tcp_state;
};

static struct nat_entry *nat_table_in[NAT_HASH_SZ];
static struct nat_entry *nat_table_out[NAT_HASH_SZ];
static int nat_port_bitmap[(NAT_PORT_END - NAT_PORT_START + 1) / 8 + 1];
static pthread_mutex_t nat_lock = PTHREAD_MUTEX_INITIALIZER;

static uint32_t nat_hash(uint32_t a, uint16_t b, uint32_t c, uint16_t d, uint8_t e) {
    uint32_t h = a ^ (b << 16) ^ c ^ (d << 16) ^ (e << 24);
    h ^= h >> 16; h *= 0x85ebca6b; h ^= h >> 13;
    h *= 0xc2b2ae35; h ^= h >> 16;
    return h;
}

static uint16_t alloc_nat_port(void) {
    static uint16_t last = NAT_PORT_START;
    for (int tries = 0; tries < (NAT_PORT_END - NAT_PORT_START); tries++) {
        if (++last >= NAT_PORT_END) last = NAT_PORT_START;
        int idx = last - NAT_PORT_START;
        if (!(nat_port_bitmap[idx / 8] & (1 << (idx % 8)))) {
            nat_port_bitmap[idx / 8] |= (1 << (idx % 8));
            return last;
        }
    }
    return 0;
}

static void free_nat_port(uint16_t port) {
    if (port >= NAT_PORT_START && port <= NAT_PORT_END) {
        int idx = port - NAT_PORT_START;
        nat_port_bitmap[idx / 8] &= ~(1 << (idx % 8));
    }
}

static struct nat_entry *nat_lookup_inbound(uint32_t nat_ip, uint16_t nat_port, uint8_t proto) {
    uint32_t h = nat_hash(nat_ip, nat_port, 0, 0, proto);
    int bucket = h % NAT_HASH_SZ;
    for (struct nat_entry *e = nat_table_in[bucket]; e; e = e->next_in) {
        if (e->nat_port == nat_port && e->nat_ip == nat_ip && e->proto == proto)
            return e;
    }
    return NULL;
}

static uint32_t nat_hash_out(uint32_t client_ip, uint16_t client_port,
                              uint32_t dest_ip, uint16_t dest_port, uint8_t proto) {
    return nat_hash(client_ip, client_port, dest_ip, dest_port, proto);
}

static struct nat_entry *nat_lookup_outbound(uint32_t client_ip, uint16_t client_port,
                                              uint32_t dest_ip, uint16_t dest_port, uint8_t proto) {
    uint32_t h = nat_hash_out(client_ip, client_port, dest_ip, dest_port, proto);
    int bucket = h % NAT_HASH_SZ;
    for (struct nat_entry *e = nat_table_out[bucket]; e; e = e->next_out) {
        if (e->client_ip == client_ip && e->client_port == client_port &&
            e->dest_ip == dest_ip && e->dest_port == dest_port && e->proto == proto)
            return e;
    }
    return NULL;
}

static struct nat_entry *nat_add(uint32_t client_ip, uint16_t client_port,
                                  uint32_t dest_ip, uint16_t dest_port, uint8_t proto,
                                  uint32_t nat_ip, const uint8_t *client_mac) {
    uint16_t nat_port = alloc_nat_port();
    if (!nat_port) return NULL;
    uint32_t h_in = nat_hash(nat_ip, nat_port, 0, 0, proto);
    uint32_t h_out = nat_hash_out(client_ip, client_port, dest_ip, dest_port, proto);
    struct nat_entry *e = calloc(1, sizeof(*e));
    if (!e) { free_nat_port(nat_port); return NULL; }
    e->client_ip = client_ip;
    e->client_port = client_port;
    e->dest_ip = dest_ip;
    e->dest_port = dest_port;
    e->proto = proto;
    e->nat_ip = nat_ip;
    e->nat_port = nat_port;
    e->last_seen = time(NULL);
    if (client_mac) memcpy(e->client_mac, client_mac, 6);
    // Insert into inbound hash
    int b_in = h_in % NAT_HASH_SZ;
    e->next_in = nat_table_in[b_in];
    nat_table_in[b_in] = e;
    // Insert into outbound hash
    int b_out = h_out % NAT_HASH_SZ;
    e->next_out = nat_table_out[b_out];
    nat_table_out[b_out] = e;
    return e;
}

static void nat_cleanup(void) {
    time_t now = time(NULL);
    for (int i = 0; i < NAT_HASH_SZ; i++) {
        struct nat_entry **pp = &nat_table_in[i];
        while (*pp) {
            struct nat_entry *e = *pp;
            int idle = (int)(now - e->last_seen);
            int max_idle = (e->proto == IPPROTO_TCP) ? NAT_TCP_IDLE :
                           (e->proto == IPPROTO_UDP) ? NAT_UDP_IDLE : NAT_ICMP_IDLE;
            if (idle > max_idle || (e->tcp_state == 0x04)) {
                // Remove from inbound table
                *pp = e->next_in;
                // Remove from outbound table
                uint32_t h_out = nat_hash_out(e->client_ip, e->client_port,
                                              e->dest_ip, e->dest_port, e->proto);
                int b_out = h_out % NAT_HASH_SZ;
                struct nat_entry **op = &nat_table_out[b_out];
                while (*op) {
                    if (*op == e) { *op = e->next_out; break; }
                    op = &(*op)->next_out;
                }
                free_nat_port(e->nat_port);
                free(e);
            } else {
                pp = &e->next_in;
            }
        }
    }
}

// Checksum
static uint16_t ip_checksum(const uint16_t *buf, int len) {
    uint32_t sum = 0;
    for (; len > 1; len -= 2) sum += *buf++;
    if (len) sum += *(const uint8_t *)buf;
    while (sum >> 16) sum = (sum & 0xffff) + (sum >> 16);
    return ~sum;
}

static uint16_t tcp_udp_checksum(const struct ip *ip, const uint8_t *hdr, int hdrlen, int is_tcp) {
    uint32_t sum = 0;
    // Pseudo header
    uint16_t buf[6] = {
        ip->ip_src.s_addr >> 16, ip->ip_src.s_addr & 0xffff,
        ip->ip_dst.s_addr >> 16, ip->ip_dst.s_addr & 0xffff,
        htons(is_tcp ? IPPROTO_TCP : IPPROTO_UDP),
        htons(hdrlen)
    };
    for (int i = 0; i < 6; i++) sum += buf[i];
    for (int i = 0; i < hdrlen; i += 2) {
        uint16_t w;
        if (i + 1 < hdrlen) w = (hdr[i] << 8) | hdr[i+1];
        else w = hdr[i] << 8;
        sum += w;
    }
    while (sum >> 16) sum = (sum & 0xffff) + (sum >> 16);
    return (sum == 0xffff) ? 0 : ~sum;
}

// TCP MSS clamping
#define TARGET_MSS 1360

static void clamp_tcp_mss(uint8_t *tcp, int tcp_len) {
    int hdrlen = (tcp[12] >> 4) * 4;
    if (hdrlen <= 20 || hdrlen > tcp_len) return;
    int optlen = hdrlen - 20;
    uint8_t *opt = tcp + 20;
    for (int i = 0; i < optlen - 1; ) {
        int kind = opt[i];
        if (kind == 0) break;
        if (kind == 1) { i++; continue; }
        if (i + 1 >= optlen) break;
        int len = opt[i+1];
        if (len < 2 || i + len > optlen) break;
        if (kind == 2 && len == 4) {
            uint16_t mss = (opt[i+2] << 8) | opt[i+3];
            if (mss > TARGET_MSS) {
                opt[i+2] = (TARGET_MSS >> 8) & 0xff;
                opt[i+3] = TARGET_MSS & 0xff;
            }
            break;
        }
        i += len;
    }
}

// Interface info
struct if_info {
    uint32_t ip;
    uint8_t mac[6];
    int has_mac;
};

static int get_if_info(const char *name, struct if_info *info, int get_mac_ioctl) {
    memset(info, 0, sizeof(*info));
    struct ifaddrs *ifa0 = NULL;
    if (getifaddrs(&ifa0) < 0) return -1;
    for (struct ifaddrs *i = ifa0; i; i = i->ifa_next) {
        if (strcmp(i->ifa_name, name) != 0) continue;
        if (i->ifa_addr->sa_family == AF_INET) {
            struct sockaddr_in *sin = (struct sockaddr_in *)i->ifa_addr;
            info->ip = sin->sin_addr.s_addr;
        }
        if (i->ifa_addr->sa_family == AF_LINK) {
            struct sockaddr_dl *sdl = (struct sockaddr_dl *)i->ifa_addr;
            if (sdl->sdl_alen == 6) {
                memcpy(info->mac, LLADDR(sdl), 6);
                info->has_mac = 1;
            }
        }
    }
    freeifaddrs(ifa0);
    // On bridge interfaces, getifaddrs may return a member's MAC instead of the bridge's own.
    // Use ioctl(SIOCGIFLLADDR) for a more reliable MAC if requested.
    if (get_mac_ioctl && info->has_mac) {
        int s = socket(AF_INET, SOCK_DGRAM, 0);
        if (s >= 0) {
            struct ifreq ifr;
            memset(&ifr, 0, sizeof(ifr));
            strncpy(ifr.ifr_name, name, sizeof(ifr.ifr_name) - 1);
            // Try to get the real MAC via ioctl
            struct sockaddr_dl sdl;
            memset(&sdl, 0, sizeof(sdl));
            ifr.ifr_addr.sa_family = AF_LINK;
            ifr.ifr_addr.sa_len = sizeof(sdl);
            if (ioctl(s, SIOCGIFMAC, &ifr) >= 0) {
                struct sockaddr_dl *sdlp = (struct sockaddr_dl *)&ifr.ifr_addr;
                if (sdlp->sdl_alen == 6) {
                    memcpy(info->mac, LLADDR(sdlp), 6);
                }
            }
            close(s);
        }
    }
    return (info->ip != 0) ? 0 : -1;
}

// Auto-detect VPN utun interface
static char utun_ifname[IFNAMSIZ];
static void make_utun_name(char *buf, int n) {
    static const unsigned char _u[] = S_UTUN;
    char ustr[8];
    for (int i = 0; i < 4; i++) ustr[i] = _u[i] ^ 0xAA;
    ustr[4] = 0;
    snprintf(buf, 16, "%s%d", ustr, n);
}
static int find_utun(void) {
    struct ifaddrs *ifa0 = NULL;
    if (getifaddrs(&ifa0) < 0) return -1;
    for (int u = 0; u <= 9; u++) {
        char name[16];
        make_utun_name(name, u);
        uint32_t ip4 = 0;
        for (struct ifaddrs *i = ifa0; i; i = i->ifa_next) {
            if (strcmp(i->ifa_name, name) != 0) continue;
            if (i->ifa_addr->sa_family == AF_INET) {
                struct sockaddr_in *sin = (struct sockaddr_in *)i->ifa_addr;
                ip4 = sin->sin_addr.s_addr;
                break;
            }
        }
        if (ip4) {
            strncpy(utun_ifname, name, sizeof(utun_ifname) - 1);
            freeifaddrs(ifa0);
            return 0;
        }
    }
    freeifaddrs(ifa0);
    return -1;
}

// Forward declarations for packet handlers
static void process_ether_packet(uint8_t *pkt, int len);
static void process_null_packet(uint8_t *pkt, int len);
static void process_raw_packet(uint8_t *pkt, int len);

// BPF helpers
struct bpf_handle {
    int fd;
    int dlt;
    int snaplen;
    int blen;
    uint8_t *buf;
    char ifname[IFNAMSIZ];
    int valid;
    time_t last_retry;
};

static int open_bpf(struct bpf_handle *h, const char *ifname) {
    memset(h, 0, sizeof(*h));
    h->fd = -1;
    strncpy(h->ifname, ifname, sizeof(h->ifname) - 1);

    for (int i = 0; i < 16; i++) {
        char path[32];
        snprintf(path, sizeof(path), "/dev/bpf%d", i);
        h->fd = open(path, O_RDWR);
        if (h->fd >= 0) break;
    }
    if (h->fd < 0) { perror("open bpf"); return -1; }

    if (ioctl(h->fd, BIOCGBLEN, &h->blen) < 0) { perror("BIOCGBLEN"); close(h->fd); h->fd = -1; return -1; }

    struct ifreq ifr;
    memset(&ifr, 0, sizeof(ifr));
    strncpy(ifr.ifr_name, ifname, sizeof(ifr.ifr_name) - 1);
    if (ioctl(h->fd, BIOCSETIF, &ifr) < 0) { perror("BIOCSETIF"); close(h->fd); h->fd = -1; return -1; }

    if (ioctl(h->fd, BIOCGDLT, &h->dlt) < 0) { perror("BIOCGDLT"); close(h->fd); h->fd = -1; return -1; }

    int imm = 1;
    if (ioctl(h->fd, BIOCIMMEDIATE, &imm) < 0) { perror("BIOCIMMEDIATE"); close(h->fd); h->fd = -1; return -1; }

    int promisc = 1;
    ioctl(h->fd, BIOCPROMISC, &promisc);

    h->buf = malloc(h->blen + 64);
    h->snaplen = h->blen;
    h->valid = 1;

    fprintf(stderr, "BPF %s: fd=%d dlt=%d blen=%d\n", ifname, h->fd, h->dlt, h->blen);
    return 0;
}

static void bpf_close(struct bpf_handle *h);

static int bpf_read(struct bpf_handle *h) {
    if (!h->valid) return -1;
    int n = read(h->fd, h->buf, h->blen);
    if (n <= 0) {
        if (n < 0 && errno != EINTR) {
            fprintf(stderr, "BPF_ERR: fd=%d n=%d errno=%d\n", h->fd, n, errno);
            if (errno == ENXIO) bpf_close(h);
        }
        return n;
    }
    int off = 0;
    while (off + (int)sizeof(struct bpf_hdr) <= n) {
        struct bpf_hdr *bh = (struct bpf_hdr *)(h->buf + off);
        if (bh->bh_hdrlen < (int)sizeof(struct bpf_hdr) || bh->bh_hdrlen > 64) break;
        if (off + bh->bh_hdrlen + bh->bh_caplen > n) break;
        uint8_t *pkt = (uint8_t *)(h->buf + off + bh->bh_hdrlen);
        int pktlen = bh->bh_caplen;

        if (h->dlt == DLT_EN10MB) {
            process_ether_packet(pkt, pktlen);
        } else if (h->dlt == DLT_NULL) {
            process_null_packet(pkt, pktlen);
        } else if (h->dlt == DLT_RAW) {
            process_raw_packet(pkt, pktlen);
        }

        off += BPF_WORDALIGN(bh->bh_hdrlen + bh->bh_caplen);
    }
    return n;
}

static int bpf_write_ether(struct bpf_handle *h, const uint8_t *dst_mac,
                            const uint8_t *src_mac, uint16_t ether_type,
                            const uint8_t *ip_pkt, int ip_len) {
    uint8_t buf[1600];
    if (14 + ip_len > (int)sizeof(buf)) return -1;
    memcpy(buf, dst_mac, 6);
    memcpy(buf + 6, src_mac, 6);
    buf[12] = ether_type >> 8;
    buf[13] = ether_type & 0xff;
    memcpy(buf + 14, ip_pkt, ip_len);
    int total = 14 + ip_len;
    int ret = (int)write(h->fd, buf, total);
    if (ret < 0) fprintf(stderr, "WRITE_ERR: fd=%d ret=%d errno=%d\n", h->fd, ret, errno);
    return ret;
}

static int bpf_write_null(struct bpf_handle *h, uint32_t af, const uint8_t *ip_pkt, int ip_len) {
    uint8_t buf[1600];
    if (4 + ip_len > (int)sizeof(buf)) return -1;
    uint32_t af_net = htonl(af);
    memcpy(buf, &af_net, 4);
    memcpy(buf + 4, ip_pkt, ip_len);
    int total = 4 + ip_len;
    return (int)write(h->fd, buf, total);
}

static int bpf_write_raw(struct bpf_handle *h, const uint8_t *ip_pkt, int ip_len) {
    if (ip_len > 1600) return -1;
    return (int)write(h->fd, ip_pkt, ip_len);
}

static void bpf_close(struct bpf_handle *h) {
    if (h->fd >= 0) {
        close(h->fd);
        h->fd = -1;
    }
    h->valid = 0;
}

static int bpf_reopen(struct bpf_handle *h) {
    time_t now = time(NULL);
    if (now - h->last_retry < 3) return -1;
    h->last_retry = now;

    if (h->fd >= 0) close(h->fd);
    h->fd = -1;
    h->valid = 0;

    for (int i = 0; i < 16; i++) {
        char path[32];
        snprintf(path, sizeof(path), "/dev/bpf%d", i);
        h->fd = open(path, O_RDWR);
        if (h->fd >= 0) break;
    }
    if (h->fd < 0) return -1;

    if (ioctl(h->fd, BIOCGBLEN, &h->blen) < 0) { close(h->fd); h->fd = -1; return -1; }

    struct ifreq ifr;
    memset(&ifr, 0, sizeof(ifr));
    strncpy(ifr.ifr_name, h->ifname, sizeof(ifr.ifr_name) - 1);
    if (ioctl(h->fd, BIOCSETIF, &ifr) < 0) { close(h->fd); h->fd = -1; return -1; }

    if (ioctl(h->fd, BIOCGDLT, &h->dlt) < 0) { close(h->fd); h->fd = -1; return -1; }

    int imm = 1;
    ioctl(h->fd, BIOCIMMEDIATE, &imm);

    int promisc = 1;
    ioctl(h->fd, BIOCPROMISC, &promisc);

    if (!h->buf) h->buf = malloc(h->blen + 64);
    h->snaplen = h->blen;
    h->valid = 1;

    fprintf(stderr, "BPF REOPEN %s: fd=%d dlt=%d blen=%d\n", h->ifname, h->fd, h->dlt, h->blen);
    return 0;
}

// Globals
static struct bpf_handle bpf_bridge, bpf_utun;
static struct if_info bridge_info, utun_info;
static volatile int g_running = 1;
static int g_wake_fds[2];
static void handle_signal(int sig) {
    (void)sig;
    g_running = 0;
    uint8_t c = 1;
    write(g_wake_fds[1], &c, 1);
}

// Process outbound packet from bridge100
static int g_pkt_count = 0;

static void process_ether_packet(uint8_t *pkt, int len) {
    g_pkt_count++;
    if (len < 14 + (int)sizeof(struct ip)) return;
    struct ether_header *eh = (struct ether_header *)pkt;
    if (ntohs(eh->ether_type) != ETHERTYPE_IP) return;

    if (!bridge_info.has_mac) {
        memcpy(bridge_info.mac, eh->ether_dhost, 6);
        bridge_info.has_mac = 1;
    }

    struct ip *ip = (struct ip *)(pkt + 14);
    int ip_hlen = ip->ip_hl << 2;
    if (len < 14 + ip_hlen || ip->ip_v != 4) return;

    if (ip->ip_p != IPPROTO_TCP && ip->ip_p != IPPROTO_UDP && ip->ip_p != IPPROTO_ICMP) return;

    uint16_t src_port = 0, dst_port = 0;
    uint8_t *l4hdr;
    int l4len;

    if (ip->ip_p == IPPROTO_TCP) {
        if (len < 14 + ip_hlen + (int)sizeof(struct tcphdr)) return;
        struct tcphdr *tcp = (struct tcphdr *)((uint8_t *)ip + ip_hlen);
        src_port = ntohs(tcp->th_sport);
        dst_port = ntohs(tcp->th_dport);
        l4hdr = (uint8_t *)tcp;
        l4len = ntohs(ip->ip_len) - ip_hlen;
    } else if (ip->ip_p == IPPROTO_UDP) {
        if (len < 14 + ip_hlen + (int)sizeof(struct udphdr)) return;
        struct udphdr *udp = (struct udphdr *)((uint8_t *)ip + ip_hlen);
        src_port = ntohs(udp->uh_sport);
        dst_port = ntohs(udp->uh_dport);
        l4hdr = (uint8_t *)udp;
        l4len = ntohs(ip->ip_len) - ip_hlen;
    } else {
        src_port = 0; dst_port = 0;
        l4hdr = (uint8_t *)ip + ip_hlen;
        l4len = ntohs(ip->ip_len) - ip_hlen;
    }

    uint32_t client_ip = ip->ip_src.s_addr;
    uint32_t dst = ip->ip_dst.s_addr;

    uint32_t bnet = bridge_info.ip & htonl(0xfffffff0);
    uint32_t bmask = htonl(0xfffffff0);
    if ((client_ip & bmask) != bnet) return;
    if ((dst & bmask) == bnet) return;
    if (utun_info.ip == 0) return;

    uint16_t nat_port;
    int found = 0;

    pthread_mutex_lock(&nat_lock);
    struct nat_entry *ne = nat_lookup_outbound(client_ip, src_port, dst, dst_port, ip->ip_p);
    if (!ne) {
        ne = nat_add(client_ip, src_port, dst, dst_port, ip->ip_p, utun_info.ip, eh->ether_shost);
    }
    if (ne) {
        found = 1;
        nat_port = ne->nat_port;
        ne->last_seen = time(NULL);

        if (ip->ip_p == IPPROTO_TCP) {
            struct tcphdr *tcp = (struct tcphdr *)l4hdr;
            ne->tcp_state |= tcp->th_flags & (TH_FIN | TH_RST);
            if (tcp->th_flags & TH_SYN) clamp_tcp_mss((uint8_t *)tcp, l4len);
        }
    }
    pthread_mutex_unlock(&nat_lock);

    if (!found) return;

    // Rewrite source IP and port
    ip->ip_src.s_addr = utun_info.ip;
    if (ip->ip_p == IPPROTO_TCP) {
        ((struct tcphdr *)l4hdr)->th_sport = htons(nat_port);
    } else if (ip->ip_p == IPPROTO_UDP) {
        ((struct udphdr *)l4hdr)->uh_sport = htons(nat_port);
    }

    ip->ip_sum = 0;
    ip->ip_sum = ip_checksum((uint16_t *)ip, ip_hlen);

    if (ip->ip_p == IPPROTO_TCP) {
        ((struct tcphdr *)l4hdr)->th_sum = 0;
        ((struct tcphdr *)l4hdr)->th_sum = tcp_udp_checksum(ip, l4hdr, l4len, 1);
    } else if (ip->ip_p == IPPROTO_UDP) {
        struct udphdr *uh = (struct udphdr *)l4hdr;
        uh->uh_sum = 0;
        uh->uh_sum = tcp_udp_checksum(ip, l4hdr, l4len, 0);
    }

    if (bpf_utun.valid)
        bpf_write_raw(&bpf_utun, (uint8_t *)ip, ntohs(ip->ip_len));
}

// Process inbound packet from utun5
static void process_ip_packet(uint8_t *pkt, int len, int skip) {
    if (len < skip + (int)sizeof(struct ip)) return;

    struct ip *ip = (struct ip *)(pkt + skip);
    int ip_hlen = ip->ip_hl << 2;
    if (len < skip + ip_hlen || ip->ip_v != 4) return;

    if (ip->ip_p != IPPROTO_TCP && ip->ip_p != IPPROTO_UDP && ip->ip_p != IPPROTO_ICMP) return;

    uint16_t dst_port = 0;
    uint8_t *l4hdr;
    int l4len;

    if (ip->ip_p == IPPROTO_TCP) {
        if (len < skip + ip_hlen + (int)sizeof(struct tcphdr)) return;
        struct tcphdr *tcp = (struct tcphdr *)((uint8_t *)ip + ip_hlen);
        dst_port = ntohs(tcp->th_dport);
        l4hdr = (uint8_t *)tcp;
        l4len = ntohs(ip->ip_len) - ip_hlen;
    } else if (ip->ip_p == IPPROTO_UDP) {
        if (len < skip + ip_hlen + (int)sizeof(struct udphdr)) return;
        struct udphdr *udp = (struct udphdr *)((uint8_t *)ip + ip_hlen);
        dst_port = ntohs(udp->uh_dport);
        l4hdr = (uint8_t *)udp;
        l4len = ntohs(ip->ip_len) - ip_hlen;
    } else {
        dst_port = 0;
        l4hdr = (uint8_t *)ip + ip_hlen;
        l4len = ntohs(ip->ip_len) - ip_hlen;
    }

    uint32_t nat_ip = ip->ip_dst.s_addr;

    // Copy NAT entry data while locked
    uint32_t client_ip = 0;
    uint16_t client_port = 0;
    uint8_t client_mac[6];
    int found = 0;

    pthread_mutex_lock(&nat_lock);
    struct nat_entry *ne = nat_lookup_inbound(nat_ip, dst_port, ip->ip_p);
    if (ne) {
        found = 1;
        client_ip = ne->client_ip;
        client_port = ne->client_port;
        memcpy(client_mac, ne->client_mac, 6);
        ne->last_seen = time(NULL);

        if (ip->ip_p == IPPROTO_TCP) {
            struct tcphdr *tcp = (struct tcphdr *)l4hdr;
            ne->tcp_state |= tcp->th_flags & (TH_FIN | TH_RST);
            if (tcp->th_flags & TH_SYN) clamp_tcp_mss((uint8_t *)tcp, l4len);
        }
    }
    pthread_mutex_unlock(&nat_lock);

    if (!found) return;

    // Rewrite destination
    ip->ip_dst.s_addr = client_ip;
    if (ip->ip_p == IPPROTO_TCP) {
        ((struct tcphdr *)l4hdr)->th_dport = htons(client_port);
    } else if (ip->ip_p == IPPROTO_UDP) {
        ((struct udphdr *)l4hdr)->uh_dport = htons(client_port);
    }

    ip->ip_sum = 0;
    ip->ip_sum = ip_checksum((uint16_t *)ip, ip_hlen);

    if (ip->ip_p == IPPROTO_TCP) {
        ((struct tcphdr *)l4hdr)->th_sum = 0;
        ((struct tcphdr *)l4hdr)->th_sum = tcp_udp_checksum(ip, l4hdr, l4len, 1);
    } else if (ip->ip_p == IPPROTO_UDP) {
        struct udphdr *uh = (struct udphdr *)l4hdr;
        uh->uh_sum = 0;
        uh->uh_sum = tcp_udp_checksum(ip, l4hdr, l4len, 0);
    }

    int wlen = ntohs(ip->ip_len);

    if (bpf_bridge.valid && bridge_info.has_mac) {
        int retb = bpf_write_ether(&bpf_bridge, client_mac, bridge_info.mac,
                                  ETHERTYPE_IP, (uint8_t *)ip, wlen);
        if (retb < 0) fprintf(stderr, "WROTE_BRIDGE: ret=%d errno=%d\n", retb, errno);
    }
}

static void process_null_packet(uint8_t *pkt, int len) {
    if (len < 4) return;
    uint32_t af;
    memcpy(&af, pkt, 4);
    af = ntohl(af);
    if (af != AF_INET) return;
    process_ip_packet(pkt, len, 4);
}

static void process_raw_packet(uint8_t *pkt, int len) {
    process_ip_packet(pkt, len, 0);
}

// Cleanup thread
static void *cleanup_thread(void *arg) {
    (void)arg;
    int state;
    while (g_running) {
        struct timeval tv = { 5, 0 };
        fd_set rfds;
        FD_ZERO(&rfds);
        FD_SET(g_wake_fds[0], &rfds);
        int ret = select(g_wake_fds[0] + 1, &rfds, NULL, NULL, &tv);
        if (ret > 0) {
            uint8_t c;
            read(g_wake_fds[0], &c, 1);
            break;
        }
        pthread_setcancelstate(PTHREAD_CANCEL_DISABLE, &state);
        pthread_mutex_lock(&nat_lock);
        nat_cleanup();
        pthread_mutex_unlock(&nat_lock);
        pthread_setcancelstate(PTHREAD_CANCEL_ENABLE, &state);
    }
    return NULL;
}

int main(int argc, char **argv) {
    anti_debug();
    signal(SIGINT, handle_signal);
    signal(SIGTERM, handle_signal);

    fprintf(stderr, "VPNTether NAT Relay v2.0 starting...\n");

    // Get bridge info (required)
    if (get_if_info(BRIDGE, &bridge_info, 1) < 0) {
        fprintf(stderr, "bridge100 not available, retrying for 10s...\n");
        for (int i = 0; i < 10; i++) {
            sleep(1);
            if (get_if_info(BRIDGE, &bridge_info, 1) >= 0) break;
        }
        if (bridge_info.ip == 0) {
            fprintf(stderr, "Failed to get bridge100 info (is hotspot on?)\n");
            return 1;
        }
    }

    // Detect VPN utun interface
    memset(&utun_info, 0, sizeof(utun_info));
    utun_ifname[0] = 0;
    int utun_ready = (find_utun() >= 0 && get_if_info(utun_ifname, &utun_info, 0) >= 0);
    if (!utun_ready)
        fprintf(stderr, "VPN utun not available, will retry in main loop...\n");

    char ipbuf[64];
    inet_ntop(AF_INET, &bridge_info.ip, ipbuf, sizeof(ipbuf));
    fprintf(stderr, "bridge100: IP=%s MAC=%02x:%02x:%02x:%02x:%02x:%02x\n", ipbuf,
            bridge_info.mac[0], bridge_info.mac[1], bridge_info.mac[2],
            bridge_info.mac[3], bridge_info.mac[4], bridge_info.mac[5]);
    if (utun_ready) {
        inet_ntop(AF_INET, &utun_info.ip, ipbuf, sizeof(ipbuf));
        fprintf(stderr, "%s: IP=%s\n", utun_ifname, ipbuf);
    }

    // Open BPF
    if (open_bpf(&bpf_bridge, BRIDGE) < 0) return 1;
    if (utun_ready)
        open_bpf(&bpf_utun, utun_ifname); // may fail, that's ok

    // Create wake pipe
    pipe(g_wake_fds);

    // Start cleanup thread
    pthread_t cleaner;
    pthread_create(&cleaner, NULL, cleanup_thread, NULL);

    fprintf(stderr, "NAT Relay running (PID %d)\n", getpid());

    int stat_count = 0;
    long long bridge_bytes = 0, utun_bytes = 0;
    int retry_counter = 0;

    // Main loop
    while (g_running) {
        // Try to reopen broken handles
        if (!bpf_bridge.valid) bpf_reopen(&bpf_bridge);
        if (!bpf_utun.valid) bpf_reopen(&bpf_utun);

        // Periodically check if VPN utun appeared
        if (!utun_ready && (retry_counter % 10 == 0)) {
            if (find_utun() >= 0 && get_if_info(utun_ifname, &utun_info, 0) >= 0) {
                utun_ready = 1;
                inet_ntop(AF_INET, &utun_info.ip, ipbuf, sizeof(ipbuf));
                fprintf(stderr, "%s: now available IP=%s\n", utun_ifname, ipbuf);
                if (!bpf_utun.valid) {
                    strncpy(bpf_utun.ifname, utun_ifname, sizeof(bpf_utun.ifname) - 1);
                    bpf_reopen(&bpf_utun);
                }
            }
        }

        fd_set rfds;
        FD_ZERO(&rfds);
        if (bpf_bridge.valid) FD_SET(bpf_bridge.fd, &rfds);
        if (bpf_utun.valid) FD_SET(bpf_utun.fd, &rfds);
        FD_SET(g_wake_fds[0], &rfds);

        int maxfd = g_wake_fds[0];
        if (bpf_bridge.valid && bpf_bridge.fd > maxfd) maxfd = bpf_bridge.fd;
        if (bpf_utun.valid && bpf_utun.fd > maxfd) maxfd = bpf_utun.fd;

        struct timeval tv = { 5, 0 };
        int ret = select(maxfd + 1, &rfds, NULL, NULL, &tv);
        if (ret < 0) {
            if (errno == EINTR) continue;
            break;
        }

        if (FD_ISSET(g_wake_fds[0], &rfds)) {
            uint8_t c;
            read(g_wake_fds[0], &c, 1);
            break;
        }
        if (bpf_bridge.valid && FD_ISSET(bpf_bridge.fd, &rfds)) {
            int r = bpf_read(&bpf_bridge);
            if (r > 0) bridge_bytes += r;
        }
        if (bpf_utun.valid && FD_ISSET(bpf_utun.fd, &rfds)) {
            int r = bpf_read(&bpf_utun);
            if (r > 0) utun_bytes += r;
        }

        retry_counter++;
        stat_count++;
        if (stat_count >= 600) {
            stat_count = 0;
            fprintf(stderr, "STAT: bridge=%lld utun=%lld pkt=%d utun_ready=%d\n",
                    bridge_bytes, utun_bytes, g_pkt_count, utun_ready);
        }
    }

    fprintf(stderr, "Shutting down...\n");
    g_running = 0;
    uint8_t wc = 1;
    write(g_wake_fds[1], &wc, 1);
    pthread_cancel(cleaner);
    pthread_join(cleaner, NULL);
    close(g_wake_fds[0]);
    close(g_wake_fds[1]);
    if (bpf_bridge.fd >= 0) close(bpf_bridge.fd);
    if (bpf_utun.fd >= 0) close(bpf_utun.fd);
    free(bpf_bridge.buf);
    free(bpf_utun.buf);

    for (int i = 0; i < NAT_HASH_SZ; i++) {
        struct nat_entry *e = nat_table_in[i];
        while (e) {
            struct nat_entry *next = e->next_in;
            free_nat_port(e->nat_port);
            free(e);
            e = next;
        }
    }

    fprintf(stderr, "NAT Relay stopped.\n");
    return 0;
}
