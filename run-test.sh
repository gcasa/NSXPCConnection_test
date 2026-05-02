#!/bin/zsh

set -euo pipefail

workspace_dir="$(cd -- "$(dirname -- "$0")" && pwd)"
binary_path="$workspace_dir/NSXPCConnectionAnonymousListenerTest"
source_path="$workspace_dir/NSXPCConnectionAnonymousListenerTest.m"
sdk_path="$(xcrun --sdk macosx --show-sdk-path)"

clang \
  -Wall \
  -Wextra \
  -Werror \
  -fobjc-arc \
  -framework Foundation \
  -isysroot "$sdk_path" \
  "$source_path" \
  -o "$binary_path"

"$binary_path"