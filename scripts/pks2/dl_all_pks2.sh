#!/bin/sh
# POSIX shell replacement for scripts/pks2/dl_all_pks2.py
# Uses xmllint (libxml2) for robust HTML parsing.
set -eu

WWW_PK_URL="https://dtc.jrc.ec.europa.eu/dtc_public_key_certificates_st.php.html"
PK_BASE_URL="https://dtc.jrc.ec.europa.eu/"
ROOT_PK_ZIP_URL="https://dtc.jrc.ec.europa.eu/ERCA_Gen2_Root_Certificate.zip"
TARGET="../../internal/pkg/certificates/pks2"
ROOT_NAME="ERCA Gen2 (1) Root Certificate.bin"

cleanup() {
  rm -f "${tmpzip:-}" "${tmphtml:-}" "${parsed:-}"
}
trap cleanup EXIT HUP INT TERM

mkdir -p "$TARGET"

if [ ! -f "$TARGET/$ROOT_NAME" ]; then
  tries=0
  success=0
  while [ "$success" -eq 0 ] && [ "$tries" -lt 10 ]; do
    tries=$((tries + 1))
    tmpzip=$(mktemp -t erca_zip.XXXXXX) || tmpzip="/tmp/erca_$$.zip"
    if curl -fsSL "$ROOT_PK_ZIP_URL" -o "$tmpzip"; then
      if unzip -p "$tmpzip" "$ROOT_NAME" > "$TARGET/$ROOT_NAME" 2>/dev/null; then
        printf 'saving %s\n' "$ROOT_NAME"
        success=1
      fi
    fi
    rm -f "$tmpzip"
    [ "$success" -eq 1 ] || sleep 1
  done
fi

tmphtml=$(mktemp -t pks2_html.XXXXXX) || tmphtml="/tmp/pks2_$$.html"
if ! curl -fsSL "$WWW_PK_URL" -o "$tmphtml"; then
  printf 'ERROR: failed to download %s\n' "$WWW_PK_URL" >&2
  exit 1
fi

parsed=$(mktemp -t pks2_parsed.XXXXXX) || parsed="/tmp/pks2_parsed_$$"
if command -v xmllint >/dev/null 2>&1; then
  xmllint --html --xpath '//a[@title="Download certificate file"]' "$tmphtml" 2>/dev/null \
    | sed 's/></>\n</g' \
    | sed -n 's/.*href="\([^"]*\)".*>\s*\([^<]*\)\s*<\/a>.*/\1\t\2/p' > "$parsed"
else
  grep 'title="Download certificate file"' "$tmphtml" \
    | sed -n 's/.*href="\([^"]*\)".*>\s*\([^<]*\)\s*<.*/\1\t\2/p' > "$parsed"
fi

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
    tmpfile=$(mktemp -t pks2_cert.XXXXXX) || tmpfile="/tmp/pks2_cert_$$"
    if curl -fsSL "${PK_BASE_URL}${link}" -o "$tmpfile"; then
      bytes=$(wc -c < "$tmpfile" | tr -d ' ')
      if [ "$bytes" -ge 204 ] && [ "$bytes" -le 341 ]; then
        firstchar=$(dd if="$tmpfile" bs=1 count=1 2>/dev/null | tr -d '\n' || printf '')
        if [ "$firstchar" != "<" ]; then
          printf 'saving %s.bin\n' "$key_identifier"
          mv "$tmpfile" "$dest"
          success=1
        else
          rm -f "$tmpfile"
        fi
      else
        rm -f "$tmpfile"
      fi
    else
      rm -f "$tmpfile"
    fi
    [ "$success" -eq 1 ] || sleep 1
  done
done < "$parsed"
