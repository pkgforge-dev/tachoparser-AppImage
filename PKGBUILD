# Maintainer: fiftydinar
pkgname=tachoparser
pkgver=373eef0
pkgrel=1
pkgdesc="Decode and verify tachograph data (VU and driver card data)"
arch=('x86_64')
url="https://github.com/traconiq/tachoparser"
license=('AGPL3')
depends=('zenity-gtk3')          # dddui (GUI) uses zenity at runtime; remove if you don't want the GUI binary
makedepends=('go' 'git' 'python' 'python-requests' 'python-lxml' 'curl' 'unzip' 'libxml2')
source=("git+https://github.com/traconiq/tachoparser.git")
sha512sums=('SKIP')

# Generate a pkgver from the git repo (tags/commit)
pkgver() {
  cd "$srcdir/tachoparser"
  # produce something like 0.0.0.r<commit-short> or tag-based version if tags exist
  git_describe=$(git describe --tags --long --always 2>/dev/null || echo "")
  if [[ -n "$git_describe" ]]; then
    # remove leading v if present, convert hyphens to dots for pkgver
    echo "${git_describe#v}" | sed 's/-/./g'
  else
    echo "0.0.0"
  fi
}

prepare() {
  cp -r "${srcdir%/*}"/scripts "$srcdir/tachoparser"
  cd "$srcdir/tachoparser"

  # Ensure target directories exist so the scripts can write into them
  mkdir -p internal/pkg/certificates/pks1 internal/pkg/certificates/pks2

  # Download the public keys (network required). These files are embedded via go:embed
  (cd scripts/pks1 && sh ./dl_all_pks1.sh)
  (cd scripts/pks2 && sh ./dl_all_pks2.sh)

  # Optionally vendor modules if you want reproducible builds
  # go mod vendor
}

build() {
  cd "$srcdir/tachoparser"

  export GOFLAGS="-buildvcs=false"
  export GOPROXY="${GOPROXY:-https://proxy.golang.org,direct}"

  # Ensure modules are available
  go mod download

  # Build each command into its own binary
  BINARIES=(cmd/dddparser cmd/dddserver cmd/dddclient cmd/dddui cmd/dddsimple)
  for b in "${BINARIES[@]}"; do
    echo "Building ${b}"
    (cd "$b" && go build -trimpath -ldflags "-s -w" -o "${b##*/}")
  done
}

package() {
  cd "$srcdir/tachoparser"

  BINARIES=(dddparser dddserver dddclient dddui dddsimple)
  for bin in "${BINARIES[@]}"; do
    src="./cmd/${bin}/${bin}"
    if [[ -f "$src" ]]; then
      install -Dm755 "$src" "$pkgdir/usr/bin/${bin}"
    else
      echo "Warning: expected binary $src not found; skipping"
    fi
  done

  # license
  install -Dm644 LICENSE.md "$pkgdir/usr/share/licenses/${pkgname}/LICENSE.md"
  # readme
  install -Dm644 README.md "$pkgdir/usr/share/doc/${pkgname}/README.md"
}
