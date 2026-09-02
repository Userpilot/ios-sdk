#!/usr/bin/env bash
#
# Build Userpilot.xcframework from the Swift package.
#
#   scripts/build-xcframework.sh [--output DIR] [--zip]
#
# Produces one binary artifact holding the iOS device and iOS Simulator slices,
# for consumers who integrate neither via SPM nor CocoaPods: manual drag-and-drop
# integration and the Flutter / React Native / Capacitor wrappers.
#
# Exit code: 0 = built and verified, 1 = failed.
#
# ---------------------------------------------------------------------------
# Why this is a script and not a one-line xcodebuild
# ---------------------------------------------------------------------------
# Four things about this package each break the textbook recipe:
#
#   1. The product is `.library(name:targets:)` — *automatic* linkage, which Xcode
#      resolves to a static object file. `xcodebuild archive` on the stock manifest
#      emits only `Userpilot.o`; there is no .framework to package. So the script
#      rewrites the manifest to `type: .dynamic` for the duration of the build and
#      restores it on exit, including on failure or Ctrl-C.
#
#      Dynamic rather than static is also required for correctness: `Bundle.module`
#      resolves resources through `Bundle(for:).resourceURL`, which is the framework
#      itself only when the framework is dynamic. In a static framework that call
#      returns the *host app's* bundle, and every image, xib and countries.json
#      lookup would trap at runtime.
#
#   2. The archived .framework is missing two pieces Xcode would add for a real
#      framework target, both copied in by `assemble_framework`:
#        * Modules/Userpilot.swiftmodule — without it, `import Userpilot` fails.
#        * Userpilot_Userpilot.bundle    — the SPM resource bundle, which has to sit
#          inside the framework for the lookup described above to find it.
#          (See Sources/Userpilot/Extensions/Bundle+Extensions.swift.)
#
#   3. `xcodebuild -create-xcframework` rejects a Swift framework whose .swiftmodule
#      contains no .swiftinterface ("No 'swiftinterface' files found within ..."),
#      so BUILD_LIBRARY_FOR_DISTRIBUTION=YES is mandatory here, not a nicety.
#
#   4. ...but this package cannot emit a *verifiable* interface. The module and its
#      public class are both named `Userpilot`, so every qualified name the interface
#      printer writes — `Userpilot.UserpilotAnalytic`, `Userpilot.Socket.CloseCode`,
#      `Userpilot.Userpilot.Config` — resolves to the class rather than the module,
#      and emit-time verification fails with 66 errors.
#
#      Since inside a .swiftinterface the module's own types resolve unqualified,
#      dropping the leading `Userpilot.` qualifier makes the interface correct.
#      So the build passes -no-verify-emitted-module-interface, `repair_interfaces`
#      strips that qualifier, and `verify_interface` then typechecks each repaired
#      interface with swift-frontend — the same check the compiler would run, so the
#      suppression above is re-armed rather than skipped. A slice whose interface
#      does not typecheck fails this script.
#
# The proper upstream fix for (4) is for the module and the public class to stop
# sharing a name; that is a breaking change for every consumer and every wrapper,
# so it is deliberately not attempted here.

set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

SCHEME="Userpilot"
MODULE="Userpilot"
MANIFEST="Package.swift"
RESOURCE_BUNDLE="${MODULE}_${MODULE}.bundle"

OUTPUT_DIR=".build/xcframework"
MAKE_ZIP=0
INCLUDE_DSYMS=0

usage() {
    cat <<EOF
Build ${MODULE}.xcframework (iOS device + iOS Simulator).

Usage: scripts/build-xcframework.sh [options]

  --output DIR   Where to write the .xcframework (default: ${OUTPUT_DIR})
  --zip          Also produce a .zip and print its SHA-256 (SPM binaryTarget checksum)
  --dsyms        Bundle dSYMs into the artifact (roughly triples its size)
  -h, --help     Show this help
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --output)  OUTPUT_DIR="${2:?--output needs a directory}"; shift 2 ;;
        --zip)     MAKE_ZIP=1; shift ;;
        --dsyms)   INCLUDE_DSYMS=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *)         echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
    esac
done

command -v xcodebuild >/dev/null 2>&1 || { echo "❌ xcodebuild not found — install Xcode."; exit 1; }
SWIFT_FRONTEND="$(xcrun --find swift-frontend 2>/dev/null || true)"
[ -x "$SWIFT_FRONTEND" ] || { echo "❌ swift-frontend not found — check xcode-select -p."; exit 1; }

WORK_DIR="$(mktemp -d)"
LOG="$WORK_DIR/xcodebuild.log"
MANIFEST_BACKUP="$WORK_DIR/Package.swift.orig"

# Restore the manifest however we leave: success, error, or interrupt.
cleanup() {
    if [ -f "$MANIFEST_BACKUP" ]; then
        cp "$MANIFEST_BACKUP" "$MANIFEST"
    fi
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT INT TERM

# ---------------------------------------------------------------------------
# 1. Patch the manifest to build a dynamic framework
# ---------------------------------------------------------------------------
cp "$MANIFEST" "$MANIFEST_BACKUP"

if grep -q "type: .dynamic" "$MANIFEST"; then
    echo "→ Manifest already declares a dynamic product; leaving it alone."
else
    # `targets: ["Userpilot"]` appears exactly once (the .library product); the test
    # target refers to the module through `dependencies:`, so this anchor is unambiguous.
    sed -i '' -e 's/^\( *\)targets: \["'"$MODULE"'"\]$/\1type: .dynamic,\
\1targets: ["'"$MODULE"'"]/' "$MANIFEST"

    if ! grep -q "type: .dynamic" "$MANIFEST"; then
        echo "❌ Could not patch $MANIFEST to a dynamic product."
        echo "   Expected a line reading: targets: [\"$MODULE\"]"
        exit 1
    fi
    echo "→ Patched $MANIFEST to type: .dynamic (restored on exit)."
fi

# ---------------------------------------------------------------------------
# 2. Archive each platform, then complete and repair the framework
# ---------------------------------------------------------------------------

# repair_interfaces <swiftmodule-dir>
#
# Drop the leading `Userpilot.` module qualifier from every emitted interface. Only
# the *first* qualifier of a name is removed, so `Userpilot.Userpilot.Config`
# correctly becomes `Userpilot.Config` (Config stays nested in the class) while
# `Userpilot.UserpilotAnalytic` becomes `UserpilotAnalytic`. Every occurrence in
# the emitted interface is a type position — there are no string literals to damage.
repair_interfaces() {
    local swiftmodule="$1" iface
    for iface in "$swiftmodule"/*.swiftinterface; do
        [ -e "$iface" ] || continue
        sed -i '' -E "s/(^|[^A-Za-z0-9_.])$MODULE\./\1/g" "$iface"
    done
}

# verify_interface <swiftinterface>
#
# Typecheck a repaired interface exactly as a consuming compiler would when it has
# no matching binary .swiftmodule. The target triple is read back out of the
# interface's own `// swift-module-flags:` header.
verify_interface() {
    local iface="$1" target sdk_name
    target="$(sed -n 's|^// swift-module-flags:.*-target \([^ ]*\).*|\1|p' "$iface" | head -1)"
    if [ -z "$target" ]; then
        echo "❌ No -target in $(basename "$iface")"
        return 1
    fi
    case "$target" in
        *simulator*) sdk_name=iphonesimulator ;;
        *)           sdk_name=iphoneos ;;
    esac

    if ! "$SWIFT_FRONTEND" -frontend -typecheck-module-from-interface "$iface" \
        -target "$target" \
        -sdk "$(xcodebuild -version -sdk "$sdk_name" Path)" \
        -enable-library-evolution -swift-version 5 -module-name "$MODULE" \
        >"$WORK_DIR/verify.log" 2>&1; then
        echo "❌ $(basename "$iface") does not typecheck:"
        grep "error:" "$WORK_DIR/verify.log" | head -10
        return 1
    fi
}

# assemble_framework <archive> <derived-data> <sdk-build-dir>
assemble_framework() {
    local archive="$1" derived="$2" sdk_dir="$3"
    local framework="$archive/Products/usr/local/lib/$MODULE.framework"
    local products="$derived/Build/Intermediates.noindex/ArchiveIntermediates/$SCHEME/BuildProductsPath/$sdk_dir"

    [ -d "$framework" ] || { echo "❌ No framework in archive at $framework"; exit 1; }
    [ -d "$products/$MODULE.swiftmodule" ] || { echo "❌ No $MODULE.swiftmodule in $products"; exit 1; }
    [ -d "$products/$RESOURCE_BUNDLE" ] || { echo "❌ No $RESOURCE_BUNDLE in $products"; exit 1; }

    mkdir -p "$framework/Modules"
    cp -R "$products/$MODULE.swiftmodule" "$framework/Modules/"
    # ABI descriptors feed swift-api-digester; no consumer needs them to import the
    # module, and they cost ~876K per architecture.
    rm -f "$framework/Modules/$MODULE.swiftmodule"/*.abi.json
    # -L: the build-products entry is a symlink into IntermediateBuildFilesPath.
    cp -RL "$products/$RESOURCE_BUNDLE" "$framework/"

    repair_interfaces "$framework/Modules/$MODULE.swiftmodule"

    local iface
    for iface in "$framework/Modules/$MODULE.swiftmodule"/*.swiftinterface; do
        [ -e "$iface" ] || { echo "❌ No .swiftinterface emitted for $sdk_dir"; exit 1; }
        verify_interface "$iface" || exit 1
    done
}

# archive_for <label> <destination> <sdk-build-dir>
archive_for() {
    local label="$1" destination="$2" sdk_dir="$3"
    local archive="$WORK_DIR/$label.xcarchive"
    local derived="$WORK_DIR/dd-$label"

    echo "→ Archiving ${label}…"
    if ! xcodebuild archive \
        -scheme "$SCHEME" \
        -destination "$destination" \
        -configuration Release \
        -archivePath "$archive" \
        -derivedDataPath "$derived" \
        SKIP_INSTALL=NO \
        BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
        OTHER_SWIFT_FLAGS='$(inherited) -no-verify-emitted-module-interface' \
        -quiet >"$LOG" 2>&1; then
        echo "❌ Archive failed for $label. Last 40 lines:"
        tail -40 "$LOG"
        exit 1
    fi

    echo "→ Repairing and verifying the ${label} module interface…"
    assemble_framework "$archive" "$derived" "$sdk_dir"
}

archive_for "ios"           "generic/platform=iOS"           "Release-iphoneos"
archive_for "ios-simulator" "generic/platform=iOS Simulator" "Release-iphonesimulator"

# ---------------------------------------------------------------------------
# 3. Combine the slices
# ---------------------------------------------------------------------------
mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"          # -create-xcframework requires absolute paths
XCFRAMEWORK="$OUTPUT_DIR/$MODULE.xcframework"
rm -rf "$XCFRAMEWORK"

echo "→ Creating $MODULE.xcframework…"
# dSYMs are debug symbols for symbolicating crash reports. They are never linked
# into a consumer's app, so bundling them costs download size and buys nothing at
# runtime — hence opt-in. Archived dSYMs are kept out of the artifact by default.
CREATE_ARGS=()
for label in ios ios-simulator; do
    CREATE_ARGS+=(-framework "$WORK_DIR/$label.xcarchive/Products/usr/local/lib/$MODULE.framework")
    if [ "$INCLUDE_DSYMS" -eq 1 ]; then
        CREATE_ARGS+=(-debug-symbols "$WORK_DIR/$label.xcarchive/dSYMs/$MODULE.framework.dSYM")
    fi
done

xcodebuild -create-xcframework "${CREATE_ARGS[@]}" \
    -output "$XCFRAMEWORK" >"$LOG" 2>&1 || { echo "❌ -create-xcframework failed:"; tail -40 "$LOG"; exit 1; }

# ---------------------------------------------------------------------------
# 4. Check the artifact rather than trusting the exit code
# ---------------------------------------------------------------------------
FAILURES=()
for slice in "$XCFRAMEWORK"/*/; do
    name="$(basename "$slice")"
    framework="$slice$MODULE.framework"
    [ -f "$framework/$MODULE" ]                        || FAILURES+=("$name: missing binary")
    [ -d "$framework/Modules/$MODULE.swiftmodule" ]     || FAILURES+=("$name: missing Modules/$MODULE.swiftmodule")
    ls "$framework/Modules/$MODULE.swiftmodule"/*.swiftinterface >/dev/null 2>&1 \
                                                       || FAILURES+=("$name: no .swiftinterface in the Swift module")
    [ -d "$framework/$RESOURCE_BUNDLE" ]                || FAILURES+=("$name: missing $RESOURCE_BUNDLE")
    [ -f "$framework/$RESOURCE_BUNDLE/countries.json" ] || FAILURES+=("$name: resource bundle has no countries.json")
done

SLICE_COUNT="$(find "$XCFRAMEWORK" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"
[ "$SLICE_COUNT" -eq 2 ] || FAILURES+=("expected 2 slices, found $SLICE_COUNT")

if [ ${#FAILURES[@]} -gt 0 ]; then
    echo "❌ The built xcframework is incomplete:"
    printf '   - %s\n' "${FAILURES[@]}"
    exit 1
fi

echo
echo "✅ $XCFRAMEWORK"
for slice in "$XCFRAMEWORK"/*/; do
    echo "   $(basename "$slice"): $(lipo -archs "$slice$MODULE.framework/$MODULE")"
done
echo "   size: $(du -sh "$XCFRAMEWORK" | cut -f1)"

# ---------------------------------------------------------------------------
# 5. Optional zip for binary distribution
# ---------------------------------------------------------------------------
if [ "$MAKE_ZIP" -eq 1 ]; then
    ZIP="$OUTPUT_DIR/$MODULE.xcframework.zip"
    rm -f "$ZIP"
    ditto -c -k --sequesterRsrc --keepParent "$XCFRAMEWORK" "$ZIP"
    echo
    echo "✅ $ZIP"
    # An SPM binaryTarget checksum is just the SHA-256 of the zip.
    echo "   checksum: $(shasum -a 256 "$ZIP" | cut -d' ' -f1)"
fi
