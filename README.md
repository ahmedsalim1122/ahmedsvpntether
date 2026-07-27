# AhmedVPN Tether

Route your iPhone hotspot traffic through your VPN automatically. Zero client-side configuration required.

## Features
- **Zero Config** - Connected devices automatically route through VPN
- **MTU Auto-Fix** - Maintains optimal utun MTU for maximum speed
- **TCP Tuning** - Optimizes buffers, MSS, and congestion algorithms
- **PF Hook** - Blocks NetworkExtension PF NAT bypass using ElleKit
- **Settings UI** - Toggle on/off from Settings app
- **Persistent** - LaunchDaemon auto-starts after every jailbreak
- **License System** - Built-in activation for paid distribution

## Requirements
- iOS 16.0+
- Jailbroken with Dopamine (rootless)
- ElleKit installed
- Any VPN app (V2Box, NpvTunnel, etc.)

## Installation

### Via Sileo
1. Open Sileo → **Sources** → **+**
2. Add: `https://ahmedsalim1122.github.io/ahmedsvpntether-repo`
3. Search for **"AhmedVPN Tether"**
4. Install and respring
5. Go to **Settings → AhmedVPN Tether** to activate

### Build from source
```bash
# On device:
bash build_tweak.sh

# Install:
dpkg -i /tmp/com.alhamadany.ahmed.vpntether_1.0.0.deb
```

## Activation
After installing, go to **Settings → AhmedVPN Tether** and enter your license key.

Format: `VPNT-XXXX-XXXX-XXXX`

## How It Works
1. Blocks PF NAT rules in `misd` via ElleKit function hooks
2. Forces utun5 MTU to 1450 (matches pdp_ip0) every 0.5s
3. Applies TCP tuning for optimal throughput
4. All hotspot traffic routes through VPN tunnel automatically

## Speed Results
| Metric | Value |
|--------|-------|
| Download | ~80 Mbps |
| Upload | ~17 Mbps |
| Ping | ~144ms |
| Interface | 2.4GHz WiFi |

## License
Proprietary. All rights reserved.

## Author
**Ahmed Alhamadany** - [GitHub](https://github.com/ahmedsalim1122)
