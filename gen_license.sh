#!/bin/bash
# gen_license.sh - Generate VPNTether license key from device UUID
# Usage: ./gen_license.sh <device-uuid>
if [ -z "$1" ]; then
    echo "Usage: $0 <device-uuid>"
    exit 1
fi
uuid="$1"
secret="VPNTetherSecret2026"
key=$(echo -n "${secret}${uuid}" | sha256sum | head -c 32)
echo "License key: $key"
