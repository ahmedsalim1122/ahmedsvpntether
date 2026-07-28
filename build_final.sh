#!/var/jb/usr/bin/bash
export PATH=/var/jb/usr/bin:/var/jb/usr/sbin:/var/jb/sbin:/var/jb/bin:/usr/bin:/bin:/usr/sbin:/sbin

PKGNAME="com.alhamadany.ahmed.vpntether"
VERSION="1.0.0"
BUILD_DIR="/tmp/vpntether_build"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/$PKGNAME/DEBIAN"
mkdir -p "$BUILD_DIR/$PKGNAME/var/jb/Library/VPNTether"
mkdir -p "$BUILD_DIR/$PKGNAME/var/jb/Library/LaunchDaemons"
mkdir -p "$BUILD_DIR/$PKGNAME/var/jb/usr/libexec/vpntether"

cat > "$BUILD_DIR/$PKGNAME/DEBIAN/control" << 'CTRLEOF'
Package: com.alhamadany.ahmed.vpntether
Name: AhmedVPN Tether
Depends: firmware (>= 16.0), ellekit
Architecture: iphoneos-arm64
Description: Route iPhone hotspot traffic through VPN automatically. Zero client configuration.
Maintainer: Ahmed Alhamadany <ahmed@alhamadany.dev>
Section: Tweaks
Version: 1.0.0
CTRLEOF

# Use the fixed scripts we already uploaded
cp /tmp/prerm_fix.sh "$BUILD_DIR/$PKGNAME/DEBIAN/prerm"
cp /tmp/postinst_fix.sh "$BUILD_DIR/$PKGNAME/DEBIAN/postinst"

# Copy files
cp /var/jb/usr/local/libexec/pf_hook/pf_hook.dylib "$BUILD_DIR/$PKGNAME/var/jb/Library/VPNTether/"
cp /var/jb/usr/libexec/vpntether/vpntether_manager "$BUILD_DIR/$PKGNAME/var/jb/usr/libexec/vpntether/"
cp /var/jb/Library/LaunchDaemons/com.vpntether.daemon.plist "$BUILD_DIR/$PKGNAME/var/jb/Library/LaunchDaemons/"

chmod 755 "$BUILD_DIR/$PKGNAME/DEBIAN/postinst"
chmod 755 "$BUILD_DIR/$PKGNAME/DEBIAN/prerm"
chmod 755 "$BUILD_DIR/$PKGNAME/var/jb/Library/VPNTether/pf_hook.dylib"
chmod 755 "$BUILD_DIR/$PKGNAME/var/jb/usr/libexec/vpntether/vpntether_manager"

dpkg-deb -Zxz --build "$BUILD_DIR/$PKGNAME" "/tmp/${PKGNAME}_${VERSION}.deb" 2>&1

# Force remove broken package
dpkg --purge --force-all "$PKGNAME" 2>/dev/null || true

# Install
dpkg -i "/tmp/${PKGNAME}_${VERSION}.deb" 2>&1

echo "=== verify ==="
dpkg -L "$PKGNAME" 2>&1
ps -A | grep vpntether | grep -v grep
echo "DONE"
