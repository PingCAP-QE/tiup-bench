#!/usr/bin/env bash
set -euo pipefail

if [[ $# != 3 ]]; then
    echo "Usage: $0 <os> <arch> <output-directory>" >&2
    exit 1
fi
os=$1
arch=$2
output=$3
case "$os/$arch" in
    linux/amd64|linux/arm64|darwin/amd64|darwin/arm64) ;;
    *) echo "Unsupported release platform: $os/$arch" >&2; exit 1 ;;
esac

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
if command -v sha256sum >/dev/null 2>&1; then
    checksum=(sha256sum)
else
    checksum=(shasum -a 256)
fi
mkdir -p "$output"
tmp=$(mktemp -d "$output/.dependencies.XXXXXX")
trap 'rm -rf -- "$tmp"' EXIT

tpc_archive="go-tpc_1.0.12_${os}_${arch}.tar.gz"
ycsb_archive="go-ycsb-${os}-${arch}.tar.gz"
for archive in "$tpc_archive" "$ycsb_archive"; do
    # The expected digest comes only from the reviewed, checked-in lock file.
    awk -v archive="$archive" '$2 == archive {print}' \
        "$script_dir/dependencies.sha256" > "$tmp/$archive.sha256"
    if [[ $(wc -l < "$tmp/$archive.sha256") -ne 1 ]]; then
        echo "Expected exactly one pinned SHA-256 for $archive" >&2
        exit 1
    fi
done

curl -fsSL --retry 3 --proto '=https' --proto-redir '=https' \
    "https://github.com/pingcap/go-tpc/releases/download/v1.0.12/$tpc_archive" \
    -o "$tmp/$tpc_archive"
curl -fsSL --retry 3 --proto '=https' --proto-redir '=https' \
    "https://github.com/pingcap/go-ycsb/releases/download/v1.0.3/$ycsb_archive" \
    -o "$tmp/$ycsb_archive"

# Verify both downloads before extracting anything. Never execute archive contents.
for archive in "$tpc_archive" "$ycsb_archive"; do
    (cd "$tmp" && "${checksum[@]}" -c "$archive.sha256")
done
# Read only the expected binary; archive paths and permissions are not restored.
tar -xzOf "$tmp/$tpc_archive" go-tpc > "$tmp/go-tpc"
tar -xzOf "$tmp/$ycsb_archive" go-ycsb > "$tmp/go-ycsb"
chmod 755 "$tmp/go-tpc" "$tmp/go-ycsb"
mv -f "$tmp/go-tpc" "$tmp/go-ycsb" "$output/"
