"""Key/cert generation and decryption of the Apple Business server token (.p7m).

Uses the system `openssl` binary so the core stays dependency-free. Decrypted
content is held in memory only; it is never written to disk.
"""

from __future__ import annotations

import base64
import json
import os
import re
import subprocess
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path

KEY_NAME = "mdm_private.key"
CERT_NAME = "mdm_public_cert.pem"
CERT_CN = "Omnissa Beta Token Utility"


class ServerTokenError(Exception):
    """Raised for any problem generating keys or reading the server token."""


def mask(value: str, keep: int = 4) -> str:
    """Mask a secret for display, keeping only the last few characters."""
    if len(value) <= keep:
        return "[REDACTED]"
    return f"[REDACTED]...{value[-keep:]}"


def parse_access_token_expiry(value: str) -> datetime | None:
    """Parse Apple's access_token_expiry (ISO-8601, often with trailing Z)."""
    text = (value or "").strip()
    if not text:
        return None
    if text.endswith("Z"):
        text = text[:-1] + "+00:00"
    try:
        dt = datetime.fromisoformat(text)
    except ValueError:
        return None
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt


def access_token_expired(creds: Credentials, now: datetime | None = None) -> bool:
    """True when access_token_expiry is present and strictly before now (UTC)."""
    expiry = parse_access_token_expiry(creds.access_token_expiry)
    if expiry is None:
        return False
    current = now or datetime.now(timezone.utc)
    if current.tzinfo is None:
        current = current.replace(tzinfo=timezone.utc)
    return expiry < current


@dataclass(frozen=True)
class Credentials:
    consumer_key: str
    consumer_secret: str
    access_token: str
    access_secret: str
    access_token_expiry: str = ""

    def __repr__(self) -> str:  # never leak secrets via logging/tracebacks
        return (
            f"Credentials(consumer_key={mask(self.consumer_key)}, "
            f"access_token={mask(self.access_token)}, "
            f"expiry={self.access_token_expiry!r}, secrets=[REDACTED])"
        )


def _openssl_bin() -> str:
    """Prefer a fixed system path so PATH hijacks cannot substitute openssl."""
    for path in ("/usr/bin/openssl", "/opt/homebrew/bin/openssl"):
        if os.path.isfile(path) and os.access(path, os.X_OK):
            return path
    return "openssl"


def _run(cmd: list[str], **kw) -> subprocess.CompletedProcess:
    try:
        return subprocess.run(cmd, capture_output=True, check=False, **kw)
    except FileNotFoundError as exc:
        raise ServerTokenError(f"'{cmd[0]}' not found") from exc


def ensure_workdir(workdir: Path) -> Path:
    workdir.mkdir(mode=0o700, parents=True, exist_ok=True)
    os.chmod(workdir, 0o700)
    return workdir


def generate_keypair(workdir: Path, days: int = 365) -> tuple[Path, Path]:
    """Create the private key and self-signed cert to upload to Apple Business."""
    ensure_workdir(workdir)
    key, cert = workdir / KEY_NAME, workdir / CERT_NAME
    if key.exists() or cert.exists():
        raise ServerTokenError(
            f"{key.name}/{cert.name} already exist in {workdir}; "
            "refusing to overwrite. Remove them to start over."
        )
    openssl = _openssl_bin()
    old_umask = os.umask(0o177)
    try:
        res = _run(
            [
                openssl, "req", "-x509", "-newkey", "rsa:2048", "-nodes",
                "-sha256",
                "-keyout", str(key), "-out", str(cert),
                "-days", str(days), "-subj", f"/CN={CERT_CN}",
            ]
        )
    finally:
        os.umask(old_umask)
    if res.returncode != 0:
        raise ServerTokenError(f"openssl failed: {res.stderr.decode(errors='replace')}")
    os.chmod(key, 0o600)
    return key, cert


def find_p7m(workdir: Path) -> Path | None:
    """Newest *.p7m in workdir, or None."""
    files = sorted(workdir.glob("*.p7m"), key=lambda p: p.stat().st_mtime)
    return files[-1] if files else None


def decrypt_server_token(p7m: Path, workdir: Path) -> Credentials:
    """Decrypt the .p7m with the generated key and parse the OAuth credentials."""
    key, cert = workdir / KEY_NAME, workdir / CERT_NAME
    for f in (p7m, key, cert):
        if not f.is_file():
            raise ServerTokenError(f"Missing file: {f}")

    base = [
        _openssl_bin(), "smime", "-decrypt", "-recip", str(cert), "-inkey", str(key),
    ]
    res = _run(base + ["-inform", "SMIME", "-in", str(p7m)])
    if res.returncode != 0:
        # Fallback used by the original Microsoft script: drop the 5 S/MIME
        # header lines, base64-decode to DER, decrypt from stdin.
        try:
            lines = p7m.read_text(errors="replace").splitlines()[5:]
            der = base64.b64decode("".join(lines))
        except (ValueError, OSError):
            der = b""
        if der:
            res = _run(base + ["-inform", "DER"], input=der)
    if res.returncode != 0:
        raise ServerTokenError(
            "Failed to decrypt the .p7m. Does it match the PEM that was "
            "uploaded to Apple Business?"
        )
    match = re.search(rb"\{.*\}", res.stdout, re.DOTALL)
    if not match:
        raise ServerTokenError("No JSON payload found in decrypted server token.")
    try:
        data = json.loads(match.group(0))
        return Credentials(
            consumer_key=data["consumer_key"],
            consumer_secret=data["consumer_secret"],
            access_token=data["access_token"],
            access_secret=data["access_secret"],
            access_token_expiry=data.get("access_token_expiry", ""),
        )
    except (ValueError, KeyError) as exc:
        raise ServerTokenError(f"Server token payload is malformed: {exc}") from exc
