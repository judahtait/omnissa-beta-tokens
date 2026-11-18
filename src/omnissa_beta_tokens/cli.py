"""Command line interface: omnissa-beta-tokens {init,fetch,cleanup}."""

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
    CERT_NAME,
    KEY_NAME,
    ServerTokenError,
    access_token_expired,
    decrypt_server_token,
    ensure_workdir,
    find_p7m,
    generate_keypair,
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


def _warn(msg: str) -> None:
    print(f"[WARNING] {msg}", file=sys.stderr)


def _info(msg: str) -> None:
    print(f"[INFO] {msg}", file=sys.stderr)


def cmd_init(args: argparse.Namespace) -> int:
    try:
        _, cert = generate_keypair(args.workdir)
    except ServerTokenError as exc:
        return _err(str(exc))
    _info(f"Created key and certificate in {args.workdir} (private key mode 600).")
    copied = " (copied to clipboard - paste it into the form)" if _copy_to_clipboard(SERVICE_NAME) else ""
    # Echo --workdir when it is not the default, so the next command looks in the right place.
    workdir_opt = "" if args.workdir == DEFAULT_WORKDIR else f"--workdir {args.workdir} "
    print(
        "\nNext steps in Apple Business:\n"
        f"  1. Devices > Management Services > Add\n     {APPLE_ADD_SERVICE_URL}\n"
        f"  2. Service Name: {SERVICE_NAME}{copied}\n"
        f"  3. Upload this file: {cert}\n"
        "  4. Download the .p7m server token\n"
        f"  5. Run: omnissa-beta-tokens {workdir_opt}fetch --watch\n",
        file=sys.stderr,
    )
    return 0


def _watch_downloads(workdir: Path, interval: int) -> Path:
    downloads = Path("~/Downloads").expanduser()
    seen = set(downloads.glob("*.p7m"))
    _info(f"Watching {downloads} for a new .p7m (Ctrl+C to stop)...")
    while True:
        for f in downloads.glob("*.p7m"):
            if f not in seen:
                dest = workdir / f.name
                shutil.copy2(f, dest)
                dest.chmod(0o600)
                _info(f"Found {f.name}")
                return dest
        time.sleep(interval)


def _cleanup_targets(workdir: Path) -> list[Path]:
    """Key, cert, and *.p7m under workdir (existing files only)."""
    targets: list[Path] = []
    for name in (KEY_NAME, CERT_NAME):
        path = workdir / name
        if path.is_file():
            targets.append(path)
    targets.extend(sorted(p for p in workdir.glob("*.p7m") if p.is_file()))
    return targets


def cmd_cleanup(args: argparse.Namespace) -> int:
    workdir = args.workdir
    if not workdir.is_dir():
        return _err(f"Workdir does not exist: {workdir}")
    targets = _cleanup_targets(workdir)
    if not targets:
        return _err(f"Nothing to delete in {workdir} (no key/cert/*.p7m).")
    if not args.yes:
        if not sys.stdin.isatty():
            return _err("Refusing cleanup without --yes (non-interactive terminal).")
        print(f"About to delete {len(targets)} file(s) in {workdir}:", file=sys.stderr)
        for path in targets:
            print(f"  {path.name}", file=sys.stderr)
        try:
            reply = input("Type yes to confirm: ")
        except EOFError:
            return _err("Cleanup cancelled.")
        if reply.strip().lower() != "yes":
            return _err("Cleanup cancelled.")
    for path in targets:
        path.unlink()
        _info(f"Deleted {path}")
    print(
        "\nReminder: also delete the management service in Apple Business\n"
        f"  (Devices > Management Services — typically '{SERVICE_NAME}').\n"
        "Local key/cert/*.p7m are gone; the ABM service is not removed by this tool.\n",
        file=sys.stderr,
    )
    return 0


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
        if access_token_expired(creds):
            _warn(
                "Server token access_token_expiry is in the past. "
                "Regenerate the server token in Apple Business and retry."
            )
        _info(f"Server token read: {creds!r}")
        tokens = render.filter_tokens(fetch_beta_tokens(creds), args.os, args.match)
    except (ServerTokenError, AbmError) as exc:
        return _err(str(exc))
    except KeyboardInterrupt:
        return _err("Interrupted.")

    if not tokens:
        return _err("No beta programs matched.")

    unsupported = render.unsupported_uem_beta_oses(tokens)
    if unsupported:
        labels = ", ".join(unsupported)
        _warn(
            f"UEM Software Update:Settings > Beta cannot deliver {labels}. "
            "Those platforms are not applicable for this setting."
        )

    if args.format == "json":
        out = render.to_json(tokens)
    elif args.format == "csv":
        out = render.to_csv(tokens)
    else:
        out = render.to_table(tokens, reveal=args.reveal)
    print(out)

    if args.uem_block:
        if len(tokens) != 1:
            return _err(
                f"--uem-block needs exactly one program; got {len(tokens)}. "
                "Narrow with --os and/or --match."
            )
        block = render.uem_paste_block(tokens[0])
        print()
        print(block)
        if _copy_to_clipboard(block):
            _info("UEM paste block copied to clipboard.")
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
    f.add_argument(
        "--uem-block",
        action="store_true",
        help="Print a UEM paste block (Title/Token/Mode checklist) for exactly one matched program",
    )
    f.set_defaults(func=cmd_fetch)

    c = sub.add_parser("cleanup", help="Delete local key/cert/*.p7m under --workdir")
    c.add_argument(
        "--yes",
        action="store_true",
        help="Skip confirmation (required when stdin is not a TTY)",
    )
    c.set_defaults(func=cmd_cleanup)
    return p


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    _banner(not args.no_banner)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
