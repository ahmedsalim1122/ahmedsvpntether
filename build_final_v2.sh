#!/var/jb/usr/bin/bash
set -e
export PATH=/var/jb/usr/bin:/var/jb/usr/sbin:/var/jb/sbin:/var/jb/bin:/usr/bin:/bin:/usr/sbin:/sbin
SDK=/var/jb/usr/share/SDKs/iPhoneOS.sdk

echo "=== 1. Compile vpntether_nat ==="
clang-16 -arch arm64 -O2 -isysroot $SDK /tmp/nat_relay.c -o /tmp/vpntether_nat \
    -L$SDK/usr/lib -F$SDK/System/Library/Frameworks

echo "=== 2. Compile status_check ==="
clang-16 -arch arm64 -O2 -isysroot $SDK /tmp/status_check.c -o /tmp/vpntether_status \
    -L$SDK/usr/lib -F$SDK/System/Library/Frameworks

echo "=== 3. Compile VPNApp ==="
clang-16 -arch arm64 -O2 -isysroot $SDK -framework UIKit -framework Foundation \
    /tmp/VPNApp.m -o /tmp/VPNApp \
    -L$SDK/usr/lib -F$SDK/System/Library/Frameworks

echo "=== 4. Sign all three ==="
ldid -S/tmp/ent.plist /tmp/vpntether_nat
ldid -S/tmp/ent.plist /tmp/vpntether_status
ldid -S/tmp/ent.plist /tmp/VPNApp
ls -la /tmp/vpntether_nat /tmp/vpntether_status /tmp/VPNApp

echo "=== 5. Set up deb directories ==="
# Havoc deb (no license check)
mkdir -p /tmp/deb_havoc/DEBIAN
mkdir -p /tmp/deb_havoc/var/jb/usr/libexec/vpntether
mkdir -p /tmp/deb_havoc/var/jb/Applications/VPNTether.app
mkdir -p /tmp/deb_havoc/var/jb/Library/LaunchDaemons

# Sileo deb (needs per-device license)
mkdir -p /tmp/deb_sileo/DEBIAN
mkdir -p /tmp/deb_sileo/var/jb/usr/libexec/vpntether
mkdir -p /tmp/deb_sileo/var/jb/Applications/VPNTether.app
mkdir -p /tmp/deb_sileo/var/jb/Library/LaunchDaemons
mkdir -p /tmp/deb_sileo/var/jb/usr/bin

echo "=== 6. Copy common files ==="
# Relay binary (same for both)
cp /tmp/vpntether_nat /tmp/deb_havoc/var/jb/usr/libexec/vpntether/vpntether_nat
cp /tmp/vpntether_nat /tmp/deb_sileo/var/jb/usr/libexec/vpntether/vpntether_nat

# Status check binary (same for both)
cp /tmp/vpntether_status /tmp/deb_havoc/var/jb/usr/libexec/vpntether/vpntether_status
cp /tmp/vpntether_status /tmp/deb_sileo/var/jb/usr/libexec/vpntether/vpntether_status

# Manager script (different for each)
cp /tmp/manager_havoc.sh /tmp/deb_havoc/var/jb/usr/libexec/vpntether/vpntether_manager
chmod +x /tmp/deb_havoc/var/jb/usr/libexec/vpntether/vpntether_manager

cp /tmp/manager_sileo.sh /tmp/deb_sileo/var/jb/usr/libexec/vpntether/vpntether_manager
chmod +x /tmp/deb_sileo/var/jb/usr/libexec/vpntether/vpntether_manager

# Symlink for sileo (so user can run vpntether_manager activate)
ln -sf /var/jb/usr/libexec/vpntether/vpntether_manager /tmp/deb_sileo/var/jb/usr/bin/vpntether_manager

echo "=== 7. Copy app files ==="
cp /tmp/VPNApp /tmp/deb_havoc/var/jb/Applications/VPNTether.app/VPNApp
cp /tmp/VPNApp /tmp/deb_sileo/var/jb/Applications/VPNTether.app/VPNApp

# Info.plist
cp /tmp/Info.plist /tmp/deb_havoc/var/jb/Applications/VPNTether.app/Info.plist
cp /tmp/Info.plist /tmp/deb_sileo/var/jb/Applications/VPNTether.app/Info.plist

# App icon (Ishtar Gate)
cp /tmp/ishtar_Icon.png /tmp/deb_havoc/var/jb/Applications/VPNTether.app/Icon.png
cp /tmp/ishtar_Icon@2x.png /tmp/deb_havoc/var/jb/Applications/VPNTether.app/Icon@2x.png
cp /tmp/ishtar_Icon@3x.png /tmp/deb_havoc/var/jb/Applications/VPNTether.app/Icon@3x.png
cp /tmp/ishtar_Icon.png /tmp/deb_sileo/var/jb/Applications/VPNTether.app/Icon.png
cp /tmp/ishtar_Icon@2x.png /tmp/deb_sileo/var/jb/Applications/VPNTether.app/Icon@2x.png
cp /tmp/ishtar_Icon@3x.png /tmp/deb_sileo/var/jb/Applications/VPNTether.app/Icon@3x.png
# App icon alt name
cp /tmp/ishtar_Icon@3x.png /tmp/deb_havoc/var/jb/Applications/VPNTether.app/AppIcon.png
cp /tmp/ishtar_Icon@3x.png /tmp/deb_sileo/var/jb/Applications/VPNTether.app/AppIcon.png
# Flag image for in-app display
cp /tmp/iraq_flag.png /tmp/deb_havoc/var/jb/Applications/VPNTether.app/flag.png
cp /tmp/iraq_flag.png /tmp/deb_sileo/var/jb/Applications/VPNTether.app/flag.png

echo "=== 8. Copy launchd plist ==="
cp /tmp/deb_build/var/jb/Library/LaunchDaemons/com.vpntether.daemon.plist /tmp/deb_havoc/var/jb/Library/LaunchDaemons/
cp /tmp/deb_build/var/jb/Library/LaunchDaemons/com.vpntether.daemon.plist /tmp/deb_sileo/var/jb/Library/LaunchDaemons/

echo "=== 9. Create DEBIAN control files ==="

# Havoc control
cat > /tmp/deb_havoc/DEBIAN/control << 'CTRL'
Package: com.alhamadany.ahmed.vpntether
Name: AhmedVPN Tether (HAVOC)
Version: 2.0.0
Architecture: iphoneos-arm64
Depends: firmware (>= 15.0)
Section: Networking
Maintainer: Ahmed Alhamadany
Description: Full paid version - No license required
 Forces all hotspot traffic through active VPN tunnel.
 .
 Features:
  - Zero-config auto-detect of VPN interface
  - Kernel-bypass NAT for source-filtering VPNs
  - TCP MSS clamping for optimal MTU
  - Full IPv4 NAT (TCP/UDP/ICMP)
  - Status display app with Iraq flag
  - WhatsApp support button
 .
 This HAVOC version does not require a license key.
CTRL

# Havoc postinst
cat > /tmp/deb_havoc/DEBIAN/postinst << 'PINST'
#!/var/jb/usr/bin/bash
export PATH=/var/jb/usr/bin:/var/jb/usr/sbin:/var/jb/sbin:/var/jb/bin:/usr/bin:/bin:/usr/sbin:/sbin
echo "HAVOC" > /var/db/vpntether_license
mkdir -p /var/log/vpntether
uicache -p /var/jb/Applications/VPNTether.app/ 2>/dev/null
launchctl load /var/jb/Library/LaunchDaemons/com.vpntether.daemon.plist 2>/dev/null
echo "AhmedVPN Tether (HAVOC) installed. Relay will auto-start."
PINST
chmod +x /tmp/deb_havoc/DEBIAN/postinst

# Havoc prerm
cat > /tmp/deb_havoc/DEBIAN/prerm << 'PRERM'
#!/var/jb/usr/bin/bash
export PATH=/var/jb/usr/bin:/var/jb/usr/sbin:/var/jb/sbin:/var/jb/bin:/usr/bin:/bin:/usr/sbin:/sbin
launchctl unload /var/jb/Library/LaunchDaemons/com.vpntether.daemon.plist 2>/dev/null
killall vpntether_nat vpntether_manager 2>/dev/null
PRERM
chmod +x /tmp/deb_havoc/DEBIAN/prerm

# Sileo control
cat > /tmp/deb_sileo/DEBIAN/control << 'CTRL'
Package: com.alhamadany.ahmed.vpntether.sileo
Name: AhmedVPN Tether (SILEO)
Version: 2.0.0
Architecture: iphoneos-arm64
Depends: firmware (>= 15.0)
Section: Networking
Maintainer: Ahmed Alhamadany
Description: Per-device license required to activate
 Forces all hotspot traffic through active VPN tunnel.
 .
 INSTALLS FREE - but relay won't run without a license key.
 To activate: vpntether_manager activate <license-key>
 .
 Each license is tied to one device UUID.
 Contact on WhatsApp to purchase.
CTRL

# Sileo postinst
cat > /tmp/deb_sileo/DEBIAN/postinst << 'PINST'
#!/var/jb/usr/bin/bash
export PATH=/var/jb/usr/bin:/var/jb/usr/sbin:/var/jb/sbin:/var/jb/bin:/usr/bin:/bin:/usr/sbin:/sbin
# Removed: license file not written for Sileo
mkdir -p /var/log/vpntether
uicache -p /var/jb/Applications/VPNTether.app/ 2>/dev/null
launchctl load /var/jb/Library/LaunchDaemons/com.vpntether.daemon.plist 2>/dev/null
echo "AhmedVPN Tether (SILEO) installed."
echo "RELAY WILL NOT START without a valid license."
echo "To activate: vpntether_manager activate <license-key>"
echo "Contact on WhatsApp to get your per-device license key."
PINST
chmod +x /tmp/deb_sileo/DEBIAN/postinst

# Sileo prerm (same as havoc)
cp /tmp/deb_havoc/DEBIAN/prerm /tmp/deb_sileo/DEBIAN/prerm

echo "=== 10. Update Info.plist identifiers ==="
# Sileo needs different bundle ID
sed -i 's|com.alhamadany.ahmed.vpntether|com.alhamadany.ahmed.vpntether.sileo|g' /tmp/deb_sileo/var/jb/Applications/VPNTether.app/Info.plist

echo "=== 11. Build debs ==="
cd /tmp/deb_havoc
find . -name '.DS_Store' -delete
dpkg-deb -Z gzip -b . /tmp/com.alhamadany.ahmed.vpntether_havoc_2.0.0.deb

cd /tmp/deb_sileo
find . -name '.DS_Store' -delete
dpkg-deb -Z gzip -b . /tmp/com.alhamadany.ahmed.vpntether_sileo_2.0.0.deb

ls -lh /tmp/com.alhamadany.ahmed.vpntether*2.0.0.deb

echo "=== 12. Install HAVOC deb ==="
dpkg -i /tmp/com.alhamadany.ahmed.vpntether_havoc_2.0.0.deb
uicache -p /var/jb/Applications/VPNTether.app/

echo "=== DONE ==="
echo "HAVOC deb: /tmp/com.alhamadany.ahmed.vpntether_havoc_2.0.0.deb"
echo "SILEO deb: /tmp/com.alhamadany.ahmed.vpntether_sileo_2.0.0.deb"
echo ""
echo "For license generation (Sileo users):"
echo "  Get device UUID from user: sysctl kern.uuid"
echo "  Generate key: echo -n \"VPNTetherSecret2026\${uuid}\" | shasum -a 256 | head -c 32"
echo "  User activates: vpntether_manager activate <key>"
