#!/bin/sh

set -eu

ARCH=$(uname -m)

echo "Installing debloated packages..."
echo "---------------------------------------------------------------"
get-debloated-pkgs --add-common --prefer-nano

echo "Installing AUR packages"
echo "---------------------------------------------------------------"
make-aur-package zenity-rs-bin
make-aur-package

chmod +x ./AppDir/bin/dddui