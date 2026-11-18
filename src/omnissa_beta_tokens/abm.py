"""Client for the Apple Business / Apple School Manager ADE web service."""

from __future__ import annotations

import json
import urllib.error
import urllib.request
from dataclasses import dataclass
from typing import Callable

from .oauth import build_oauth_header
from .servertoken import Credentials

BASE_URL = "https://mdmenrollment.apple.com"
SESSION_URL = f"{BASE_URL}/session"
TOKENS_URL = f"{BASE_URL}/os-beta-enrollment/tokens"

# Apple's API returns some legacy OS identifiers; map to friendly names.
OS_DISPLAY = {"OSX": "macOS", "homePodOS": "homePodOS"}


class AbmError(Exception):
    """Raised when the Apple web service returns an error."""


@dataclass(frozen=True)
class BetaToken:
    title: str
    os: str
    token: str

    @property
    def os_display(self) -> str:
        return OS_DISPLAY.get(self.os, self.os)

    def __repr__(self) -> str:
        return f"BetaToken(title={self.title!r}, os={self.os!r}, token=[REDACTED])"


Opener = Callable[[urllib.request.Request], "urllib.response.addinfourl"]


def _get(url: str, headers: dict[str, str], opener: Opener) -> tuple[int, bytes]:
    req = urllib.request.Request(url, headers=headers, method="GET")
    try:
        with opener(req) as resp:
            return resp.status, resp.read()
    except urllib.error.HTTPError as exc:
        return exc.code, exc.read()
    except urllib.error.URLError as exc:
        raise AbmError(f"Network error contacting Apple: {exc.reason}") from exc


def get_session_token(creds: Credentials, opener: Opener = urllib.request.urlopen) -> str:
    header = build_oauth_header(
        "GET", SESSION_URL,
        creds.consumer_key, creds.consumer_secret,
        creds.access_token, creds.access_secret,
    )
    status, body = _get(
        SESSION_URL, {"Authorization": header, "Accept": "application/json"}, opener
    )
    if status != 200:
        raise AbmError(
            f"Session request failed (HTTP {status}). The server token may be "
            "expired or revoked; generate a new one in Apple Business."
        )
    try:
        token = json.loads(body).get("auth_session_token")
    except ValueError:
        token = None
    if not token:
        raise AbmError("auth_session_token missing in session response.")
    return token


def get_beta_tokens(session_token: str, opener: Opener = urllib.request.urlopen) -> list[BetaToken]:
    status, body = _get(
        TOKENS_URL,
        {
            "X-ADM-Auth-Session": session_token,
            "X-Server-Protocol-Version": "1",
            "Accept": "application/json",
        },
        opener,
    )
    if status == 403 and b"APPLE_SEED_FOR_IT_TURNED_OFF" in body:
        raise AbmError(
            "Beta access is turned off for this organization "
            "(APPLE_SEED_FOR_IT_TURNED_OFF). Enroll the organization in "
            "AppleSeed for IT at https://beta.apple.com/for-it and retry."
        )
    if status != 200:
        raise AbmError(f"Beta token request failed (HTTP {status}).")
    try:
        items = json.loads(body)["betaEnrollmentTokens"]
        return [BetaToken(i["title"], i["os"], i["token"]) for i in items]
    except (ValueError, KeyError, TypeError) as exc:
        raise AbmError(f"Unexpected beta token response: {exc}") from exc


def fetch_beta_tokens(creds: Credentials, opener: Opener = urllib.request.urlopen) -> list[BetaToken]:
    return get_beta_tokens(get_session_token(creds, opener), opener)
