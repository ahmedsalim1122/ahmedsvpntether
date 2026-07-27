#!/bin/bash
# setup_sileo_repo.sh - Set up APT repository for Sileo distribution
# Run this on a web server (GitHub Pages, etc.)

REPO_DIR="vpntether-repo"
PKGNAME="com.alhamadany.ahmed.vpntether"
VERSION="1.0.0"

echo "=== Setting up Sileo APT Repository ==="

# Create repo structure
mkdir -p "$REPO_DIR/dists/stable/main/binary-arm64"
mkdir -p "$REPO_DIR/pool/main"

# Copy .deb
cp "/tmp/${PKGNAME}_${VERSION}.deb" "$REPO_DIR/pool/main/"

# Generate Packages
cd "$REPO_DIR/pool/main"
dpkg-scanpackages . /dev/null > ../Packages
gzip -k -f ../Packages
cd ../..

# Generate Release
cat > dists/stable/Release << EOF
Origin: AhmedVPN
Label: AhmedVPN Tether
Suite: stable
Codename: stable
Architectures: arm64
Components: main
Description: Route iPhone hotspot traffic through VPN
Date: $(date -R)
SHA256:
 $(sha256sum pool/main/Packages | awk '{print " "$(NF)}')
 $(sha256sum pool/main/Packages.gz | awk '{print " "$(NF)}')
EOF

echo ""
echo "=== Repository ready ==="
echo "Upload '$REPO_DIR/' to your web server"
echo "Add to Sileo: https://YOUR-DOMAIN.com/$REPO_DIR"
echo ""
echo "For GitHub Pages:"
echo "  1. Create repo 'vpntether-repo' on GitHub"
echo "  2. Copy contents of $REPO_DIR/"
echo "  3. Enable Pages in Settings"
echo "  4. Add URL: https://YOURUSER.github.io/vpntether-repo"
