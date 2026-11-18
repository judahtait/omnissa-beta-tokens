"""Tests use fabricated credentials only - never real Apple data."""

import io
import json
import subprocess
import tempfile
import unittest
import urllib.error
from datetime import datetime, timezone
from pathlib import Path
from unittest import mock

from omnissa_beta_tokens import render
from omnissa_beta_tokens.abm import AbmError, BetaToken, fetch_beta_tokens, get_beta_tokens
from omnissa_beta_tokens.oauth import build_oauth_header, urlenc
from omnissa_beta_tokens.servertoken import (
    CERT_NAME,
    KEY_NAME,
    Credentials,
    ServerTokenError,
    access_token_expired,
    decrypt_server_token,
    generate_keypair,
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

    def test_json_and_csv_include_tokens(self):
        data = json.loads(render.to_json(self.toks))
        self.assertEqual(data[0]["token"], "M" * 40)
        self.assertIn("M" * 40, render.to_csv(self.toks))

    def test_uem_paste_block_is_guidance_not_json(self):
        block = render.uem_paste_block(self.toks[0])
        self.assertIn("Title: macOS Test Beta", block)
        self.assertIn("Token: " + "M" * 40, block)
        self.assertIn("auto", block)
        self.assertIn("offer-always-on", block)
        self.assertIn("AlwaysOn", block)
        self.assertNotIn("{", block)
        self.assertNotIn("com.apple.configuration", block)

    def test_unsupported_uem_beta_oses(self):
        mixed = self.toks + [
            BetaToken("tvOS Seed", "tvOS", "V" * 40),
            BetaToken("visionOS Seed", "visionOS", "W" * 40),
        ]
        self.assertEqual(render.unsupported_uem_beta_oses(self.toks), [])
        self.assertEqual(render.unsupported_uem_beta_oses(mixed), ["tvOS", "visionOS"])


class ExpiryTests(unittest.TestCase):
    def test_expired_and_future(self):
        past = Credentials("ck", "cs", "at", "as", access_token_expiry="2020-01-01T00:00:00Z")
        future = Credentials("ck", "cs", "at", "as", access_token_expiry="2099-01-01T00:00:00Z")
        empty = Credentials("ck", "cs", "at", "as", access_token_expiry="")
        now = datetime(2024, 6, 1, tzinfo=timezone.utc)
        self.assertTrue(access_token_expired(past, now=now))
        self.assertFalse(access_token_expired(future, now=now))
        self.assertFalse(access_token_expired(empty, now=now))


class CleanupCliTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.wd = Path(self.tmp.name) / "wd"

    def tearDown(self):
        self.tmp.cleanup()

    def test_cleanup_requires_yes_when_non_tty(self):
        from omnissa_beta_tokens import cli

        generate_keypair(self.wd)
        (self.wd / "fake.p7m").write_bytes(b"not-a-real-token")
        with mock.patch.object(cli.sys.stdin, "isatty", return_value=False):
            code = cli.main(["--no-banner", "--workdir", str(self.wd), "cleanup"])
        self.assertEqual(code, 1)
        self.assertTrue((self.wd / KEY_NAME).exists())

    def test_cleanup_yes_deletes_and_reminds(self):
        from omnissa_beta_tokens import cli

        generate_keypair(self.wd)
        p7m = self.wd / "fake.p7m"
        p7m.write_bytes(b"not-a-real-token")
        err = io.StringIO()
        with mock.patch.object(cli.sys, "stderr", err):
            code = cli.main(["--no-banner", "--workdir", str(self.wd), "cleanup", "--yes"])
        self.assertEqual(code, 0)
        self.assertFalse((self.wd / KEY_NAME).exists())
        self.assertFalse((self.wd / CERT_NAME).exists())
        self.assertFalse(p7m.exists())
        self.assertIn("management service", err.getvalue())

    def test_cleanup_missing_workdir(self):
        from omnissa_beta_tokens import cli

        missing = self.wd / "missing"
        code = cli.main(["--no-banner", "--workdir", str(missing), "cleanup", "--yes"])
        self.assertEqual(code, 1)


class FetchCliTests(unittest.TestCase):
    toks = [
        BetaToken("macOS Test Beta", "OSX", "M" * 40),
        BetaToken("tvOS Seed", "tvOS", "V" * 40),
    ]

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.wd = Path(self.tmp.name) / "wd"
        generate_keypair(self.wd)
        (self.wd / "fake.p7m").write_bytes(b"not-a-real-token")

    def tearDown(self):
        self.tmp.cleanup()

    def _run_fetch(self, *extra, tokens=None, expiry="2099-01-01T00:00:00Z"):
        from omnissa_beta_tokens import cli

        creds = Credentials("ck", "cs", "at", "as", access_token_expiry=expiry)
        err, out = io.StringIO(), io.StringIO()
        with mock.patch.object(cli, "decrypt_server_token", return_value=creds), \
             mock.patch.object(cli, "fetch_beta_tokens", return_value=tokens if tokens is not None else self.toks), \
             mock.patch.object(cli, "_copy_to_clipboard", return_value=True), \
             mock.patch.object(cli.sys, "stderr", err), \
             mock.patch.object(cli.sys, "stdout", out):
            code = cli.main(["--no-banner", "--workdir", str(self.wd), "fetch", *extra])
        return code, out.getvalue(), err.getvalue()

    def test_uem_block_errors_on_multiple(self):
        code, out, err = self._run_fetch("--uem-block")
        self.assertEqual(code, 1)
        self.assertIn("exactly one program", err)
        self.assertIn("tvOS", err)
        self.assertIn("macOS Test Beta", out)

    def test_uem_block_single_match_copies(self):
        code, out, err = self._run_fetch("--match", "macOS", "--uem-block")
        self.assertEqual(code, 0)
        self.assertIn("Title: macOS Test Beta", out)
        self.assertIn("Token: " + "M" * 40, out)
        self.assertIn("offer-always-on", out)
        self.assertIn("copied to clipboard", err)
        self.assertNotIn("tvOS", err)

    def test_expired_access_token_warns(self):
        code, _out, err = self._run_fetch("--match", "macOS", expiry="2020-01-01T00:00:00Z")
        self.assertEqual(code, 0)
        self.assertIn("access_token_expiry is in the past", err)


class ServiceNameTests(unittest.TestCase):
    def test_default_service_name(self):
        from omnissa_beta_tokens.cli import SERVICE_NAME
        self.assertEqual(SERVICE_NAME, "Workspace One Beta Token Service")
