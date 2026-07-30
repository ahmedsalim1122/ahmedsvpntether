#!/var/jb/usr/bin/bash
# vpntether_manager - VPNTether NAT Relay Daemon (SILEO EDITION - needs per-device license)
export PATH=/var/jb/usr/bin:/var/jb/usr/sbin:/var/jb/sbin:/var/jb/bin:/usr/bin:/bin:/usr/sbin:/sbin

NAT_BIN="/var/jb/usr/libexec/vpntether/vpntether_nat"
LOGDIR="/var/log/vpntether"
LOG="$LOGDIR/daemon.log"
LICENSE_FILE="/var/db/vpntether_license"
CLIENTS_FILE="/var/db/vpntether_clients"

mkdir -p "$LOGDIR"
log() { echo "$(date) $*" >> "$LOG"; }

# Per-device license check: SHA256("VPNTetherSecret2026" + device_uuid) == stored_license_key
check_license() {
    local uuid
    uuid=$(sysctl kern.uuid 2>/dev/null | cut -d' ' -f2)
    [ -z "$uuid" ] && return 1
    local key
    key=$(cat "$LICENSE_FILE" 2>/dev/null)
    [ -z "$key" ] && return 1
    local expected
    uuid=$(echo "$uuid" | tr '[:upper:]' '[:lower:]')
    expected=$(echo -n "VPNTetherSecret2026${uuid}" | sha256sum | cut -d' ' -f1 | head -c 32)
    [ "$key" = "$expected" ] && return 0 || return 1
}

activate_license() {
    local key="$1"
    [ -z "$key" ] && { echo "Usage: vpntether_manager activate <license-key>"; return 1; }
    local uuid
    uuid=$(sysctl kern.uuid 2>/dev/null | cut -d' ' -f2)
    [ -z "$uuid" ] && { echo "Cannot get device UUID"; return 1; }
    local expected
    uuid=$(echo "$uuid" | tr '[:upper:]' '[:lower:]')
    expected=$(echo -n "VPNTetherSecret2026${uuid}" | sha256sum | cut -d' ' -f1 | head -c 32)
    if [ "$key" != "$expected" ]; then
        echo "INVALID LICENSE KEY for this device"
        return 1
    fi
    echo "$key" > "$LICENSE_FILE"
    chmod 600 "$LICENSE_FILE"
    log "License activated"
    echo "License activated!"
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
    if check_license; then echo "License: ACTIVATED"; else echo "License: NOT ACTIVATED"; fi
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

case "$1" in
    activate)
        activate_license "$2"; exit $? ;;
    status)
        show_status ;;
    *)
        log "=== vpntether_manager (SILEO) started ==="
        if ! check_license; then
            log "NO VALID LICENSE - relay won't start"
            log "Use: vpntether_manager activate <license-key>"
            echo "NO VALID LICENSE - relay won't start" >> "$LOG"
            # Keep running to show status
            while true; do
                count_clients
                sleep 30
            done
            exit 1
        fi
        log "License valid, starting relay..."
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
