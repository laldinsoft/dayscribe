# Security

DayScribe runs entirely on your Mac. The app itself contains no networking
code; the only downloads happen in `scripts/` at build time, from pinned
URLs, and are verified against SHA-256 checksums before use.

If you find a vulnerability, please open a GitHub security advisory for this
repository (Security → Report a vulnerability) rather than a public issue.
Include steps to reproduce and the affected version from
`Resources/Info.plist`.
