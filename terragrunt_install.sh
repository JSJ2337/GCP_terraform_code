set -euo pipefail

OS="linux"
ARCH="amd64"
VERSION="v0.92.1"
BINARY_NAME="terragrunt_${OS}_${ARCH}"
curl -sL "https://github.com/gruntwork-io/terragrunt/releases/download/$VERSION/$BINARY_NAME" -o "$BINARY_NAME"
CHECKSUM="$(sha256sum "$BINARY_NAME" | awk '{print $1}')"
curl -sL "https://github.com/gruntwork-io/terragrunt/releases/download/$VERSION/SHA256SUMS" -o SHA256SUMS
EXPECTED_CHECKSUM="$(grep "$BINARY_NAME" <SHA256SUMS | awk '{print $1}')"
if [ "$CHECKSUM" == "$EXPECTED_CHECKSUM" ]; then
 echo "Checksums match!"
else
 echo "Checksums do not match!"
fi
