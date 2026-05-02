#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./install-libxpc-linux-deps.sh [options]

Installs toolchain prerequisites and then builds/installs libxpc only.
GNUstep is assumed to already be installed.

Options:
  --repo URL         Git URL for the libxpc repository.
                     Default: https://github.com/jceel/libxpc.git
  --branch NAME      Optional git branch/tag/commit to checkout.
  --workdir PATH     Working directory for clone/build artifacts.
                     Default: ./_libxpc_build
  --prefix PATH      Install prefix.
                     Default: /usr/local
  --yes              Run non-interactively where package manager supports it.
  --help             Show this help text.

Notes:
  - This script intentionally does NOT install or build libdispatch/libkqueue.
  - It installs and builds only libxpc.
EOF
}

AUTO_YES=0
REPO_URL="https://github.com/jceel/libxpc.git"
BRANCH=""
WORKDIR="$(pwd)/_libxpc_build"
PREFIX="/usr/local"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes)
      AUTO_YES=1
      shift
      ;;
    --repo)
      [[ $# -ge 2 ]] || { echo "--repo requires a value." >&2; exit 1; }
      shift
      REPO_URL="$1"
      shift
      ;;
    --branch)
      [[ $# -ge 2 ]] || { echo "--branch requires a value." >&2; exit 1; }
      shift
      BRANCH="$1"
      shift
      ;;
    --workdir)
      [[ $# -ge 2 ]] || { echo "--workdir requires a value." >&2; exit 1; }
      shift
      WORKDIR="$1"
      shift
      ;;
    --prefix)
      [[ $# -ge 2 ]] || { echo "--prefix requires a value." >&2; exit 1; }
      shift
      PREFIX="$1"
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$REPO_URL" || -z "$WORKDIR" || -z "$PREFIX" ]]; then
  echo "--repo, --workdir, and --prefix require values." >&2
  exit 1
fi

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "This script must be run on Linux." >&2
  exit 1
fi

if [[ ! -r /etc/os-release ]]; then
  echo "Unable to detect Linux distribution: /etc/os-release is missing." >&2
  exit 1
fi

# shellcheck disable=SC1091
. /etc/os-release

if [[ ${EUID} -eq 0 ]]; then
  SUDO=()
elif command -v sudo >/dev/null 2>&1; then
  SUDO=(sudo)
else
  echo "This script needs root privileges. Re-run as root or install sudo." >&2
  exit 1
fi

PM=""
UPDATE_CMD=()
INSTALL_CMD=()
REQUIRED_PACKAGES=()

if command -v apt-get >/dev/null 2>&1; then
  PM="apt"
  UPDATE_CMD=("${SUDO[@]}" apt-get update)
  INSTALL_CMD=("${SUDO[@]}" apt-get install)
  if [[ $AUTO_YES -eq 1 ]]; then
    INSTALL_CMD+=( -y --no-install-recommends )
  else
    INSTALL_CMD+=( --no-install-recommends )
  fi
  REQUIRED_PACKAGES=(
    build-essential
    clang
    cmake
    ninja-build
    pkg-config
    git
    ca-certificates
    curl
    python3
    autoconf
    automake
    libtool
    libblocksruntime-dev
    libbsd-dev
    uuid-dev
    libxml2-dev
    libssl-dev
  )
elif command -v dnf >/dev/null 2>&1; then
  PM="dnf"
  UPDATE_CMD=("${SUDO[@]}" dnf makecache)
  INSTALL_CMD=("${SUDO[@]}" dnf install)
  if [[ $AUTO_YES -eq 1 ]]; then
    INSTALL_CMD+=( -y )
  fi
  REQUIRED_PACKAGES=(
    gcc
    gcc-c++
    clang
    cmake
    ninja-build
    make
    pkgconf-pkg-config
    git
    ca-certificates
    curl
    python3
    autoconf
    automake
    libtool
    libblocksruntime-devel
    libbsd-devel
    libuuid-devel
    libxml2-devel
    openssl-devel
  )
elif command -v yum >/dev/null 2>&1; then
  PM="yum"
  UPDATE_CMD=("${SUDO[@]}" yum makecache)
  INSTALL_CMD=("${SUDO[@]}" yum install)
  if [[ $AUTO_YES -eq 1 ]]; then
    INSTALL_CMD+=( -y )
  fi
  REQUIRED_PACKAGES=(
    gcc
    gcc-c++
    clang
    cmake
    ninja-build
    make
    pkgconfig
    git
    ca-certificates
    curl
    python3
    autoconf
    automake
    libtool
    libblocksruntime-devel
    libbsd-devel
    libuuid-devel
    libxml2-devel
    openssl-devel
  )
elif command -v pacman >/dev/null 2>&1; then
  PM="pacman"
  UPDATE_CMD=("${SUDO[@]}" pacman -Sy)
  INSTALL_CMD=("${SUDO[@]}" pacman -S --needed)
  if [[ $AUTO_YES -eq 1 ]]; then
    INSTALL_CMD+=( --noconfirm )
  fi
  REQUIRED_PACKAGES=(
    base-devel
    clang
    cmake
    ninja
    pkgconf
    git
    ca-certificates
    curl
    python
    autoconf
    automake
    libtool
    libblocksruntime
    libbsd
    util-linux-libs
    libxml2
    openssl
  )
elif command -v zypper >/dev/null 2>&1; then
  PM="zypper"
  UPDATE_CMD=("${SUDO[@]}" zypper --gpg-auto-import-keys refresh)
  INSTALL_CMD=("${SUDO[@]}" zypper install)
  if [[ $AUTO_YES -eq 1 ]]; then
    INSTALL_CMD+=( -y )
  fi
  REQUIRED_PACKAGES=(
    gcc
    gcc-c++
    clang
    cmake
    ninja
    make
    pkg-config
    git
    ca-certificates
    curl
    python3
    autoconf
    automake
    libtool
    libblocksruntime-devel
    libbsd-devel
    libuuid-devel
    libxml2-devel
    libopenssl-devel
  )
else
  echo "Unsupported distribution: no supported package manager found." >&2
  exit 1
fi

run_cmd() {
  echo "+ $*"
  "$@"
}

install_required() {
  run_cmd "${UPDATE_CMD[@]}"
  run_cmd "${INSTALL_CMD[@]}" "${REQUIRED_PACKAGES[@]}"
}

build_and_install_libxpc() {
  local src_dir="$WORKDIR/libxpc"
  local build_dir="$src_dir/build"

  run_cmd mkdir -p "$WORKDIR"

  if [[ -d "$src_dir/.git" ]]; then
    run_cmd git -C "$src_dir" fetch --all --tags
    run_cmd git -C "$src_dir" reset --hard HEAD
    run_cmd git -C "$src_dir" clean -fdx
    run_cmd git -C "$src_dir" checkout main || true
    run_cmd git -C "$src_dir" pull --ff-only
  else
    run_cmd git clone "$REPO_URL" "$src_dir"
  fi

  if [[ -n "$BRANCH" ]]; then
    run_cmd git -C "$src_dir" checkout "$BRANCH"
  fi

  if [[ -f "$src_dir/CMakeLists.txt" ]]; then
    run_cmd cmake -S "$src_dir" -B "$build_dir" -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$PREFIX"
    run_cmd cmake --build "$build_dir" --parallel
    run_cmd "${SUDO[@]}" cmake --install "$build_dir"
    return
  fi

  if [[ -f "$src_dir/configure.ac" || -f "$src_dir/configure.in" ]]; then
    if [[ ! -f "$src_dir/configure" ]]; then
      run_cmd bash -lc "cd '$src_dir' && autoreconf -fi"
    fi
    run_cmd bash -lc "cd '$src_dir' && ./configure --prefix='$PREFIX'"
    run_cmd bash -lc "cd '$src_dir' && make -j\"\$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)\""
    run_cmd bash -lc "cd '$src_dir' && ${SUDO[*]} make install"
    return
  fi

  echo "Could not determine how to build libxpc in $src_dir." >&2
  echo "Expected CMakeLists.txt or configure.ac/configure.in." >&2
  exit 1
}

echo "Detected distribution: ${PRETTY_NAME:-$ID}"
echo "Using package manager: $PM"
echo "libxpc repository: $REPO_URL"
echo "Install prefix: $PREFIX"

install_required
build_and_install_libxpc

cat <<'EOF'

libxpc installation complete.

Next steps:
  1. Verify installation paths under your selected prefix.
  2. Link your project against the installed libxpc artifacts.
EOF