#!/usr/bin/env bash
set -euo pipefail

if [[ $# != 1 ]]; then
    echo "Usage: $0 <output-directory>" >&2
    exit 1
fi
output=$1
version=1.49.0
case "$(uname -s)" in
    Linux) os=linux ;;
    Darwin) os=darwin ;;
    *) echo "Unsupported golangci-lint operating system" >&2; exit 1 ;;
esac
case "$(uname -m)" in
    x86_64|amd64) arch=amd64 ;;
    aarch64|arm64) arch=arm64 ;;
    *) echo "Unsupported golangci-lint architecture" >&2; exit 1 ;;
esac

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
if command -v sha256sum >/dev/null 2>&1; then
    checksum=(sha256sum)
else
    checksum=(shasum -a 256)
fi
mkdir -p "$output"
tmp=$(mktemp -d "$output/.golangci-lint.XXXXXX")
trap 'rm -rf -- "$tmp"' EXIT

archive="golangci-lint-${version}-${os}-${arch}.tar.gz"
# Trust only the digest reviewed into the repository, not a downloaded checksum.
awk -v archive="$archive" '$2 == archive {print}' \
    "$script_dir/golangci-lint.sha256" > "$tmp/$archive.sha256"
if [[ $(wc -l < "$tmp/$archive.sha256") -ne 1 ]]; then
    echo "Expected exactly one pinned SHA-256 for $archive" >&2
    exit 1
fi
curl -fsSL --retry 3 --proto '=https' --proto-redir '=https' \
    "https://github.com/golangci/golangci-lint/releases/download/v${version}/$archive" \
    -o "$tmp/$archive"
(cd "$tmp" && "${checksum[@]}" -c "$archive.sha256")
# Extract only the expected binary, after verification, then replace atomically.
tar -xzOf "$tmp/$archive" "golangci-lint-${version}-${os}-${arch}/golangci-lint" \
    > "$tmp/golangci-lint"
chmod 755 "$tmp/golangci-lint"
mv -f "$tmp/golangci-lint" "$output/golangci-lint"
