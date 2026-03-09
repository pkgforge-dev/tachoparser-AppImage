#!/bin/sh

set -eu

ARCH=$(uname -m)
VERSION=$(pacman -Q tachoparser | awk '{print $2; exit}')
export ARCH VERSION
export OUTPATH=./dist
#export ADD_HOOKS="self-updater.bg.hook"
#export UPINFO="gh-releases-zsync|${GITHUB_REPOSITORY%/*}|${GITHUB_REPOSITORY#*/}|latest|*$ARCH.AppImage.zsync"
export ICON=DUMMY
export DESKTOP=DUMMY
export MAIN_BIN=dddui
export APPNAME=tachoparser

# Deploy dependencies
quick-sharun /usr/bin/dddparser \
    	     /usr/bin/dddserver \
    	     /usr/bin/dddclient \
    	     /usr/bin/dddsimple \
			 /usr/bin/zenity

# Turn AppDir into AppImage
quick-sharun --make-appimage

# Test the app for 12 seconds, if the app normally quits before that time
# then skip this or check if some flag can be passed that makes it stay open
#quick-sharun --test ./dist/*.AppImage
