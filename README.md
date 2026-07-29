# ahmeds-vpntether

Route all hotspot traffic through VPN tunnel on jailbroken iPhone.

## SILEO Repo

Add this URL to Sileo:

```
https://ahmedsalim1122.github.io/ahmedsvpntether/repo/
```

The **SILEO** package requires a per-device license key. Contact via WhatsApp to purchase.

The **HAVOC** package is distributed separately through the Havoc storefront.

## Files

- `nat_relay.c` — NAT relay binary (XOR-obfuscated strings, anti-tamper)
- `status_check.c` — Status helper (getifaddrs + sysctl, no shell dependency)
- `app/VPNApp.m` — Status display app (UIKit, fork/execve helper)
- `manager_havoc.sh` — Manager daemon (HAVOC edition, no license check)
- `manager_sileo.sh` — Manager daemon (SILEO edition, per-device license)
- `build_final_v2.sh` — Build script (compiles, signs, packages, installs)
- `repo/` — Cydia/Sileo APT repository (Packages.gz + debs)

## License

Per-device SHA256-based license system.
