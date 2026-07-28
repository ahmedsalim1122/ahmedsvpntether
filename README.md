# VPN iOS Tether

<p align="center">
  <img src="flag_iraq.png" alt="Iraq Flag" width="128">
</p>

Route all hotspot traffic through an iPhone VPN tunnel with **zero client-side configuration**.

## What This Does

When you connect to an iPhone's personal hotspot, traffic normally bypasses the VPN and goes directly through cellular data. This tool hooks into the iPhone's `misd` daemon (MobileInternetSharing) to intercept PF (Packet Filter) NAT rules, preventing them from redirecting hotspot traffic away from the VPN.

**Result:** All devices connected to your hotspot automatically route through the VPN tunnel.

## Requirements

- **iPhone 8 Plus** (or similar A11 device) on **iOS 16.x**
- **Jailbroken** with **Dopamine** (rootless)
- **VPN app** (V2Box/NpvTunnel or similar — SNI-based proxy recommended)
- **Personal Hotspot** enabled
- **SSH access** via USB (iproxy + plink/terminal)
- **Windows PC** with PuTTY/plink installed

## How It Works

1. `misd` (MobileInternetSharing) installs PF NAT rules that redirect hotspot traffic (`172.20.10.0/28`) directly to cellular (`pdp_ip0`), bypassing the VPN tunnel (`utun5`)
2. Our hook dylib (`pf_hook.dylib`) intercepts three PF functions:
   - `PFUserBeginRules` - starts PF rule transaction
   - `PFUserAddRule` - adds a PF rule
   - `PFUserCommitRules` - commits PF rules
3. The hooks return success (1) without actually installing the rules
4. Hotspot traffic falls back to the default route, which goes through the VPN tunnel

## Files

```
vpn-ios-tether/
├── README.md              # This file
├── setup.sh               # Automated installer (run on iPhone)
├── deploy.bat             # One-click deploy from Windows
├── src/
│   ├── pf_hook.c          # Main hook dylib source (MSHookFunction + ElleKit)
│   ├── fishhook.c          # Facebook fishhook library (unused in final version)
│   └── fishhook.h          # fishhook header
├── device/
│   └── pfinject_daemon.sh # Injection daemon (monitors misd + MTU watchdog + TCP tuning)
└── ent.plist               # LDID entitlements (for reference)
```

## Installation

### Step 1: Connect to iPhone via SSH

```bash
# Start iproxy (Windows)
C:\path\to\iproxy.exe 2222 22 &

# Connect via plink (use -hostkey to avoid interactive prompt)
plink -P 2222 -pw "1" -hostkey "ssh-ed25519 255 SHA256:HnbhRBFGb0OsGjXDH/DpJZWpDrq5jsQyxzGTJ30MrgI" root@127.0.0.1
```

Default SSH password: `1`

### Step 2: Upload Files to iPhone

```bash
# Using pscp (PuTTY)
pscp -P 2222 -pw "1" -hostkey "ssh-ed25519 255 SHA256:HnbhRBFGb0OsGjXDH/DpJZWpDrq5jsQyxzGTJ30MrgI" src\* root@127.0.0.1:/var/jb/usr/local/libexec/pf_hook/
pscp -P 2222 -pw "1" -hostkey "ssh-ed25519 255 SHA256:HnbhRBFGb0OsGjXDH/DpJZWpDrq5jsQyxzGTJ30MrgI" device\pfinject_daemon.sh root@127.0.0.1:/var/jb/usr/local/libexec/pf_hook/
pscp -P 2222 -pw "1" -hostkey "ssh-ed25519 255 SHA256:HnbhRBFGb0OsGjXDH/DpJZWpDrq5jsQyxzGTJ30MrgI" setup.sh root@127.0.0.1:/var/jb/usr/local/libexec/pf_hook/
```

### Step 3: Run Installer on iPhone

```bash
# SSH into iPhone, then:
export PATH=/var/jb/usr/bin:/var/jb/usr/sbin:/var/jb/sbin:/var/jb/bin:/usr/bin:/bin:/usr/sbin:/sbin
chmod +x /var/jb/usr/local/libexec/pf_hook/setup.sh
bash /var/jb/usr/local/libexec/pf_hook/setup.sh
```

Or run the individual steps:

```bash
# Install ElleKit (hooking framework)
apt-get download ellekit
dpkg -i /var/jb/var/cache/apt/archives/ellekit_*.deb

# Compile the hook dylib
cd /var/jb/usr/local/libexec/pf_hook
clang-16 -dynamiclib -target arm64-apple-ios16.0 \
    -isysroot /var/jb/usr/share/SDKs/iPhoneOS.sdk \
    pf_hook.c -L/var/jb/usr/lib -llellekit -ldl \
    -o pf_hook.dylib
ldid -S pf_hook.dylib

# Start the daemon
nohup /var/jb/usr/bin/bash /var/jb/usr/local/libexec/pf_hook/inject_daemon.sh &
```

### Step 4: Use

1. **Connect VPN** (V2Box/NpvTunnel) on the iPhone
2. **Enable Personal Hotspot** (Settings > Personal Hotspot — turn OFF "Maximize Compatibility" for 5GHz)
3. **Connect your device** to the iPhone's WiFi hotspot
4. **Done!** All traffic routes through VPN

## Usage After First Install

After the first install, the daemon runs automatically after each jailbreak. Simply:

1. Jailbreak with Dopamine
2. Connect VPN
3. Enable Hotspot (5GHz recommended — OFF "Maximize Compatibility")
4. Connect device

The daemon detects when `misd` starts/restarts and injects the hook automatically. It also monitors utun5 MTU every 0.5s and fixes it when the VPN resets it.

## Monitoring

```bash
# Check if hooks are active
cat /var/jb/usr/local/libexec/pf_hook/hook.log

# Watch the injection daemon
tail -f /var/jb/usr/local/libexec/pf_hook/inject_daemon.log

# Verify PF rules are being intercepted (should see HOOKED lines)
grep HOOKED /var/jb/usr/local/libexec/pf_hook/hook.log

# Check bridge100 (hotspot interface)
ifconfig bridge100

# Check VPN tunnel
ifconfig utun5

# Check MTU chain (utun5 should be 1350)
ifconfig utun5 | grep mtu
ifconfig bridge100 | grep mtu
ifconfig pdp_ip0 | grep mtu
```

## Troubleshooting

### No WiFi SSID broadcasting
- Make sure `misd` is running: `ps -eo pid,comm | grep misd`
- Restart it: `launchctl start com.apple.MobileInternetSharing`
- Toggle hotspot OFF/ON in iPhone Settings

### Internet not working on connected device
- Check VPN is connected: `ifconfig utun5`
- Check default route: `netstat -rn | grep default`
- Default route should go through `utun5`, not `pdp_ip0`
- Check utun5 MTU is 1350: `ifconfig utun5 | grep mtu`
- If MTU is 1500, fix it: `ifconfig utun5 mtu 1350`
- Reconnect WiFi on the client device after MTU fix

### Upload not working / 0 Mbps
- This happens when utun5 MTU is 1500 but bridge100 is 1350
- Large packets from client get dropped due to MTU mismatch
- Fix: `ifconfig utun5 mtu 1350` on iPhone, then reconnect WiFi on client
- PMTUD should auto-fix this, but may take a moment

### Hook not injecting
- Check daemon is running: `ps -eo pid,comm | grep inject_daemon`
- Check ElleKit installed: `ls /var/jb/usr/lib/libellekit.dylib`
- Check daemon log: `tail -20 /var/jb/usr/local/libexec/pf_hook/inject_daemon.log`
- Restart daemon: `launchctl kickstart -k system/com.local.pfinject`

### SSH connection keeps dropping
- Restart iproxy: kill and restart `iproxy 2222 22`
- Check utun5 MTU — VPN resetting it can briefly disrupt SSH

### After reboot
1. Re-jailbreak with Dopamine
2. Reconnect SSH (restart iproxy)
3. The daemon auto-starts via LaunchDaemon
4. Connect VPN, enable hotspot
5. `plink` may hang on host key verification after reboot — use `-hostkey` flag

## Network Performance Tuning

The inject daemon automatically applies TCP tuning every 6 seconds. These optimizations improve throughput when tethering through VPN:

| Setting | Default | Tuned | Effect |
|---------|---------|-------|--------|
| `tcp.sendspace` | 128KB | 256KB | Larger send buffer |
| `tcp.recvspace` | 128KB | 256KB | Larger receive buffer |
| `tcp.autosndbufmax` | 4MB | 8MB | Max send buffer |
| `tcp.autorcvbufmax` | 4MB | 8MB | Max receive buffer |
| `tcp.mssdflt` | 512 | 1300 | Segments sized for VPN MTU |
| `tcp.win_scale_factor` | 3 | 4 | Larger TCP windows |
| `tcp.delayed_ack` | 3 | 0 | Removes 40ms latency |
| `tcp.cubic_tcp_friendliness` | 0 | 1 | Better congestion avoidance |
| `tcp.maxseg_unacked` | 8 | 16 | More data per ACK |
| `tcp.pmtud_blackhole_detection` | 1 | 0 | Enables Path MTU Discovery |
| `utun5 MTU` | 1500 | 1350 | Prevents fragmentation (monitored) |

### MTU management

The VPN app (NpvTunnel) resets utun5 MTU to 1500 on every reconnect. The daemon monitors every 0.5s and fixes it to 1350. This is critical because:
- bridge100 stays at 1350 (set once)
- utun5 must match bridge100 to avoid fragmentation
- PMTUD (Path MTU Discovery) handles the WiFi side (client learns the correct MTU)

### Expected speeds (tested)

**Through SNI proxy VPN tethered:**
- **Download:** 20 Mbps
- **Upload:** 33 Mbps
- **Ping:** 191ms (SNI proxy latency)

**Phone direct (through VPN, no tethering):**
- **Download:** 160 Mbps
- **Upload:** ~40 Mbps

The reduction from 160→20 Mbps is due to:
- WiFi relay overhead (half-duplex radio)
- VPN encryption on A11 chip
- TCP processing in kernel network stack
- SNI proxy adds ~191ms latency

**Tips for best speed:**
- Use 5GHz hotspot (turn OFF "Maximize Compatibility")
- Keep connected device close to iPhone
- 5GHz has shorter range than 2.4GHz but higher throughput

## Technical Details

### Why this approach?

- **No pfctl available** on iOS 16 (not in any APT repo, can't compile from source)
- **BPF ioctls broken** on iOS 16.7 (`BIOCSETIF` returns EINVAL)
- **PF raw ioctls dead** on iOS 16.7 (`DIOCSTART`/`DIOCXBEGIN` return ENODEV)
- **PacketFilter.framework** is available for processes with `com.apple.pf.allow` entitlement
- **misd** has the required entitlement and calls PF functions to install NAT rules

### Why MSHookFunction instead of fishhook?

Facebook's fishhook library (GOT/rebinding) hangs on iOS 16 arm64e with chained fixups. ElleKit's `MSHookFunction` (code patching with PAC-compatible trampolines) works reliably.

### Race condition

The daemon must inject the hook **before** `misd` installs PF rules. The inject daemon polls every 0.5 seconds and injects immediately when a new `misd` PID is detected. This usually catches it before PF calls happen.

### Root cause

`misd` installs PF NAT rules in the `com.apple.internet-sharing/base_v4` anchor:
```
nat on pdp_ip0 from 172.20.10.0/28 to any -> (pdp_ip0)
```
This redirects ALL hotspot subnet traffic directly to cellular, bypassing the VPN tunnel entirely. Our hook prevents these rules from being installed.

## Tested On

- iPhone 8 Plus (A11, T8015), iOS 16.7.16, Darwin 22.6.0
- Dopamine jailbreak (rootless)
- V2Box/NpvTunnel VPN app (SNI-based proxy)
- ElleKit 1.1.3
- clang-16 (Procursus toolchain)
- Android phone as WiFi client (tested)
