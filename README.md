# ahmeds-vpntether

Route all hotspot traffic through VPN tunnel on jailbroken iPhone.

## SILEO Repo

Add this URL to Sileo:

```
https://ahmedsalim1122.github.io/ahmedsvpntether/repo/
```

## License System

The **SILEO** package requires a per-device license key tied to the device UUID.

### For Client — How to get your license

1. Install the SILEO deb from the repo above
2. Open the **VPNTether** app on your iPhone
3. Tap the **Activate License** button
4. Send the following to the seller on WhatsApp:
   - Your device UUID (shown in the app, or run `sysctl kern.uuid` in terminal)
   - Your order confirmation
5. Enter the received license key and tap **Activate**

### For Seller — How to generate a license key

Use the `gen_license` script:

**Windows:**
```
gen_license.bat 28E24CE2-BA1C-38B1-AC56-C0BE08A077BC
```

**macOS/Linux:**
```bash
./gen_license.sh 28E24CE2-BA1C-38B1-AC56-C0BE08A077BC
```

**iPhone (SSH):**
```bash
sysctl kern.uuid
# Output: 28E24CE2-BA1C-38B1-AC56-C0BE08A077BC
echo -n "VPNTetherSecret2026$(sysctl kern.uuid | cut -d' ' -f2)" | sha256sum | head -c 32
```

The key is `SHA256("VPNTetherSecret2026" + device_UUID)`, first 32 hex characters.

## HAVOC

The **HAVOC** package is distributed through the Havoc storefront (no license required).

## Files

- `nat_relay.c` — NAT relay binary (XOR-obfuscated strings, anti-tamper)
- `status_check.c` — Status helper (getifaddrs + sysctl, no shell dependency)
- `app/VPNApp.m` — Status display app (UIKit, fork/execve helper)
- `manager_havoc.sh` — Manager daemon (HAVOC edition, no license check)
- `manager_sileo.sh` — Manager daemon (SILEO edition, per-device license)
- `build_final_v2.sh` — Build script (compiles, signs, packages, installs)
- `repo/` — Cydia/Sileo APT repository (Packages.gz + debs)
- `gen_license.bat` — License key generator for Windows
- `gen_license.sh` — License key generator for macOS/Linux
