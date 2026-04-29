#!/bin/bash
# setup-cert.sh — create a stable self-signed code-signing identity ONCE.
# After this, bundle.sh will produce builds with a consistent signature so
# macOS TCC (Accessibility, Input Monitoring, etc.) doesn't revoke permission
# on every rebuild.
#
# Usage: ./setup-cert.sh
# You may be prompted for your login password during the trust step.

set -euo pipefail

CERT_NAME="PromtSidecarDev"
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

if security find-identity -v -p codesigning login.keychain-db | grep -q "$CERT_NAME"; then
    echo "==> '$CERT_NAME' already exists. Skipping."
    echo "    To recreate, delete it from Keychain Access and rerun."
    exit 0
fi

echo "==> Generating self-signed certificate ($CERT_NAME, 10-year validity)"
cat > "$TMP_DIR/cert.cnf" <<EOF
[ req ]
distinguished_name = req_dn
prompt = no

[ req_dn ]
CN = $CERT_NAME

[ ext ]
basicConstraints = CA:false
keyUsage = digitalSignature
extendedKeyUsage = codeSigning
EOF

openssl req -x509 -newkey rsa:2048 -nodes \
    -keyout "$TMP_DIR/cert.key" \
    -out "$TMP_DIR/cert.crt" \
    -days 3650 \
    -config "$TMP_DIR/cert.cnf" \
    -extensions ext 2>/dev/null

openssl pkcs12 -export -legacy \
    -in "$TMP_DIR/cert.crt" \
    -inkey "$TMP_DIR/cert.key" \
    -out "$TMP_DIR/cert.p12" \
    -name "$CERT_NAME" \
    -passout pass:promt

echo "==> Importing into login keychain"
security import "$TMP_DIR/cert.p12" \
    -k "$HOME/Library/Keychains/login.keychain-db" \
    -P promt \
    -T /usr/bin/codesign \
    -A

echo "==> Marking certificate as trusted for code signing (may prompt for login password)"
security add-trusted-cert \
    -r trustRoot \
    -p codeSign \
    -k "$HOME/Library/Keychains/login.keychain-db" \
    "$TMP_DIR/cert.crt"

echo
echo "==> Verifying:"
security find-identity -v -p codesigning login.keychain-db | grep "$CERT_NAME" || true

echo
echo "Done. Now run: ./bundle.sh"
echo "After the first AX grant for this signed build, future rebuilds will preserve permission."
