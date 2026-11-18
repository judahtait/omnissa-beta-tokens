# Omnissa Beta Token Utility (Rust)

Rust **CLI** (`omnissa-beta-tokens`) plus helper bins (`build-guide`, `make-icns`).
The macOS UI is the separate SwiftUI package under `../swift/` — build with
`../tools/make_app.sh`. Version is in `Cargo.toml`.

## Build / run

```bash
cd rust
cargo test
cargo build --release
./target/release/omnissa-beta-tokens --help
```

Or without installing:

```bash
cargo run --release -- init
cargo run --release -- fetch --watch
cargo run --release -- fetch --os macOS --match "Seed" --uem-block
cargo run --release -- cleanup --yes
```

## Subcommands

| Command | Purpose |
|---|---|
| `init` | Generate `mdm_private.key` + `mdm_public_cert.pem` under `--workdir` |
| `fetch` | Decrypt `.p7m`, list tokens (`--format table\|json\|csv`, `--reveal`, `--uem-block`) |
| `cleanup` | Delete key/cert/`*.p7m` in `--workdir` (requires `--yes`); reminds you to delete the ABM service |

`--uem-block` needs exactly one filtered program (`--os` / `--match`). It prints Title, Token, and Mode field guidance (Automatic / Offer / Offer-no-sign-in / Block) — not declaration JSON — and copies the block via `pbcopy` when available.

Default workdir: `~/.omnissa-beta-tokens`. Paths accept `~`.
