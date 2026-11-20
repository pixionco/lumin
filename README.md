# Lumin CLI

`lumin` is the command-line tool for [Lumin](https://lumintest.com): it connects a test repository to a Lumin
project, keeps generated test code in sync with the spec, runs Lumin test runs with the repository's own test command
(locally and in CI) and reports the results.

This repository distributes `lumin`: release binaries, install scripts and the GitHub Action. The CLI is a
self-contained executable; nothing else (no .NET, Node or Python) needs to be installed.

## Install

| Channel | Platform | Install | Version |
|---|---|---|---|
| Install script | Linux, macOS | `curl -fsSL https://raw.githubusercontent.com/pixionco/lumin/master/install.sh \| sh` | ![release](https://img.shields.io/github/v/release/pixionco/lumin) |
| Install script | Windows | `irm https://raw.githubusercontent.com/pixionco/lumin/master/install.ps1 \| iex` | ![release](https://img.shields.io/github/v/release/pixionco/lumin) |
| Homebrew | macOS, Linux | `brew install pixionco/tap/lumin-cli` | ![release](https://img.shields.io/github/v/release/pixionco/lumin) |
| Scoop | Windows | `scoop bucket add pixionco https://github.com/pixionco/scoop-bucket`, then `scoop install pixionco/lumin-cli` | ![scoop](https://img.shields.io/scoop/v/lumin-cli?bucket=https://github.com/pixionco/scoop-bucket) |
| GitHub Action | CI | `uses: pixionco/lumin@v1` ([below](#github-actions)) | ![release](https://img.shields.io/github/v/release/pixionco/lumin) |
| Manual | all | [Releases](https://github.com/pixionco/lumin/releases) + `SHA256SUMS` | ![release](https://img.shields.io/github/v/release/pixionco/lumin) |

Package managers that review every version can lag behind a release; the install scripts always get the newest one.

**Linux, macOS** (and Git Bash on Windows):

```sh
curl -fsSL https://raw.githubusercontent.com/pixionco/lumin/master/install.sh | sh
```

Installs into `~/.lumin/bin`. Options: `--version 1.2.0`, `--install-dir DIR` (or `LUMIN_VERSION`, `LUMIN_INSTALL_DIR`).

**Windows** (PowerShell):

```powershell
irm https://raw.githubusercontent.com/pixionco/lumin/master/install.ps1 | iex
```

Installs into `%LOCALAPPDATA%\Programs\lumin` and adds it to your user `PATH`. With options:
`& ([scriptblock]::Create((irm https://raw.githubusercontent.com/pixionco/lumin/master/install.ps1))) -Version 1.2.0`.

**Homebrew** (macOS, Linux):

```sh
brew install pixionco/tap/lumin-cli
```

**Scoop** (Windows, no admin rights needed):

```powershell
scoop bucket add pixionco https://github.com/pixionco/scoop-bucket
scoop install pixionco/lumin-cli
```

A package manager owns its install, so update with it (`brew upgrade lumin-cli`, `scoop update lumin-cli`, ...);
`lumin upgrade` prints the right command.

**Manually:** download the archive for your platform from [Releases](https://github.com/pixionco/lumin/releases),
check it against `SHA256SUMS` and put `lumin` (`lumin.exe`) on your `PATH`. Windows binaries are code-signed by
PIXION d.o.o. (from v0.2.0).

Both scripts verify the archive against `SHA256SUMS` before installing. To install from a mirror or proxy holding the
same release assets, set `LUMIN_DOWNLOAD_URL` to its base URL.

| Platform | Archive |
|----------|---------|
| Linux x64 / arm64 (glibc) | `lumin-linux-x64.tar.gz`, `lumin-linux-arm64.tar.gz` |
| macOS Apple silicon / Intel | `lumin-osx-arm64.tar.gz`, `lumin-osx-x64.tar.gz` |
| Windows x64 / arm64 | `lumin-win-x64.zip`, `lumin-win-arm64.zip` |

The installers verify every download against the release's `SHA256SUMS`. Asset names carry no version, so
`https://github.com/pixionco/lumin/releases/latest/download/lumin-linux-x64.tar.gz` always points at the newest
release.

**Verify a download.** Releases are immutable and GitHub signs an attestation of every asset when the release is
published. With the [GitHub CLI](https://cli.github.com):

```sh
gh release verify-asset v1.2.0 lumin-linux-x64.tar.gz --repo pixionco/lumin
```

## GitHub Actions

```yaml
- uses: pixionco/lumin@v1          # newest 1.x; pin @v1.2.3 for an exact version
  with:
    labels: smoke                  # create a test run from these labels and run it
  env:
    LUMIN_TOKEN: ${{ secrets.LUMIN_TOKEN }}
```

Without `test-run` or `labels` the action only installs `lumin` and adds it to `PATH`, so later steps can call any
command (`- run: lumin sync --check`).

| Input | Meaning |
|---|---|
| `version` | `1.2.0` or `latest`; default: follows the action ref (`@v1` → newest 1.x) |
| `test-run` | run this existing test run (`lumin run --test-run`) |
| `labels` | create a test run from scenarios with these labels and run it (`lumin run --create --labels`) |
| `run-name` | name of the created test run |
| `fail-on` | outcomes that fail the step: `failed` (default) or `failed,pending` |
| `args` | extra `lumin run` arguments, e.g. `--timeout 30m` |
| `working-directory` | where to run (the directory with `lumin.json`); default `.` |

Output: `version` (the installed version).

## Usage

```sh
lumin auth login                       # sign in (CI uses LUMIN_TOKEN instead)
lumin init SHOP --profile web          # connect this repository to a Lumin project
lumin sync                             # regenerate generated files from the latest spec
lumin run --create --labels smoke      # plan, run the repository's test command, upload the results
lumin --help                           # every command and option
```

Every command accepts `--json` for machine-readable output. Exit codes are stable: `0` success · `1` tests failed ·
`2` usage or configuration · `3` repository out of date · `4` authentication or permission · `5` test process
crashed · `6` server or network · `7` timeout.

## Support

Report problems with installation or the CLI in [Issues](https://github.com/pixionco/lumin/issues).
