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

echo "Make dddui sh script instead, as it works properly compared to the official one"
echo "---------------------------------------------------------------"
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

# 2) Select output directory
output_dir="$(zenity --file-selection --directory \
    --title="Save in directory...")"
status=$?
if [ $status -ne 0 ] || [ -z "$output_dir" ]; then
    printf '%s\n' "No output file selected. Exiting." >&2
    exit 1
fi
output_file="$output_dir/out.json"

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
zenity --info --width=600 --height=200 --text="Success: $input_file → $output_file"
exit 0
' > /usr/bin/dddui
chmod +x /usr/bin/dddui
mkdir -p ./AppDir/bin
cp /usr/bin/dddui ./AppDir/bin/dddui
