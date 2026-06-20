#!/usr/bin/env bash
set -euo pipefail

DOWNLOAD_DIR="/tmp/ymp-build/.cache"

mkdir -p "$DOWNLOAD_DIR"

cd "$(dirname "$0")"

update_ympbuild() {
    local f="$1"
    local pkg ver name sum_var url hash
    local -a source_urls checksums

    pkg="$(basename "$(dirname "$f")")"
    ver="$(  sed -n "/^version=/{ s/^version='//; s/'.*//; p; q }" "$f")"
    name="$( sed -n "/^name=/{    s/^name='//;   s/'.*//; p; q }" "$f")"
    [ -z "$ver" ] && { echo "  skip $pkg (no version)"; return; }
    [ -z "$name" ] && name="$pkg"
    sum_var="$([[ -f "$f" ]] && grep -q "^md5sums=" "$f" && echo "md5sums" || echo "sha256sums")"

    # Get all source URLs by sourcing the ympbuild with bash -c
    # Bash naturally expands all variables ($version, ${name}, etc.)
    source_urls=()
    while IFS= read -r -d '' url; do
        source_urls+=("$url")
    done < <(bash -c "source '$f' &>/dev/null; printf '%s\0' \"\${source[@]}\"" 2>/dev/null || true)

    [ ${#source_urls[@]} -eq 0 ] && { echo "  skip $pkg (no source URLs)"; return; }

    checksums=()
    for url in "${source_urls[@]}"; do
        # Skip local files (no protocol scheme)
        if [[ "$url" != *"://"* ]]; then
            checksums+=("SKIP")
            continue
        fi

        filename="${url##*/}"
        mkdir -p "$DOWNLOAD_DIR/$name"
        local dest="$DOWNLOAD_DIR/$name/$filename"

        if [ ! -f "$dest" ]; then
            echo "  DL   $filename"
            curl --progress-bar \
                -fsSL -o "$dest" "$url" || {
                echo "  FAIL $pkg (download $url)"
                checksums+=("SKIP")
                continue
            }
        else
            echo "  CACHE $filename"
        fi

        if [ "$sum_var" = "md5sums" ]; then
            hash="$(md5sum "$dest" | cut -d' ' -f1)"
        else
            hash="$(sha256sum "$dest" | cut -d' ' -f1)"
        fi
        checksums+=("$hash")
    done

    # Build new checksum array string
    local new_sums="("
    for h in "${checksums[@]}"; do
        new_sums+=" '$h'"
    done
    new_sums+=" )"

    # Replace old checksum block in the file
    if grep -qE "^${sum_var}=\([^)]*\)" "$f"; then
        # Single-line format: sha256sums=('hash1' 'hash2' ...)
        sed -i "s|^${sum_var}=.*|${sum_var}=${new_sums}|" "$f"
    else
        # Multi-line format: replaces from ^sha256sums=( to the closing )
        sed -i "/^${sum_var}=/,/^)/c\\${sum_var}=${new_sums}" "$f"
    fi
    echo "  OK   $pkg  ${#checksums[@]} checksums updated"
}

find "$1" -type f -iname 'ympbuild' | while read ympbuild ; do
    update_ympbuild "$ympbuild"
done
