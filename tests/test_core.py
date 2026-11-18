"""Tests use fabricated credentials only - never real Apple data."""

import io
import json
import subprocess
import tempfile
import unittest
import urllib.error
from pathlib import Path

from omnissa_beta_tokens import render
from omnissa_beta_tokens.abm import AbmError, BetaToken, fetch_beta_tokens, get_beta_tokens
from omnissa_beta_tokens.oauth import build_oauth_header, urlenc
from omnissa_beta_tokens.servertoken import (
    Credentials, ServerTokenError, decrypt_server_token, generate_keypair,
)

FAKE = {
    "consumer_key": "CK_FAKE", "consumer_secret": "CS_FAKE",
    "access_token": "AT_FAKE", "access_secret": "AS_FAKE",
    "access_token_expiry": "2099-01-01T00:00:00Z",
}


class FakeResp(io.BytesIO):
    def __init__(self, body: bytes, status: int = 200):
        super().__init__(body)
        self.status = status

    def __enter__(self):
        return self

    def __exit__(self, *a):
        return False


def opener_for(routes):
    def opener(req):
        status, body = routes[req.full_url]
        if status != 200:
            raise urllib.error.HTTPError(req.full_url, status, "err", {}, io.BytesIO(body))
        return FakeResp(body, status)
    return opener


class OAuthTests(unittest.TestCase):
    def test_urlenc(self):
        self.assertEqual(urlenc("a b/c~"), "a%20b%2Fc~")

    def test_header_deterministic(self):
        kw = dict(timestamp=1, nonce="n")
        a = build_oauth_header("GET", "https://x/y", "k", "cs", "t", "as", **kw)
        b = build_oauth_header("GET", "https://x/y", "k", "cs", "t", "as", **kw)
        self.assertEqual(a, b)
        self.assertTrue(a.startswith('OAuth realm="ADM",'))
        self.assertIn("oauth_signature=", a)
        self.assertNotIn("cs", a.replace("oauth_consumer_key", ""))  # secret not leaked


class ServerTokenTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.wd = Path(self.tmp.name) / "wd"

    def tearDown(self):
        self.tmp.cleanup()

    def _make_p7m(self, payload: bytes) -> Path:
        cert = self.wd / "mdm_public_cert.pem"
        out = self.wd / "fake.p7m"
        r = subprocess.run(
            ["openssl", "smime", "-encrypt", "-aes256", "-out", str(out), str(cert)],
            input=payload, capture_output=True,
        )
        self.assertEqual(r.returncode, 0, r.stderr)
        return out

    def test_keygen_perms_and_no_overwrite(self):
        key, _ = generate_keypair(self.wd)
        self.assertEqual(key.stat().st_mode & 0o777, 0o600)
        self.assertEqual(self.wd.stat().st_mode & 0o777, 0o700)
        with self.assertRaises(ServerTokenError):
            generate_keypair(self.wd)

    def test_decrypt_roundtrip(self):
        generate_keypair(self.wd)
        payload = b"-----BEGIN MESSAGE-----\n" + json.dumps(FAKE).encode() + b"\n-----END MESSAGE-----\n"
        creds = decrypt_server_token(self._make_p7m(payload), self.wd)
        self.assertEqual(creds.consumer_key, "CK_FAKE")
        self.assertNotIn("CS_FAKE", repr(creds))
        self.assertNotIn("AS_FAKE", repr(creds))

    def test_wrong_cert_fails(self):
        generate_keypair(self.wd)
        p7m = self._make_p7m(json.dumps(FAKE).encode())
        other = Path(self.tmp.name) / "other"
        generate_keypair(other)
        with self.assertRaises(ServerTokenError):
            decrypt_server_token(p7m, other)


class AbmTests(unittest.TestCase):
    creds = Credentials("ck", "cs", "at", "as")
    tokens_body = json.dumps({"betaEnrollmentTokens": [
        {"title": "macOS Test Beta", "os": "OSX", "token": "T" * 40},
        {"title": "iOS Test Beta", "os": "iOS", "token": "U" * 40},
    ]}).encode()

    def test_fetch_ok(self):
        from omnissa_beta_tokens import abm
        op = opener_for({
            abm.SESSION_URL: (200, b'{"auth_session_token":"S"}'),
            abm.TOKENS_URL: (200, self.tokens_body),
        })
        toks = fetch_beta_tokens(self.creds, op)
        self.assertEqual({t.os_display for t in toks}, {"macOS", "iOS"})
        self.assertNotIn("TTTT", repr(toks[0]))

    def test_seed_turned_off(self):
        from omnissa_beta_tokens import abm
        op = opener_for({abm.TOKENS_URL: (403, b'{"reason":"APPLE_SEED_FOR_IT_TURNED_OFF"}')})
        with self.assertRaises(AbmError) as cm:
            get_beta_tokens("S", op)
        self.assertIn("beta.apple.com/for-it", str(cm.exception))

    def test_session_failure(self):
        from omnissa_beta_tokens import abm
        op = opener_for({abm.SESSION_URL: (401, b"")})
        with self.assertRaises(AbmError):
            fetch_beta_tokens(self.creds, op)


class RenderTests(unittest.TestCase):
    toks = [BetaToken("macOS Test Beta", "OSX", "M" * 40), BetaToken("iOS Test Beta", "iOS", "I" * 40)]

    def test_table_masks_by_default(self):
        self.assertNotIn("M" * 40, render.to_table(self.toks))
        self.assertIn("M" * 40, render.to_table(self.toks, reveal=True))

    def test_filter(self):
        self.assertEqual(len(render.filter_tokens(self.toks, "macos", None)), 1)
        self.assertEqual(len(render.filter_tokens(self.toks, None, "ios")), 1)

    def test_declaration(self):
        d = json.loads(render.to_declaration(self.toks[0]))
        beta = d["Payload"]["Beta"]
        self.assertEqual(beta["ProgramEnrollment"], "Allowed")
        self.assertEqual(beta["RequireProgram"]["Token"], "M" * 40)
        d = json.loads(render.to_declaration(self.toks[0], "AlwaysOn", require=False))
        self.assertIn("OfferPrograms", d["Payload"]["Beta"])


if __name__ == "__main__":
    unittest.main()
