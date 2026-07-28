#!/var/jb/usr/bin/bash
export PATH=/var/jb/usr/bin:/var/jb/usr/sbin:/var/jb/sbin:/var/jb/bin:/usr/bin:/bin:/usr/sbin:/sbin
SDK="/private/preboot/7C98171B56C4A28F70AF02F9A3AC1C20ABF11FD00376761FC4AAE204233D327BDD3B256D6418174B1A8071F8196B5B86/dopamine-hm1KYI/procursus/usr/share/SDKs/iPhoneOS.sdk"
BUILD=/tmp/appbuild

clang-16 -arch arm64 \
    -isysroot "$SDK" \
    -I"$BUILD" \
    -miphoneos-version-min=14.0 \
    -framework UIKit \
    -framework Foundation \
    -framework CoreGraphics \
    -lobjc \
    -o "$BUILD/VPNSettings" \
    "$BUILD/main.m" 2>&1

if [ $? -eq 0 ]; then
    echo "COMPILE SUCCESS"
    ls -lh "$BUILD/VPNSettings"
else
    echo "COMPILE FAILED"
fi
