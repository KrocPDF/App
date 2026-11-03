# Security Policy

## Supported Versions

We release patches and security fixes for the active version line of KrocPDF Mobile.

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |
| < 1.0   | :x:                |

---

## Privacy & Threat Model

KrocPDF operates primarily in **Confidential Mode**:
- Document processing, image conversion, and PDF operations occur **100% locally on-device**.
- No file data or scan outputs are transmitted over the network unless explicitly running in a user-consented cloud conversion mode.
- Local storage operations adhere to strict OS-scoped storage and sandboxing standards.

---

## Reporting a Vulnerability

If you discover a security vulnerability within KrocPDF, please report it privately:

1. **Do not open a public issue.**
2. Send an email to the security team at **security@krocpdf.com** (or reach out via GitHub Private Vulnerability Reporting under the Security tab of the repository).
3. Include the following details:
   - Type of vulnerability (e.g., local storage data leakage, insecure permission escalation, dependency CVE).
   - Step-by-step reproduction instructions or a minimal Proof of Concept (PoC).
   - Affected device environment (OS version, device model, app version).

### Response SLA
- **Initial Response:** Within 48 hours.
- **Triage & Assessment:** Within 5 business days.
- **Fix & Public Disclosure:** Coordinated release date once a remediation patch has been verified.

