#!/usr/bin/env bash
# Collect tsukimi.exe and its runtime dependencies into a portable,
# self-contained directory (then a zip) for Windows.
#
# Usage: package-windows.sh <install-prefix> <output-name>
#   <install-prefix>  the directory meson installed into, containing
#                     bin/tsukimi.exe (e.g. "$PWD/staging/ucrt64")
#   <output-name>     base name of the package dir and zip
#
# Must run inside the MSYS2 UCRT64 environment; expects MINGW_PREFIX
# (default /ucrt64) and ntldd to be available.
set -euo pipefail

PREFIX="$(cd "$1" && pwd)"
OUT="$2"
MINGW_PREFIX="${MINGW_PREFIX:-/ucrt64}"

PKG="$PWD/$OUT"
rm -rf "$PKG"
mkdir -p "$PKG"

# --- Executable ---
cp "$PREFIX/bin/tsukimi.exe" "$PKG/"

# --- Application data installed by meson ---
for d in share/tsukimi share/glib-2.0/schemas share/locale share/icons; do
    if [ -d "$PREFIX/$d" ]; then
        mkdir -p "$PKG/$d"
        cp -r "$PREFIX/$d/." "$PKG/$d/"
    fi
done

# --- GSettings schemas (ours + glib/gtk/adwaita ones from the toolchain) ---
mkdir -p "$PKG/share/glib-2.0/schemas"
cp "$MINGW_PREFIX/share/glib-2.0/schemas/"*.gschema.xml "$PKG/share/glib-2.0/schemas/"
glib-compile-schemas "$PKG/share/glib-2.0/schemas"

# --- Icon themes ---
mkdir -p "$PKG/share/icons"
for theme in hicolor Adwaita; do
    if [ -d "$MINGW_PREFIX/share/icons/$theme" ]; then
        cp -r "$MINGW_PREFIX/share/icons/$theme" "$PKG/share/icons/"
    fi
done
gtk4-update-icon-cache -q "$PKG/share/icons/hicolor" 2>/dev/null || true
gtk4-update-icon-cache -q "$PKG/share/icons/Adwaita" 2>/dev/null || true

# --- Locales: tsukimi translations were installed above; add gtk/glib/adw ---
for lang_dir in "$MINGW_PREFIX/share/locale"/*/LC_MESSAGES; do
    lang="$(basename "$(dirname "$lang_dir")")"
    for mo in glib20.mo gtk40.mo libadwaita.mo; do
        if [ -f "$lang_dir/$mo" ]; then
            mkdir -p "$PKG/share/locale/$lang/LC_MESSAGES"
            cp "$lang_dir/$mo" "$PKG/share/locale/$lang/LC_MESSAGES/"
        fi
    done
done

# --- fontconfig configuration (pango needs it to find fonts) ---
mkdir -p "$PKG/etc"
cp -r "$MINGW_PREFIX/etc/fonts" "$PKG/etc/fonts"

# --- GStreamer plugins ---
mkdir -p "$PKG/lib/gstreamer-1.0"
cp "$MINGW_PREFIX/lib/gstreamer-1.0/"*.dll "$PKG/lib/gstreamer-1.0/"

# --- GLib spawn helpers ---
cp "$MINGW_PREFIX/bin/gspawn-win64-helper.exe" "$PKG/" 2>/dev/null || true
cp "$MINGW_PREFIX/bin/gspawn-win64-helper-console.exe" "$PKG/" 2>/dev/null || true

# --- DLL closure ---
# ntldd (a native Windows program) may print drive-lettered paths, so
# normalize with cygpath before filtering; skip only Windows system DLLs.
mapfile -t raw_dlls < <(
    {
        ntldd -R "$PKG/tsukimi.exe"
        for plugin in "$PKG/lib/gstreamer-1.0/"*.dll; do
            ntldd -R "$plugin"
        done
    } | grep '=>' | awk '{print $3}' | sort -u
)
count=0
for dll in "${raw_dlls[@]}"; do
    posix="$(cygpath -u "$dll")"
    case "$posix" in
        /c/Windows/* | /c/windows/*) continue ;;
    esac
    if [ -f "$posix" ]; then
        cp "$posix" "$PKG/"
        count=$((count + 1))
    fi
done
echo "Copied $count DLLs into the package"

# --- Self-check: fail loudly instead of shipping a broken package ---
# (api|ext)-ms-* are Windows API-set pseudo-DLLs resolved by the OS loader at
# runtime (no file on disk); the rest are optional/delay-loaded system
# components. ntldd always reports them as "not found", so exclude them.
missing="$(ntldd -R "$PKG/tsukimi.exe" | grep -i 'not found' | grep -viE '((api|ext)-ms-|wtdccm|azureattest|pdmutilities|hvsifiletrust|wtdsensor|wpaxholder)' || true)"
if [ -n "$missing" ]; then
    echo "ERROR: unresolved DLL dependencies in the package:" >&2
    echo "$missing" >&2
    exit 1
fi

# --- Zip ---
zip -qr "$OUT.zip" "$OUT"
echo "Packaged $OUT.zip"
