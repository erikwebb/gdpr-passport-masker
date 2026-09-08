# GDPR Passport Masker for macOS

A macOS CLI utility & Finder AppleScript app to automatically redact Machine Readable Zone (MRZ) data and watermark passport scans when checking into European hotels & accommodations under GDPR compliance.

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

    tell application "Finder"
        activate
        set layoutDialog to display dialog "Select Passport Image Layout:" with title "Secure Passport Redactor" buttons {"Photo + Signature", "Photo Page Only"} default button "Photo Page Only"
        set layoutChoice to button returned of layoutDialog
    end tell

    if layoutChoice contains "Photo Page Only" then
        set layoutNum to "1"
    else
        set layoutNum to "2"
    end if

    set homePath to POSIX path of (path to home folder)
    set scriptPath to homePath & "bin/secure_passport"

    set cmd to quoted form of scriptPath & " " & quoted form of targetFile & " " & quoted form of hotelName & " " & layoutNum
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
Double-click **`Secure Passport.app`** on your Desktop. Highlight a passport scan in Finder first, or select one from the file picker when prompted.

### 2. Terminal CLI Mode
```bash
# Interactive mode:
secure_passport

# Direct arguments mode:
secure_passport /path/to/passport.jpg "Gran Hotel Madrid" 1

# Batch process images in a loop:
for f in ~/Desktop/*.jpg; do
    secure_passport "$f" "Hotel Milano" 1
done
```

---

## Redaction & Watermark Layout Options

- **Option 1 (Photo Page Only)**:
  - Solid Black Redaction Box: Bottom MRZ code lines with margin gap.
  - Diagonal Watermark: Top-down **25% – 82%** height.
- **Option 2 (Photo + Signature Pages)**:
  - Solid Black Redaction Box: Bottom MRZ code lines with margin gap.
  - Diagonal Watermark: Top-down **37.5% – 92%** height.

---

## Privacy & Legal Context (GDPR)
Under **GDPR Article 5.1(c) (Data Minimization)** and rulings by European Data Protection Authorities (e.g. Spain's AEPD, Netherlands AP):
- Accommodations must verify identity and report guest text data (Name, Date of Birth, Passport #).
- **Accommodations are generally prohibited from scanning, photocopying, or storing full images of passports**, as passports contain unneeded sensitive data (photographs, signatures, security numbers).

This tool creates a safe redacted & watermarked copy preventing unauthorized identity theft or reuse.