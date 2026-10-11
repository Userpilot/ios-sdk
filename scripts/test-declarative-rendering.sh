#!/usr/bin/env bash
# Run the rendering fixtures inside a real UIKit app. SPM's hostless test runner
# cannot validate UIWindowScene presentation or native dismissal animations.
set -euo pipefail

SDK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if ! ruby -r xcodeproj -e '' 2>/dev/null; then
  echo 'This fixture harness requires the xcodeproj Ruby gem (also installed with CocoaPods).' >&2
  exit 1
fi

SIMULATOR_ID="${1:-}"
if [ -z "$SIMULATOR_ID" ]; then
  SIMULATOR_ID="$(xcrun simctl list devices available --json | python3 -c '
import json, sys
devices = [d for runtime, items in json.load(sys.stdin)["devices"].items()
           if "iOS" in runtime for d in items if "iPhone" in d["name"]]
devices.sort(key=lambda d: d["state"] != "Booted")
if devices:
    print(devices[0]["udid"])
')"
fi
if [ -z "$SIMULATOR_ID" ]; then
  echo 'No available iPhone simulator. Install an iOS runtime in Xcode first.' >&2
  exit 1
fi

RENDER_OUTPUT="$(mktemp -d "${TMPDIR:-/tmp}/userpilot-rendering.XXXXXX")"
ruby "$SDK_ROOT/scripts/rendering-fixtures/generate-host.rb" "$SDK_ROOT" "$RENDER_OUTPUT"
echo "Rendering artifacts: $RENDER_OUTPUT"
xcodebuild test \
  -project "$RENDER_OUTPUT/RenderHost.xcodeproj" -scheme RenderHost \
  -destination "platform=iOS Simulator,id=$SIMULATOR_ID" \
  -derivedDataPath "$RENDER_OUTPUT/DerivedData" \
  -resultBundlePath "$RENDER_OUTPUT/Rendering.xcresult" \
  -only-testing:HostedRenderTests/ExperienceHostingTests \
  -only-testing:HostedRenderTests/SurveyResizeHostingTests \
  -only-testing:RendererGestureTests/CarouselGestureTests \
  -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=NO
xcrun xcresulttool export attachments \
  --path "$RENDER_OUTPUT/Rendering.xcresult" --output-path "$RENDER_OUTPUT/screenshots"
echo "Rendering fixtures passed. Screenshots: $RENDER_OUTPUT/screenshots"
