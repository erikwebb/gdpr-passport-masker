#!/bin/zsh

# Dynamically resolve script directory even when executed via symlink
SCRIPT_DIR="${0:A:h}"

FILE_PATH="$1"
HOTEL_NAME="$2"

# 1. Determine file path:
# a) From CLI argument $1
# b) If no argument, from current Finder selection (if an image/PDF is selected)
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

# 2. If still no file selected or found:
# Gracefully open the online web application or local HTML
if [ -z "$FILE_PATH" ] || [ ! -f "$FILE_PATH" ]; then
    echo "[+] No file specified. Opening GDPR Passport Masker in your browser..."
    if [ -f "$SCRIPT_DIR/index.html" ]; then
        open "https://erikwebb.github.io/gdpr-passport-masker/" 2>/dev/null || open "$SCRIPT_DIR/index.html"
    else
        open "https://erikwebb.github.io/gdpr-passport-masker/"
    fi
    exit 0
fi

echo "[+] Target File: $FILE_PATH"

# 3. Determine Hotel Name (interactive prompt with default if running in terminal)
if [ -z "$HOTEL_NAME" ]; then
    if [ -t 0 ]; then
        print -n "Enter the Hotel/Apartment Name [Default: Test Hotel]: "
        read HOTEL_NAME
    fi
    if [ -z "$HOTEL_NAME" ]; then
        HOTEL_NAME="Test Hotel"
    fi
fi

echo "[+] Hotel / Accommodation: $HOTEL_NAME"
echo "[+] Launching GDPR Passport Masker web interface..."

# 4. Launch ephemeral local Python bridge to preload the document into index.html
python3 - "$FILE_PATH" "$HOTEL_NAME" "$SCRIPT_DIR" << 'PYEOF'
import http.server
import socketserver
import json
import base64
import mimetypes
import os
import sys
import threading
import time
import urllib.parse
import webbrowser

file_path = sys.argv[1] if len(sys.argv) > 1 else ""
hotel_name = sys.argv[2] if len(sys.argv) > 2 else ""
script_dir = sys.argv[3] if len(sys.argv) > 3 else os.getcwd()

payload = None
if file_path and os.path.isfile(file_path):
    ext = os.path.splitext(file_path)[1].lower()
    if ext == '.heic':
        mime_type = 'image/heic'
    elif ext == '.pdf':
        mime_type = 'application/pdf'
    elif ext in ('.jpg', '.jpeg'):
        mime_type = 'image/jpeg'
    elif ext == '.png':
        mime_type = 'image/png'
    elif ext == '.webp':
        mime_type = 'image/webp'
    else:
        mime_type = mimetypes.guess_type(file_path)[0] or 'application/octet-stream'
    
    with open(file_path, 'rb') as f:
        file_bytes = f.read()
    
    payload = {
        'fileName': os.path.basename(file_path),
        'mimeType': mime_type,
        'hotelName': hotel_name,
        'base64': base64.b64encode(file_bytes).decode('utf-8')
    }

class PreloadHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=script_dir, **kwargs)

    def log_message(self, format, *args):
        pass # Suppress HTTP access logs for clean terminal output

    def do_GET(self):
        if self.path.startswith('/api/preload'):
            if payload:
                body = json.dumps(payload).encode('utf-8')
                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self.send_header('Content-Length', str(len(body)))
                self.send_header('Access-Control-Allow-Origin', '*')
                self.end_headers()
                self.wfile.write(body)
            else:
                self.send_response(404)
                self.end_headers()
            
            # Shutdown server 2 seconds after preload is retrieved
            threading.Thread(target=lambda: (time.sleep(2), httpd.shutdown()), daemon=True).start()
            return
        super().do_GET()

httpd = socketserver.TCPServer(('127.0.0.1', 0), PreloadHandler)
port = httpd.server_address[1]

# Safety timer: shut down after 60 seconds if untouched
threading.Timer(60.0, httpd.shutdown).start()

url = f"http://127.0.0.1:{port}/"
if payload:
    query = {"preload": "1"}
    if hotel_name:
        query["hotel"] = hotel_name
    url += "?" + urllib.parse.urlencode(query)

print(f"[+] Loaded scan in browser: {url}")
webbrowser.open(url)

try:
    httpd.serve_forever()
except KeyboardInterrupt:
    pass
finally:
    httpd.server_close()
    print("[+] Bridge complete. Redaction active in your browser!")
PYEOF
