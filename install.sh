#!/bin/sh
# Install the Lumin CLI (`lumin`) on Linux, macOS or Windows (Git Bash) from https://github.com/pixionco/lumin.
#
#   curl -fsSL https://raw.githubusercontent.com/pixionco/lumin/master/install.sh | sh
#   curl -fsSL https://raw.githubusercontent.com/pixionco/lumin/master/install.sh | sh -s -- --version 1.2.0
#
# Options (or environment variables):
#   --version VERSION     release to install, e.g. 1.2.0 (LUMIN_VERSION; default: latest)
#   --install-dir DIR     where to put the executable (LUMIN_INSTALL_DIR; default: ~/.lumin/bin)
#   LUMIN_DOWNLOAD_URL    base URL of the release assets instead of GitHub (a mirror or proxy)
#
# The archive's SHA-256 is checked against the release's SHA256SUMS before anything is installed.
set -eu

repo="pixionco/lumin"
version="${LUMIN_VERSION:-latest}"
install_dir="${LUMIN_INSTALL_DIR:-$HOME/.lumin/bin}"

fail() {
  echo "lumin install: $*" >&2
  exit 1
}

while [ $# -gt 0 ]; do
  case "$1" in
    --version) [ $# -ge 2 ] || fail "--version needs a value"; version="$2"; shift 2 ;;
    --version=*) version="${1#*=}"; shift ;;
    --install-dir) [ $# -ge 2 ] || fail "--install-dir needs a value"; install_dir="$2"; shift 2 ;;
    --install-dir=*) install_dir="${1#*=}"; shift ;;
    -h | --help)
      echo "Usage: install.sh [--version VERSION] [--install-dir DIR]"
      echo "Installs lumin from https://github.com/$repo/releases (default: latest, into ~/.lumin/bin)."
      exit 0 ;;
    *) fail "unknown option: $1 (see --help)" ;;
  esac
done

os=$(uname -s)
arch=$(uname -m)
case "$os" in
  Linux)
    if ldd --version 2>&1 | grep -qi musl; then
      fail "musl-based Linux (e.g. Alpine) is not supported yet; use a glibc-based image"
    fi
    os=linux ;;
  Darwin) os=osx ;;
  MINGW* | MSYS* | CYGWIN*) os=win ;;
  *) fail "unsupported operating system: $os" ;;
esac
# Emulated shells (x64 Git Bash on Windows ARM, Rosetta on Apple silicon) report x86_64; ask the OS instead.
if [ "$os" = win ]; then
  case "${PROCESSOR_IDENTIFIER:-}" in
    ARM*) arch=arm64 ;;
    *) arch="${PROCESSOR_ARCHITEW6432:-${PROCESSOR_ARCHITECTURE:-$arch}}" ;;
  esac
elif [ "$os" = osx ] && [ "$(sysctl -n hw.optional.arm64 2>/dev/null)" = 1 ]; then
  arch=arm64
fi
case "$arch" in
  x86_64 | amd64 | AMD64) arch=x64 ;;
  arm64 | aarch64 | ARM64) arch=arm64 ;;
  *) fail "unsupported architecture: $arch" ;;
esac
rid="$os-$arch"

if [ "$os" = win ]; then
  archive="lumin-$rid.zip"
  exe="lumin.exe"
else
  archive="lumin-$rid.tar.gz"
  exe="lumin"
fi

version="${version#v}"
if [ -n "${LUMIN_DOWNLOAD_URL:-}" ]; then
  base="${LUMIN_DOWNLOAD_URL%/}"
elif [ "$version" = latest ]; then
  base="https://github.com/$repo/releases/latest/download"
else
  base="https://github.com/$repo/releases/download/v$version"
fi

download() {
  if command -v curl > /dev/null 2>&1; then
    curl -fsSL --retry 3 -o "$2" "$1"
  elif command -v wget > /dev/null 2>&1; then
    wget -q -O "$2" "$1"
  else
    fail "curl or wget is required"
  fi
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT INT TERM

echo "Downloading $base/$archive"
download "$base/$archive" "$tmp/$archive" || fail "could not download $base/$archive"
download "$base/SHA256SUMS" "$tmp/SHA256SUMS" || fail "could not download $base/SHA256SUMS"

expected=$(awk -v f="$archive" '{ sub(/\r$/, "") } $2 == f || $2 == "*" f { print tolower($1) }' "$tmp/SHA256SUMS")
[ -n "$expected" ] || fail "$archive is not listed in SHA256SUMS"
if command -v sha256sum > /dev/null 2>&1; then
  actual=$(sha256sum "$tmp/$archive" | awk '{ print $1 }')
elif command -v shasum > /dev/null 2>&1; then
  actual=$(shasum -a 256 "$tmp/$archive" | awk '{ print $1 }')
else
  fail "sha256sum or shasum is required to verify the download"
fi
[ "$expected" = "$actual" ] || fail "checksum mismatch for $archive (expected $expected, got $actual)"

mkdir -p "$tmp/extract"
if [ "$os" = win ]; then
  if command -v unzip > /dev/null 2>&1; then
    unzip -q -o "$tmp/$archive" -d "$tmp/extract"
  else
    powershell.exe -NoProfile -Command "Expand-Archive -Force -Path '$(cygpath -w "$tmp/$archive")' -DestinationPath '$(cygpath -w "$tmp/extract")'"
  fi
else
  tar -xzf "$tmp/$archive" -C "$tmp/extract"
fi

mkdir -p "$install_dir"
mv -f "$tmp/extract/$exe" "$install_dir/$exe"
chmod +x "$install_dir/$exe"

echo "Installed lumin $("$install_dir/$exe" --version) to $install_dir/$exe"
case ":$PATH:" in
  *":$install_dir:"*) ;;
  *) echo "Add it to PATH, e.g. in your shell profile: export PATH=\"$install_dir:\$PATH\"" ;;
esac