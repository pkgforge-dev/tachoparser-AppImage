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

# Use dddui as a script instead, so it works with zenity-rs
echo '
#!/bin/sh

# 1) Select input file (.ddd)
input_file="$(zenity --file-selection \
    --title="Select file..." \
    --filename="$HOME/" \
    --file-filter="*.ddd")"
status=$?
if [ $status -ne 0 ] || [ -z "$input_file" ]; then
    printf '%s\n' "No input file selected. Exiting." >&2
    exit 1
fi

# 2) Select output file (save)
output_file="$(zenity --file-selection --save --confirm-overwrite \
    --title="Save as..." \
    --filename="out.json" \
    --file-filter="*.json")"
status=$?
if [ $status -ne 0 ] || [ -z "$output_file" ]; then
    printf '%s\n' "No output file selected. Exiting." >&2
    exit 1
fi

# 3) Ask whether the file is a driver card
zenity --question \
    --title="Card type" \
    --text="Is it a driver card" \
    --ok-label="Yes" \
    --cancel-label="No"
qstatus=$?
if [ $qstatus -eq 0 ]; then
    is_card=1
elif [ $qstatus -eq 1 ]; then
    is_card=0
else
    # Unexpected zenity return (e.g. error)
    printf '%s\n' "Error asking for card type. Exiting." >&2
    exit 1
fi

# 4) Run dddparser with appropriate flag
# Use -input and -output flags so the binary reads/writes files directly.
if [ "$is_card" -eq 1 ]; then
    dddparser -card -input "$input_file" -output "$output_file"
    rc=$?
else
    dddparser -vu -input "$input_file" -output "$output_file"
    rc=$?
fi

if [ $rc -ne 0 ]; then
    zenity --error --text="Error: dddparser failed (exit code $rc)"
    printf '%s\n' "dddparser exited with status $rc" >&2
    exit $rc
fi

# 5) Notify success
zenity --info --text="Success: $input_file → $output_file"
exit 0
' > ./AppDir/bin/dddui
chmod +x ./AppDir/bin/dddui

# Turn AppDir into AppImage
quick-sharun --make-appimage

# Test the app for 12 seconds, if the app normally quits before that time
# then skip this or check if some flag can be passed that makes it stay open
#quick-sharun --test ./dist/*.AppImage
