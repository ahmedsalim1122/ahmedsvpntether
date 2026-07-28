#!/var/jb/usr/bin/bash
export PATH=/var/jb/usr/bin:/var/jb/usr/sbin:/var/jb/sbin:/var/jb/bin:/usr/bin:/bin:/usr/sbin:/sbin
SDK=/var/jb/usr/share/SDKs/iPhoneOS.sdk
clang-16 -arch arm64 -isysroot "$SDK" \
    -miphoneos-version-min=15.0 \
    -o /var/jb/usr/libexec/vpntether/vpntether_activate \
    /tmp/appbuild/activate_helper.c 2>&1
chown root:wheel /var/jb/usr/libexec/vpntether/vpntether_activate
chmod 4755 /var/jb/usr/libexec/vpntether/vpntether_activate
echo "=== done ==="
ls -la /var/jb/usr/libexec/vpntether/vpntether_activate
