# GDPR Passport Masker

A private, client-side web application and macOS CLI utility to automatically redact Machine Readable Zone (MRZ) biometric data and apply anti-tamper check-in watermarks to passport scans for European accommodation check-ins under GDPR data minimization compliance.

🌐 **Live Web Application**: **[https://erikwebb.github.io/gdpr-passport-masker/](https://erikwebb.github.io/gdpr-passport-masker/)**  
Part of the **[Erik Webb Tools Collection](https://erikwebb.github.io/)**.

---

## Why This Exists (GDPR Article 5.1(c))

Under **EU GDPR Article 5.1(c) (Data Minimization)** and official enforcement decisions across Europe (e.g. Spain's AEPD, Netherlands AP, and Italy's Garante):
- Accommodations are only legally authorized to record guest identity text details (Name, Date of Birth, Passport Number).
- **Accommodations are prohibited from collecting or storing unredacted photocopies or scans of passports**, as full scans contain sensitive biometric data (photographs, signatures, and raw MRZ codes).

This tool creates a secure, redacted, and watermarked document that prevents identity theft or secondary reuse.

---

## Features

- **100% Client-Side Privacy**: All processing runs in memory inside your browser using HTML5 Canvas. Zero images, scans, or text are ever transmitted across the network.
- **AI & OCR Friendly**: Watermarks use translucent red without harsh black borders, and document type headers (`PASSPORT`, `UNITED STATES OF AMERICA`, `P USA`) are kept unobstructed so automated verification systems (Onfido, Veriff, Jumio) recognize the document without error.
- **Universal Format Support**: Drag and drop standard images (PNG, JPG, WebP), iPhone camera photos (HEIC), and multi-page PDFs rendered at crisp 300 DPI scan resolution.
- **Intelligent Layout Auto-Detection**: Automatically detects two-page vertical passport spreads vs. single photo page crops from the aspect ratio.
- **Live Visual Inspection**: Real-time canvas preview and one-click download for high-resolution output.

---

## macOS CLI & Desktop Integration

For quick access directly from your terminal or Finder:

### Terminal CLI Mode

```bash
# Open the web application directly:
secure_passport

# Open and preload a specific scan and hotel name:
secure_passport /path/to/passport.jpg "Grand Hotel Berlin"
```

When provided with a file, `secure_passport` starts a lightweight ephemeral local bridge, preloads your scan into your default browser with the blacked-out MRZ and watermark ready, and gracefully exits.

### Quick Setup

```bash
# Link to your PATH:
ln -sf "$PWD/gdpr_passport_masker.sh" ~/bin/secure_passport
```

---

## Disclaimer

> [!WARNING]
> **Experimental / AI-Generated Tool**: This application is **100% LLM-generated** (created using Gemini / Antigravity). It is provided strictly on an "as-is" basis with **no promise or guarantee of quality, accuracy, reliability, or legal fitness**. Always review and verify your masked and watermarked documents manually prior to sharing them.

---

## License & Author

Created by [Erik Webb](https://erikwebb.github.io/) — Software Architect & Engineering Leader.  
Open source under the MIT License.
