#!/bin/sh
# POSIX shell replacement for scripts/pks1/dl_all_pks1.py
# Uses xmllint (libxml2) for robust HTML parsing.
set -eu

WWW_PK_URL="https://dtc.jrc.ec.europa.eu/dtc_public_key_certificates_dt.php.html"
PK_BASE_URL="https://dtc.jrc.ec.europa.eu/"
ROOT_PK_ZIP_URL="https://dtc.jrc.ec.europa.eu/erca_of_doc/EC_PK.zip"
TARGET="../../internal/pkg/certificates/pks1"

cleanup() {
  rm -f "${tmpzip:-}" "${tmphtml:-}" "${parsed:-}"
}
trap cleanup EXIT HUP INT TERM

mkdir -p "$TARGET"

# Download root EC_PK.bin from zip if missing
if [ ! -f "$TARGET/EC_PK.bin" ]; then
  tries=0
  success=0
  while [ "$success" -eq 0 ] && [ "$tries" -lt 10 ]; do
    tries=$((tries + 1))
    tmpzip=$(mktemp -t ec_pk_zip.XXXXXX) || tmpzip="/tmp/ec_pk_$$.zip"
    if curl -fsSL "$ROOT_PK_ZIP_URL" -o "$tmpzip"; then
      if unzip -p "$tmpzip" "EC_PK.bin" > "$TARGET/EC_PK.bin" 2>/dev/null; then
        printf 'saving EC_PK.bin\n'
        success=1
      fi
    fi
    rm -f "$tmpzip"
    [ "$success" -eq 1 ] || sleep 1
  done
fi

# Fetch listing page
tmphtml=$(mktemp -t pks1_html.XXXXXX) || tmphtml="/tmp/pks1_$$.html"
if ! curl -fsSL "$WWW_PK_URL" -o "$tmphtml"; then
  printf 'ERROR: failed to download %s\n' "$WWW_PK_URL" >&2
  exit 1
fi

# Parse anchors with title="Download certificate file" using xmllint if available.
parsed=$(mktemp -t pks1_parsed.XXXXXX) || parsed="/tmp/pks1_parsed_$$"
if command -v xmllint >/dev/null 2>&1; then
  # xmllint --html --xpath returns concatenated nodes; split them on "><" to one per line
  xmllint --html --xpath '//a[@title="Download certificate file"]' "$tmphtml" 2>/dev/null \
    | sed 's/></>\n</g' \
    | sed -n 's/.*href="\([^"]*\)".*>\s*\([^<]*\)\s*<\/a>.*/\1\t\2/p' > "$parsed"
else
  # fallback to a conservative grep/sed extraction
  grep 'title="Download certificate file"' "$tmphtml" \
    | sed -n 's/.*href="\([^"]*\)".*>\s*\([^<]*\)\s*<.*/\1\t\2/p' > "$parsed"
fi

# Iterate parsed lines: href <TAB> link text
while IFS='	' read -r link key_identifier; do
  [ -n "${link:-}" ] || continue
  [ -n "${key_identifier:-}" ] || continue
  dest="$TARGET/${key_identifier}.bin"
  if [ -f "$dest" ]; then
    continue
  fi

  tries=0
  success=0
  while [ "$success" -eq 0 ] && [ "$tries" -lt 10 ]; do
    tries=$((tries + 1))
    tmpfile=$(mktemp -t pks1_cert.XXXXXX) || tmpfile="/tmp/pks1_cert_$$"
    if curl -fsSL "${PK_BASE_URL}${link}" -o "$tmpfile"; then
      bytes=$(wc -c < "$tmpfile" | tr -d ' ')
      if [ "$bytes" -eq 194 ]; then
        printf 'saving %s.bin\n' "$key_identifier"
        mv "$tmpfile" "$dest"
        success=1
      else
        rm -f "$tmpfile"
      fi
    else
      rm -f "$tmpfile"
    fi
    [ "$success" -eq 1 ] || sleep 1
  done
done < "$parsed"
