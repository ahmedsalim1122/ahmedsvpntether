#!/var/jb/usr/bin/bash
# build_tweak.sh - Build AhmedVPN Tether .deb on device
# Run on iPhone after SSH
export PATH=/var/jb/usr/bin:/var/jb/usr/sbin:/var/jb/sbin:/var/jb/bin:/usr/bin:/bin:/usr/sbin:/sbin

PKGNAME="com.alhamadany.ahmed.vpntether"
VERSION="1.0.0"
BUILD_DIR="/tmp/vpntether_build"
PREFIX="/Library/VPNTether"

echo "=== AhmedVPN Tether Builder ==="
echo ""

# Check deps
if ! command -v clang-16 >/dev/null 2>&1 && ! command -v clang >/dev/null 2>&1; then
    echo "ERROR: clang not found. Install: apt install clang-16"
    exit 1
fi

if ! command -v dpkg-deb >/dev/null 2>&1; then
    echo "ERROR: dpkg-deb not found. Install: apt install dpkg"
    exit 1
fi

CLANG=$(command -v clang-16 2>/dev/null || command -v clang 2>/dev/null)

echo "[1/5] Cleaning build dir..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/$PKGNAME"
mkdir -p "$BUILD_DIR/$PKGNAME/DEBIAN"
mkdir -p "$BUILD_DIR/$PKGNAME$PREFIX"
mkdir -p "$BUILD_DIR/$PKGNAME/Library/LaunchDaemons"
mkdir -p "$BUILD_DIR/$PKGNAME/Library/PreferenceBundles/VPNTetherPrefs"
mkdir -p "$BUILD_DIR/$PKGNAME/Library/PreferenceBundles/VPNTetherPrefs/Resources"
mkdir -p "$BUILD_DIR/$PKGNAME/Library/PreferenceLoader/Preferences"
mkdir -p "$BUILD_DIR/$PKGNAME/usr/libexec/vpntether"

echo "[2/5] Compiling pf_hook.dylib..."
$CLANG -arch arm64 -isysroot /var/jb/usr/share/SDKs/iPhoneOS.sdk \
    -miphoneos-version-min=15.0 \
    -dynamiclib \
    -framework Foundation \
    -lSystem \
    -O2 \
    -o "$BUILD_DIR/$PKGNAME$PREFIX/pf_hook.dylib" \
    /var/jb/usr/local/libexec/pf_hook/pf_hook.c 2>&1

if [ $? -ne 0 ]; then
    echo "ERROR: Compilation failed"
    exit 1
fi

echo "[3/5] Copying files..."
# Control
cp /tmp/vpntether_source/DEBIAN/control "$BUILD_DIR/$PKGNAME/DEBIAN/"
cp /tmp/vpntether_source/DEBIAN/postinst "$BUILD_DIR/$PKGNAME/DEBIAN/"
cp /tmp/vpntether_source/DEBIAN/prerm "$BUILD_DIR/$PKGNAME/DEBIAN/"
chmod 755 "$BUILD_DIR/$PKGNAME/DEBIAN/postinst" "$BUILD_DIR/$PKGNAME/DEBIAN/prerm"

# Daemon
cp /tmp/vpntether_source/usr/libexec/vpntether/vpntether_manager "$BUILD_DIR/$PKGNAME/usr/libexec/vpntether/"
chmod 755 "$BUILD_DIR/$PKGNAME/usr/libexec/vpntether/vpntether_manager"

# Plist
cp /tmp/vpntether_source/Library/LaunchDaemons/com.vpntether.daemon.plist "$BUILD_DIR/$PKGNAME/Library/LaunchDaemons/"

# Preferences
cp /tmp/vpntether_source/Library/PreferenceBundles/VPNTetherPrefs/VPNTetherPrefsListController.mm "$BUILD_DIR/$PKGNAME/Library/PreferenceBundles/VPNTetherPrefs/"
cp /tmp/vpntether_source/Library/PreferenceBundles/VPNTetherPrefs/entry.plist "$BUILD_DIR/$PKGNAME/Library/PreferenceBundles/VPNTetherPrefs/"
cp /tmp/vpntether_source/Library/PreferenceBundles/VPNTetherPrefs/Info.plist "$BUILD_DIR/$PKGNAME/Library/PreferenceBundles/VPNTetherPrefs/"
cp /tmp/vpntether_source/Library/PreferenceBundles/VPNTetherPrefs/Resources/Root.plist "$BUILD_DIR/$PKGNAME/Library/PreferenceBundles/VPNTetherPrefs/Resources/"
cp /tmp/vpntether_source/Library/PreferenceLoader/Preferences/VPNTether.plist "$BUILD_DIR/$PKGNAME/Library/PreferenceLoader/Preferences/"

echo "[4/5] Building .deb..."
dpkg-deb -Zxz --build "$BUILD_DIR/$PKGNAME" "/tmp/${PKGNAME}_${VERSION}.deb" 2>&1

if [ $? -ne 0 ]; then
    echo "ERROR: dpkg-deb failed"
    exit 1
fi

SIZE=$(ls -lh "/tmp/${PKGNAME}_${VERSION}.deb" | awk '{print $5}')
echo ""
echo "=== BUILD SUCCESS ==="
echo "Package: /tmp/${PKGNAME}_${VERSION}.deb"
echo "Size: $SIZE"
echo ""
echo "Install: dpkg -i /tmp/${PKGNAME}_${VERSION}.deb"
echo "Or upload to Sileo repo."
