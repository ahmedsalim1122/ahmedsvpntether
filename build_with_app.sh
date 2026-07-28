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
mkdir -p "$BUILD_DIR/$PKGNAME/var/jb/Applications/VPNSettings.app"

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

cp /tmp/prerm_fix.sh "$BUILD_DIR/$PKGNAME/DEBIAN/prerm"
cp /tmp/postinst_fix.sh "$BUILD_DIR/$PKGNAME/DEBIAN/postinst"

# Core files
cp /var/jb/usr/local/libexec/pf_hook/pf_hook.dylib "$BUILD_DIR/$PKGNAME/var/jb/Library/VPNTether/"
cp /var/jb/usr/libexec/vpntether/vpntether_manager "$BUILD_DIR/$PKGNAME/var/jb/usr/libexec/vpntether/"
cp /var/jb/usr/libexec/vpntether/vpntether_activate "$BUILD_DIR/$PKGNAME/var/jb/usr/libexec/vpntether/"
cp /var/jb/Library/LaunchDaemons/com.vpntether.daemon.plist "$BUILD_DIR/$PKGNAME/var/jb/Library/LaunchDaemons/"

# App
cp -r /tmp/appbuild/VPNSettings.app/* "$BUILD_DIR/$PKGNAME/var/jb/Applications/VPNSettings.app/"

chmod 755 "$BUILD_DIR/$PKGNAME/DEBIAN/postinst"
chmod 755 "$BUILD_DIR/$PKGNAME/DEBIAN/prerm"
chmod 755 "$BUILD_DIR/$PKGNAME/var/jb/Library/VPNTether/pf_hook.dylib"
chmod 755 "$BUILD_DIR/$PKGNAME/var/jb/usr/libexec/vpntether/vpntether_manager"
chmod 4755 "$BUILD_DIR/$PKGNAME/var/jb/usr/libexec/vpntether/vpntether_activate"
chmod 755 "$BUILD_DIR/$PKGNAME/var/jb/Applications/VPNSettings.app/VPNSettings"

dpkg-deb -Zxz --build "$BUILD_DIR/$PKGNAME" "/tmp/${PKGNAME}_${VERSION}.deb" 2>&1
ls -lh "/tmp/${PKGNAME}_${VERSION}.deb"
echo "BUILD DONE"
