"""OAuth 1.0a (HMAC-SHA1) header builder for Apple's /session endpoint."""

from __future__ import annotations

import base64
import hashlib
import hmac
import secrets
import time
from urllib.parse import quote

REALM = "ADM"


def urlenc(value: str) -> str:
    """RFC 3986 percent-encoding (unreserved: A-Z a-z 0-9 - . _ ~)."""
    return quote(value, safe="-._~")


def build_oauth_header(
    method: str,
    url: str,
    consumer_key: str,
    consumer_secret: str,
    access_token: str,
    access_secret: str,
    *,
    timestamp: int | None = None,
    nonce: str | None = None,
) -> str:
    """Return the Authorization header value for an OAuth 1.0a signed request."""
    params = {
        "oauth_consumer_key": consumer_key,
        "oauth_nonce": nonce or secrets.token_hex(8),
        "oauth_signature_method": "HMAC-SHA1",
        "oauth_timestamp": str(timestamp if timestamp is not None else int(time.time())),
        "oauth_token": access_token,
        "oauth_version": "1.0",
    }
    param_string = "&".join(
        f"{urlenc(k)}={urlenc(v)}" for k, v in sorted(params.items())
    )
    base_string = "&".join(
        [urlenc(method.upper()), urlenc(url), urlenc(param_string)]
    )
    signing_key = f"{urlenc(consumer_secret)}&{urlenc(access_secret)}"
    digest = hmac.new(
        signing_key.encode(), base_string.encode(), hashlib.sha1
    ).digest()
    params["oauth_signature"] = base64.b64encode(digest).decode()

    parts = ",".join(f'{k}="{urlenc(v)}"' for k, v in params.items())
    return f'OAuth realm="{REALM}",{parts}'
