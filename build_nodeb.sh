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

cat > "$BUILD_DIR/$PKGNAME/DEBIAN/postinst" << 'POSTEOF'
#!/var/jb/usr/bin/bash
chmod 755 /var/jb/usr/libexec/vpntether/vpntether_manager 2>/dev/null
chmod 644 /var/jb/Library/LaunchDaemons/com.vpntether.daemon.plist 2>/dev/null
launchctl bootout system/com.vpntether.daemon 2>/dev/null
launchctl bootstrap system /var/jb/Library/LaunchDaemons/com.vpntether.daemon.plist 2>/dev/null
echo "AhmedVPN Tether installed. Run: vpntether_manager activate VPNT-XXXX-XXXX-XXXX"
POSTEOF
chmod 755 "$BUILD_DIR/$PKGNAME/DEBIAN/postinst"

cat > "$BUILD_DIR/$PKGNAME/DEBIAN/prerm" << 'PRMEOF'
#!/var/jb/usr/bin/bash
launchctl bootout system/com.vpntether.daemon 2>/dev/null
killall vpntether_manager 2>/dev/null
PRMEOF
chmod 755 "$BUILD_DIR/$PKGNAME/DEBIAN/prerm"

cp /var/jb/usr/local/libexec/pf_hook/pf_hook.dylib "$BUILD_DIR/$PKGNAME/var/jb/Library/VPNTether/"
cp /var/jb/usr/libexec/vpntether/vpntether_manager "$BUILD_DIR/$PKGNAME/var/jb/usr/libexec/vpntether/"
cp /var/jb/Library/LaunchDaemons/com.vpntether.daemon.plist "$BUILD_DIR/$PKGNAME/var/jb/Library/LaunchDaemons/"

chmod 755 "$BUILD_DIR/$PKGNAME/var/jb/Library/VPNTether/pf_hook.dylib"
chmod 755 "$BUILD_DIR/$PKGNAME/var/jb/usr/libexec/vpntether/vpntether_manager"

dpkg-deb -Zxz --build "$BUILD_DIR/$PKGNAME" "/tmp/${PKGNAME}_${VERSION}.deb" 2>&1
ls -lh "/tmp/${PKGNAME}_${VERSION}.deb"
echo "BUILD DONE"
