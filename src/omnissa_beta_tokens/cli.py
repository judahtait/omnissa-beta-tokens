"""Command line interface: omnissa-beta-tokens {init,fetch}."""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

from . import __version__, render
from .abm import AbmError, fetch_beta_tokens
from .servertoken import (
    CERT_NAME, ServerTokenError, decrypt_server_token, ensure_workdir,
    find_p7m, generate_keypair, mask,
)

DEFAULT_WORKDIR = Path("~/.omnissa-beta-tokens").expanduser()
APPLE_ADD_SERVICE_URL = "https://business.apple.com/main/devices/managementservices/mdmservers/add"
SERVICE_NAME = "Workspace One Beta Token Service"


def _copy_to_clipboard(text: str) -> bool:
    """Best effort (macOS pbcopy). Apple's form cannot be prefilled, so we put
    the service name on the clipboard for the user to paste."""
    try:
        subprocess.run(["pbcopy"], input=text.encode(), check=True, timeout=5)
        return True
    except (OSError, subprocess.SubprocessError):
        return False


INDIGO = "\x1b[38;2;74;18;240m"   # Omnissa indigo #4A12F0
SLATE = "\x1b[38;2;76;97;144m"    # Omnissa slate #4C6190
BOLD, RESET = "\x1b[1m", "\x1b[0m"


def _banner(enabled: bool) -> None:
    """Omnissa banner on stderr so stdout stays clean for JSON/CSV piping."""
    if not enabled:
        return
    color = sys.stderr.isatty() and "NO_COLOR" not in os.environ
    b, i, s, r = (BOLD, INDIGO, SLATE, RESET) if color else ("", "", "", "")
    print(
        f"{b}{i}OMNISSA{r}  {b}Beta Token Utility{r} v{__version__}\n"
        f"{s}Workspace ONE UEM - Apple beta enrollment tokens{r}\n",
        file=sys.stderr,
    )


def _err(msg: str) -> int:
    print(f"[ERROR] {msg}", file=sys.stderr)
    return 1


def cmd_init(args: argparse.Namespace) -> int:
    try:
        _, cert = generate_keypair(args.workdir)
    except ServerTokenError as exc:
        return _err(str(exc))
    print(f"[INFO] Created key and certificate in {args.workdir} (private key mode 600).")
    copied = " (copied to clipboard - paste it into the form)" if _copy_to_clipboard(SERVICE_NAME) else ""
    print(
        "\nNext steps in Apple Business:\n"
        f"  1. Devices > Management Services > Add\n     {APPLE_ADD_SERVICE_URL}\n"
        f"  2. Service Name: {SERVICE_NAME}{copied}\n"
        f"  3. Upload this file: {cert}\n"
        "  4. Download the .p7m server token\n"
        "  5. Run: omnissa-beta-tokens fetch\n"
    )
    return 0


def _watch_downloads(workdir: Path, interval: int) -> Path:
    downloads = Path("~/Downloads").expanduser()
    seen = set(downloads.glob("*.p7m"))
    print(f"[INFO] Watching {downloads} for a new .p7m (Ctrl+C to stop)...")
    while True:
        for f in downloads.glob("*.p7m"):
            if f not in seen:
                dest = workdir / f.name
                shutil.copy2(f, dest)
                dest.chmod(0o600)
                print(f"[INFO] Found {f.name}")
                return dest
        time.sleep(interval)


def cmd_fetch(args: argparse.Namespace) -> int:
    workdir = ensure_workdir(args.workdir)
    try:
        if not (workdir / CERT_NAME).exists():
            return _err(f"No key/cert in {workdir}. Run 'omnissa-beta-tokens init' first.")
        p7m = args.p7m or find_p7m(workdir)
        if p7m is None and args.watch:
            p7m = _watch_downloads(workdir, args.interval)
        if p7m is None:
            return _err("No .p7m found. Pass --p7m PATH, use --watch, or copy it into " + str(workdir))
        creds = decrypt_server_token(Path(p7m), workdir)
        print(f"[INFO] Server token read: {creds!r}", file=sys.stderr)
        tokens = render.filter_tokens(fetch_beta_tokens(creds), args.os, args.match)
    except (ServerTokenError, AbmError) as exc:
        return _err(str(exc))
    except KeyboardInterrupt:
        return _err("Interrupted.")

    if not tokens:
        return _err("No beta programs matched.")
    if args.declaration:
        if len(tokens) != 1:
            return _err(f"--declaration needs exactly one match; got {len(tokens)}. Narrow with --os/--match.")
        out = render.to_declaration(tokens[0], args.enrollment, not args.offer)
    elif args.format == "json":
        out = render.to_json(tokens)
    elif args.format == "csv":
        out = render.to_csv(tokens)
    else:
        out = render.to_table(tokens, reveal=args.reveal)
    print(out)
    return 0


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="omnissa-beta-tokens",
        description="Get Apple beta enrollment tokens for Workspace ONE UEM.",
    )
    p.add_argument("--version", action="version", version=__version__)
    p.add_argument("--no-banner", action="store_true", help="Do not print the Omnissa banner")
    p.add_argument("--workdir", type=lambda s: Path(s).expanduser(), default=DEFAULT_WORKDIR,
                   help=f"Key/cert/token directory (default: {DEFAULT_WORKDIR})")
    sub = p.add_subparsers(dest="command", required=True)

    sub.add_parser("init", help="Generate key + certificate to upload to Apple Business") \
        .set_defaults(func=cmd_init)

    f = sub.add_parser("fetch", help="Decrypt the .p7m and list beta tokens")
    f.add_argument("--p7m", type=lambda s: Path(s).expanduser(), help="Path to the .p7m server token")
    f.add_argument("--watch", action="store_true", help="Wait for a new .p7m in ~/Downloads")
    f.add_argument("--interval", type=int, default=5, help="Watch poll seconds (default 5)")
    f.add_argument("--os", help="Filter by OS (iOS, macOS, tvOS, watchOS, visionOS, homePodOS)")
    f.add_argument("--match", help="Filter by text in the program title")
    f.add_argument("--format", choices=["table", "json", "csv"], default="table")
    f.add_argument("--reveal", action="store_true", help="Show full tokens in the table (masked by default)")
    f.add_argument("--declaration", action="store_true", help="Emit a reference SoftwareUpdate Settings declaration for one program")
    f.add_argument("--enrollment", choices=["Allowed", "AlwaysOn", "AlwaysOff"], default="Allowed",
                   help="ProgramEnrollment value for --declaration (default Allowed)")
    f.add_argument("--offer", action="store_true", help="Use OfferPrograms instead of RequireProgram")
    f.set_defaults(func=cmd_fetch)
    return p


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    _banner(not args.no_banner)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
