# omnissa-beta-tokens

Get Apple beta enrollment tokens (AppleSeed for IT) for use in a Workspace ONE
UEM declarative profile. Python 3.9+, no third-party dependencies, uses the
system `openssl`.

An Omnissa-maintained, improved version of the MIT-licensed upstream `betaTokens.sh`. See
`NOTICE` (upstream attribution) and `LICENSE`.

## Quick start

```bash
pip install -e .            # or: PYTHONPATH=src python3 -m omnissa_beta_tokens.cli
omnissa-beta-tokens init    # creates key + cert in ~/.omnissa-beta-tokens
# Apple Business > Devices > Management Services > Add > upload the .pem
# Download the .p7m server token, then:
omnissa-beta-tokens fetch --watch          # or --p7m /path/to/token.p7m
omnissa-beta-tokens fetch --os macOS --reveal
omnissa-beta-tokens fetch --match "macOS 27" --declaration
```

## Security

- OAuth secrets are never printed; they are shown as `[REDACTED]`.
- The decrypted server token is held in memory only (no `token.json` on disk).
- Work directory is mode 700, private key mode 600. `*.p7m`, `*.pem`, `*.key`
  are git-ignored.
- Beta tokens are masked in the table unless you pass `--reveal`. `--format
  json|csv` and `--declaration` always print full tokens because they are
  intended for export.
- Treat the `.p7m` and key as credentials. When finished, delete the
  management service in Apple Business and the local files.

## Notes

- Apple returns `OSX` for macOS; this tool displays `macOS`.
- Requires the organization to be enrolled in AppleSeed for IT
  (https://beta.apple.com/for-it); otherwise Apple returns 403
  `APPLE_SEED_FOR_IT_TURNED_OFF`.
- Tokens are per organization and per seeding period.

## Tests

```bash
PYTHONPATH=src python3 -m unittest discover -s tests -v
```

Tests use fabricated credentials only.

## Docs

- `docs/guide.md` - Workspace ONE enrollment guide (source for the branded HTML).
