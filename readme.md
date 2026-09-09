# GDPR Passport Masker for macOS

A macOS CLI utility & Finder AppleScript app to automatically redact Machine Readable Zone (MRZ) data and watermark passport scans when checking into European hotels & accommodations under GDPR compliance.

---

## Features

- **100% Native Resolution & Quality**: Decodes and encodes images using Apple ImageIO (`CGImageSource` and `CGImageDestination`), preserving 1:1 pixel dimensions, original DPI metadata, color profiles (e.g., Adobe RGB, Display P3, sRGB), and EXIF camera orientation without lossy downsampling.
- **High-Resolution 300 DPI PDF Rendering**: Automatically detects PDF passport scans and renders them at 300 DPI print/scan quality (e.g. 2482 × 3501) with support for direct PDF or image output.
- **Automated ID Verification & OCR Friendly**: Watermarks use translucent red without harsh black borders, and document headers (`PASSPORT`, `UNITED STATES OF AMERICA`, `P USA`) are kept unobstructed so automated check-in portals (such as Onfido, Veriff, or Jumio) easily recognize the document type while keeping it protected under GDPR data minimization.
- **Dual Layout Options**: Intelligently handles both single-page passport crops and full two-page spreads (signature page + photo page).

---

## Quick One-Line Installation

Run this single command in your macOS Terminal to download the files, compile the Swift engine, update your `PATH`, and set up `~/bin`:

```bash
mkdir -p ~/bin && \
curl -sL https://gist.githubusercontent.com/erikwebb/84ac1b6092fd2211294fa21c96d10187/raw/gdpr_passport_masker.sh -o ~/bin/gdpr_passport_masker.sh && \
curl -sL https://gist.githubusercontent.com/erikwebb/84ac1b6092fd2211294fa21c96d10187/raw/redact_passport.swift -o ~/bin/redact_passport.swift && \
chmod +x ~/bin/gdpr_passport_masker.sh && \
ln -sf ~/bin/gdpr_passport_masker.sh ~/bin/secure_passport && \
swiftc ~/bin/redact_passport.swift -o ~/bin/redact_passport && \
grep -q 'HOME/bin' ~/.zshrc 2>/dev/null || echo '\nexport PATH="$HOME/bin:$PATH"' >> ~/.zshrc
```

---

## Desktop App Shortcut Creation

To create a double-clickable **`Secure Passport.app`** on your Desktop:

```bash
cat << 'EOF' > /tmp/secure_passport_app.applescript
on run
    set targetFile to ""
    tell application "Finder"
        activate
        set currentSelection to selection
        if currentSelection is not {} then
            try
                set firstItem to item 1 of currentSelection
                set fileExt to name extension of firstItem
                if fileExt is in {"png", "jpg", "jpeg", "heic", "tiff", "pdf", "PNG", "JPG", "JPEG", "HEIC"} then
                    set targetFile to POSIX path of (firstItem as alias)
                end if
            end try
        end if
    end tell

    if targetFile is "" then
        try
            tell application "Finder"
                activate
                set chosenFile to choose file with prompt "Select your passport image:"
                set targetFile to POSIX path of chosenFile
            end tell
        on error
            return
        end try
    end if

    tell application "Finder"
        activate
        set hotelDialog to display dialog "Enter the Hotel/Apartment Name:" default answer "" with title "Secure Passport Redactor" buttons {"Cancel", "Continue"} default button "Continue"
        set hotelName to text returned of hotelDialog
    end tell

    set homePath to POSIX path of (path to home folder)
    set scriptPath to homePath & "bin/secure_passport"

    set cmd to quoted form of scriptPath & " " & quoted form of targetFile & " " & quoted form of hotelName
    do shell script cmd

    tell application "Finder"
        activate
        display dialog "Success! Redacted passport copy saved to your Desktop." with title "Secure Passport Redactor" buttons {"OK"} default button "OK" with icon note
    end tell
end run
EOF

osacompile -o "$HOME/Desktop/Secure Passport.app" /tmp/secure_passport_app.applescript
rm /tmp/secure_passport_app.applescript
```

---

## Usage

### 1. Desktop App Mode
Double-click **`Secure Passport.app`** on your Desktop. Highlight a passport scan in Finder first, or select one from the file picker when prompted. It automatically detects the passport layout and only prompts for the accommodation name.

### 2. Terminal CLI Mode
```bash
# Interactive mode (prompts for hotel name):
secure_passport

# Direct arguments mode:
secure_passport /path/to/passport.jpg "Gran Hotel Madrid"

# Batch process images in a loop:
for f in ~/Desktop/*.jpg; do
    secure_passport "$f" "Hotel Milano"
done
```

---

## Intelligent Layout Auto-Detection

The engine automatically inspects the image aspect ratio to determine the passport layout:

- **Two-Page Spread (Auto-Detected when Height > Width)**:
  - **Solid Black Redaction Box**: Bottom ~10% covering the Machine Readable Zone (MRZ) on two-page spreads.
  - **Dual-Zone Diagonal Watermarks**: Protects both the photo/personal data zone (10% – 43%) and signature zone (58% – 82%), leaving the center fold and header titles (`PASSPORT`, `UNITED STATES OF AMERICA`, `P USA`) unobstructed so automated check-in systems (e.g. Onfido, Veriff, Jumio) recognize the document without error.
- **Single Photo Page (Auto-Detected when Landscape / Crop)**:
  - **Solid Black Redaction Box**: Bottom ~18% covering the Machine Readable Zone (MRZ).
  - **Diagonal Watermark**: Spans 18% – 65% of image height across the photo and bearer data while leaving top document headers clear.

*(Optional manual override: pass `1` for single-page or `2` for two-page spread as a 3rd CLI argument if ever desired).*

---

## Privacy & Legal Context (GDPR)
Under **GDPR Article 5.1(c) (Data Minimization)** and rulings by European Data Protection Authorities (e.g. Spain's AEPD, Netherlands AP):
- Accommodations must verify identity and report guest text data (Name, Date of Birth, Passport #).
- **Accommodations are generally prohibited from scanning, photocopying, or storing full images of passports**, as passports contain unneeded sensitive data (photographs, signatures, security numbers).

This tool creates a safe redacted & watermarked copy preventing unauthorized identity theft or reuse.
