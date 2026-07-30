#!/var/jb/usr/bin/bash
# vpntether_manager - VPNTether NAT Relay Daemon (HAVOC EDITION - no license needed)
export PATH=/var/jb/usr/bin:/var/jb/usr/sbin:/var/jb/sbin:/var/jb/bin:/usr/bin:/bin:/usr/sbin:/sbin

NAT_BIN="/var/jb/usr/libexec/vpntether/vpntether_nat"
LOGDIR="/var/log/vpntether"
LOG="$LOGDIR/daemon.log"
CLIENTS_FILE="/var/db/vpntether_clients"

mkdir -p "$LOGDIR"
log() { echo "$(date) $*" >> "$LOG"; }

ensure_license() {
    [ -s "$LICENSE_FILE" ] || echo "HAVOC" > "$LICENSE_FILE"
}

tune_network() {
    sysctl -w net.inet.ip.forwarding=1 >/dev/null 2>&1
    sysctl -w net.inet.ip.check_interface=0 >/dev/null 2>&1
    sysctl -w net.inet.tcp.sendspace=262144 >/dev/null 2>&1
    sysctl -w net.inet.tcp.recvspace=262144 >/dev/null 2>&1
    sysctl -w net.inet.tcp.mssdflt=1410 >/dev/null 2>&1
    sysctl -w net.inet.tcp.win_scale_factor=4 >/dev/null 2>&1
}

count_clients() {
    local c
    c=$(arp -a 2>/dev/null | grep -c '172.20.10')
    echo "$c" > "$CLIENTS_FILE"
}

show_status() {
    echo "=== VPNTether Status ==="
    echo "License: ACTIVATED (HAVOC)"
    if ps -axc 2>/dev/null | grep -q vpntether_nat >/dev/null 2>&1; then
        echo "Relay: RUNNING"
    else
        echo "Relay: STOPPED"
    fi
    local ip=""
    for u in 0 1 2 3 4 5 6 7 8 9; do
        ip=$(ifconfig "utun$u" 2>/dev/null | grep "inet " | tr -s ' ' | cut -d' ' -f3)
        [ -n "$ip" ] && echo "VPN utun: utun$u ($ip)" && break
    done
    [ -z "$ip" ] && echo "VPN utun: NOT FOUND"
    echo "Hotspot: $(ifconfig bridge100 2>/dev/null | grep 'inet ' | tr -s ' ' | cut -d' ' -f3)"
    count_clients
    echo "Clients: $(cat $CLIENTS_FILE 2>/dev/null || echo 0)"
}

LICENSE_FILE="/var/db/vpntether_license"

case "$1" in
    activate)
        echo "HAVOC" > "$LICENSE_FILE"
        echo "License activated!" ;;
    status)
        show_status ;;
    *)
        log "=== vpntether_manager (HAVOC) started ==="
        ensure_license
        tune_network
        while true; do
            if ! ps -axc 2>/dev/null | grep -q vpntether_nat >/dev/null 2>&1; then
                log "Starting vpntether_nat..."
                $NAT_BIN &
                sleep 2
            fi
            count_clients
            sleep 10
        done ;;
esac
