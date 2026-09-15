#!/bin/sh
# Build the tsukimi binary with cargo and copy it to the meson output path.
#
# Usage: cargo-build.sh <cargo> <built-binary> <output> <cargo args...>
#
# meson's custom_target does not wrap commands in a shell on Windows, so the
# `build && cp` sequence has to live in a script instead of the command line.
set -e

cargo="$1"
built="$2"
output="$3"
shift 3

"$cargo" build "$@"
cp "$built" "$output"
