#!/var/jb/usr/bin/bash
export PATH=/var/jb/usr/bin:/var/jb/usr/sbin:/var/jb/sbin:/var/jb/bin:/usr/bin:/bin:/usr/sbin:/sbin

APPDIR=/tmp/appbuild/VPNSettings.app
rm -rf "$APPDIR"
mkdir -p "$APPDIR"

cp /tmp/appbuild/VPNSettings "$APPDIR/VPNSettings"

cat > "$APPDIR/Info.plist" << 'PLISTEOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>VPNSettings</string>
    <key>CFBundleIdentifier</key>
    <string>com.alhamadany.ahmed.vpntether.settings</string>
    <key>CFBundleName</key>
    <string>AhmedVPN Tether</string>
    <key>CFBundleDisplayName</key>
    <string>AhmedVPN Tether</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSRequiresIPhoneOS</key>
    <true/>
    <key>UIRequiredDeviceCapabilities</key>
    <array>
        <string>arm64</string>
    </array>
    <key>UISupportedInterfaceOrientations</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
    </array>
</dict>
</plist>
PLISTEOF

ldid -S "$APPDIR/VPNSettings" 2>&1
echo "=== signed ==="
ls -la "$APPDIR/"
echo "=== app size ==="
du -sh "$APPDIR"
