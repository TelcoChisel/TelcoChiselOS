# Official Homebrew Tap for TelcoSec Tools

This is the official [Homebrew](https://brew.sh/) tap for the **TelcoSec** ecosystem, providing native packages and command-line utilities for telecommunications security research, cellular core orchestration, software-defined radio diagnostics, and smartcard analysis across **macOS** (Apple Silicon & Intel) and **Linux**.

---

## Quickstart & Installation

### Option 1: Tap and Install

```bash
# 1. Tap the official repository
brew tap telcochisel/tap

# 2. Install telcosec
brew install telcosec
```

### Option 2: Single-Line Direct Installation

```bash
brew install telcochisel/tap/telcosec
```

### Option 3: Bleeding-Edge Build from Trunk (`HEAD`)

To compile the latest unreleased developments directly from the `main` branch of `telcosec-cli`:

```bash
brew install --HEAD telcochisel/tap/telcosec
```

---

## Available Formulas

| Formula | Description | Status |
| :--- | :--- | :--- |
| **`telcosec`** | Unified Operator CLI for Telecom Security, SDR Diagnostics, 10GbE SFP+ Tuning, and 5G Core Operations | Stable `v2026.2` |
| **`telcochisel`** | Canonical alias for `telcosec` | Stable `v2026.2` |

---

## What `telcosec` Provides

The `telcosec` formula compiles a zero-dependency static Mach-O (macOS) or ELF (Linux) binary and automatically installs:
- **`telcosec`** and **`telcochisel`** binaries in `$(brew --prefix)/bin`
- **Shell Autocompletions**:
  - **Bash**: `$(brew --prefix)/etc/bash_completion.d/telcosec`
  - **Zsh**: `$(brew --prefix)/share/zsh/site-functions/_telcosec`
  - **Fish**: `$(brew --prefix)/share/fish/vendor_completions.d/telcosec.fish`
- **Section 1 UNIX Manual Pages**:
  - `man telcosec` and `man telcochisel` in `$(brew --prefix)/share/man/man1`

---

## Verification & Usage

Verify your installation:

```bash
telcosec version
telcosec check
telcosec pkg repo status
telcosec sim atr 3B9F95801FC78031E073FE211B674A4C7380110043
```

---

## Updating & Maintenance

To update `telcosec` to the latest release:

```bash
brew update
brew upgrade telcosec
```

To remove:

```bash
brew uninstall telcosec
brew untap telcochisel/tap
```

---

## Automated Formula Bumping

Formula updates are automated via GitHub Actions:
- Whenever a new tag (e.g. `v3.0.1`) is published in [`telcosec-cli`](https://github.com/TelcoChisel/telcosec-cli), the release pipeline dispatches a `bump-formula` event to this tap.
- Maintainers can also trigger an automated bump on-demand via the GitHub CLI:
  ```bash
  gh workflow run bump.yml --repo TelcoChisel/homebrew-tap -f version=v3.0.1
  ```
- The workflow automatically fetches the release archive, computes and verifies the SHA256 checksum, updates `Formula/telcosec.rb`, runs `brew test-bot --only-tap-syntax` for audit compliance, and commits directly to `main`.

---

## Documentation & Upstream Repositories

- **TelcoChisel OS Documentation Portal**: [https://telcochisel.com](https://telcochisel.com)
- **Official Metapackage CDN**: [https://meta.telcosec.net](https://meta.telcosec.net)
- **Operator CLI Source Code**: [https://github.com/TelcoChisel/telcosec-cli](https://github.com/TelcoChisel/telcosec-cli)
- **TelcoChisel OS Distribution**: [https://github.com/TelcoChisel/TelcoChiselOS](https://github.com/TelcoChisel/TelcoChiselOS)
- **TelcoChisel Organization**: [https://github.com/TelcoChisel](https://github.com/TelcoChisel)

## License

Apache License 2.0. See [LICENSE](LICENSE) for full details.
