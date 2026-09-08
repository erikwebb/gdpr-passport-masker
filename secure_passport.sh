#!/bin/zsh

FILE_PATH="$1"
HOTEL_NAME="$2"
LAYOUT_CHOICE="$3"

# 1. Determine file path:
# a) From CLI argument $1
# b) If no argument, from current Finder selection (if an image is selected)
# c) If no image selected in Finder, open Finder file picker dialog

if [ -z "$FILE_PATH" ]; then
    FILE_PATH=$(osascript -e '
    tell application "Finder"
        activate
        set currentSelection to selection
        if currentSelection is not {} then
            try
                set firstItem to item 1 of currentSelection
                set fileExt to name extension of firstItem
                if fileExt is in {"png", "jpg", "jpeg", "heic", "tiff", "pdf", "PNG", "JPG", "JPEG", "HEIC"} then
                    return POSIX path of (firstItem as alias)
                end if
            end try
        end if
    end tell
    return ""
    ' 2>/dev/null)
fi

if [ -z "$FILE_PATH" ] || [ ! -f "$FILE_PATH" ]; then
    FILE_PATH=$(osascript -e '
    tell application "Finder"
        activate
        set chosenFile to choose file with prompt "Select your passport image:"
        return POSIX path of chosenFile
    end tell
    ' 2>/dev/null)
fi

if [ -z "$FILE_PATH" ] || [ ! -f "$FILE_PATH" ]; then
    echo "[-] Error: No file selected and no valid file path provided."
    echo "Usage: $0 [/path/to/passport_image.jpg] [Hotel Name] [Layout: 1 or 2]"
    exit 1
fi

echo "[+] Target File: $FILE_PATH"

# 2. Determine Hotel Name (interactive prompt with default or fallback for loop testing)
if [ -z "$HOTEL_NAME" ]; then
    if [ -t 0 ]; then
        print -n "Enter the Hotel/Apartment Name [Default: Test Hotel]: "
        read HOTEL_NAME
    fi
    if [ -z "$HOTEL_NAME" ]; then
        HOTEL_NAME="Test Hotel"
    fi
fi

# 3. Determine Layout Choice (interactive prompt with default or fallback for loop testing)
if [ -z "$LAYOUT_CHOICE" ]; then
    if [ -t 0 ]; then
        print "What does this image include?"
        print "1) Photo Page Only (Censors bottom 25%, Watermarks 25-75%)"
        print "2) Photo + Signature Pages (Censors bottom 12.5%, Watermarks 37.5-87.5%)"
        print -n "Select 1 or 2 [Default: 1]: "
        read LAYOUT_CHOICE
    fi
    if [ -z "$LAYOUT_CHOICE" ]; then
        LAYOUT_CHOICE="1"
    fi
fi

# Sanitize hotel name for filename placement
HOTEL_CLEAN=$(echo "$HOTEL_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/_/g' | sed 's/__*/_/g')
if [ -z "$HOTEL_CLEAN" ]; then
    HOTEL_CLEAN="hotel"
fi

# Setup target paths
DESKTOP_PATH="$HOME/Desktop"
FILE_NAME=$(basename "$FILE_PATH")
TARGET_PATH="$DESKTOP_PATH/secured_${HOTEL_CLEAN}_$FILE_NAME"

# Execute solid black-out censorship and watermark using compiled Swift redactor
"$HOME/bin/redact_passport" "$FILE_PATH" "$TARGET_PATH" "$LAYOUT_CHOICE" "$HOTEL_NAME"

echo "[+] Success! Redacted & watermarked copy saved to Desktop: secured_${HOTEL_CLEAN}_$FILE_NAME"