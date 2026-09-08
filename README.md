# Secure Passport Redactor for macOS

A macOS CLI utility & AppleScript Finder app to automatically redact Machine Readable Zone (MRZ) data and watermark passport scans when checking into European hotels & accommodations under GDPR compliance.

## Privacy & Legal Context (GDPR)
Under **GDPR Article 5.1(c) (Data Minimization)** and rulings by European Data Protection Authorities (e.g. Spain's AEPD, Netherlands AP):
- Hotels have a legal duty to inspect your identity and report guest text data (Name, Date of Birth, Passport #).
- **However**, hotels are generally **not authorized to scan, photocopy, or store full images of identity documents**.
- Passports contain excessive data (facial photos, signatures, MRZ security codes) not required by guest registration laws.

This tool helps travelers redact non-essential zones (MRZ code lines) and watermark the passport image with `"FOR [HOTEL] CHECK-IN ONLY"` to prevent unauthorized reuse or identity fraud.

---

## Installation & Setup

1. **Clone/Save files into `~/bin`**:
   ```bash
   mkdir -p ~/bin
   ```

2. **Compile the Swift Redactor Engine**:
   ```bash
   swiftc redact_passport.swift -o ~/bin/redact_passport
   ```

3. **Make the Zsh script executable**:
   ```bash
   chmod +x secure_passport.sh
   ln -sf ~/bin/secure_passport.sh ~/bin/secure_passport
   ```

4. **Ensure `~/bin` is in your `PATH`**:
   Add this line to your `~/.zshrc`:
   ```bash
   export PATH="$HOME/bin:$PATH"
   ```

---

## Usage

### 1. Terminal / CLI Mode
```bash
# Interactive mode (uses selected Finder image or opens file picker):
secure_passport

# Command line mode:
secure_passport /path/to/passport.jpg "Gran Hotel Madrid" 1

# Batch process images in a loop:
for f in ~/Desktop/*.jpg; do
    secure_passport "$f" "Hotel Milano" 1
done
```

### 2. Layout Options
- **Option 1 (Photo Page Only)**:
  - Solid Black Redaction Box: Bottom **25%** (MRZ code lines).
  - Diagonal Watermark: Top-down **25% – 75%** height.
- **Option 2 (Photo + Signature Pages)**:
  - Solid Black Redaction Box: Bottom **12.5%**.
  - Diagonal Watermark: Top-down **37.5% – 87.5%** height.

---

## macOS Desktop App Shortcut

To create a double-clickable Desktop shortcut that integrates directly with Finder:

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
        set layoutDialog to display dialog "Select Passport Image Layout:" with title "Secure Passport Redactor" buttons {"Photo + Signature (12.5%)", "Photo Page Only (25%)"} default button "Photo Page Only (25%)"
        set layoutChoice to button returned of layoutDialog
    end tell

    if layoutChoice contains "25%" then
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

## License
MIT License