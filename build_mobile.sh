#!/usr/bin/env bash
# ============================================================================
# DEEPWOOD MOBILE BUILD (2026-07-28) -- the one-command pipeline for every
# future game update. The game keeps evolving on PC; this repackages the
# CURRENT tree for phones, no mobile-specific steps needed.
#
#   ./build_mobile.sh              debug APK  -> build/deepwood-debug.apk
#   ./build_mobile.sh release      Play AAB   -> build/deepwood-release.aab
#   ./build_mobile.sh ios          Xcode project -> build/ios/ (finish on a Mac)
#
# Before each STORE release (not needed for sideload testing):
#   1. bump version/code (+1 every upload) and version/name in
#      export_presets.cfg under [preset.1] (Android) / [preset.2] (iOS)
#   2. release mode needs the RELEASE keystore configured in the preset
#      (see task notes; debug builds use the auto debug keystore)
#
# Toolchain lives in C:/Users/bacho/android-dev (portable JDK 17 + SDK);
# Godot editor settings already point at it. If Android export ever fails
# with missing SDK paths, re-add export/android/java_sdk_path +
# android_sdk_path in editor_settings-4.7.tres (an open editor rewrites
# that file on exit and can drop them).
# ============================================================================
set -e
GODOT="/c/Users/bacho/Desktop/Godot.exe"
cd "$(dirname "$0")"
mkdir -p build

case "${1:-debug}" in
	release)
		"$GODOT" --headless --export-release "Android" "build/deepwood-release.aab"
		ls -la build/deepwood-release.aab
		;;
	ios)
		mkdir -p build/ios
		"$GODOT" --headless --export-debug "iOS" "build/ios/Deepwood.ipa" || true
		echo "iOS: open the generated Xcode project in build/ios/ on a Mac to sign + upload."
		ls build/ios
		;;
	debug|*)
		"$GODOT" --headless --export-debug "Android" "build/deepwood-debug.apk"
		ls -la build/deepwood-debug.apk
		;;
esac
