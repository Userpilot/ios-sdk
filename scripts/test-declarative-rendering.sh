#!/usr/bin/env bash
# Run the rendering fixtures inside a real UIKit app. SPM's hostless test runner
# cannot validate UIWindowScene presentation or native dismissal animations.
set -euo pipefail

SDK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if ! ruby -r xcodeproj -e '' 2>/dev/null; then
  echo 'This fixture harness requires the xcodeproj Ruby gem (also installed with CocoaPods).' >&2
  exit 1
fi

find_simulator() {
  xcrun simctl list devices available --json | python3 -c '
import json, sys
devices = [d for runtime, items in json.load(sys.stdin)["devices"].items()
           if "iOS" in runtime for d in items if sys.argv[1] in d["name"]]
devices.sort(key=lambda d: d["state"] != "Booted")
if devices:
    print(devices[0]["udid"])
' "$1"
}

SIMULATOR_ID="${1:-$(find_simulator iPhone)}"
IPAD_ID="${2:-$(find_simulator iPad)}"
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
  -only-testing:HostedRenderTests/ExperienceAccessibilityHostingTests \
  -only-testing:HostedRenderTests/ExperienceVoiceOverHostingTests \
  -only-testing:HostedRenderTests/SurveyResizeHostingTests \
  -only-testing:RendererGestureTests/CarouselGestureTests \
  -only-testing:RendererGestureTests/CarouselDirectionTests \
  -only-testing:RendererGestureTests/VoiceOverFixtureTests \
  -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=NO
xcrun xcresulttool export attachments \
  --path "$RENDER_OUTPUT/Rendering.xcresult" --output-path "$RENDER_OUTPUT/screenshots"
# Only an iPad host can open a second scene; iPhone runs skip the overlay scene test.
if [ -n "$IPAD_ID" ]; then
  xcodebuild test \
    -project "$RENDER_OUTPUT/RenderHost.xcodeproj" -scheme RenderHost \
    -destination "platform=iOS Simulator,id=$IPAD_ID" \
    -derivedDataPath "$RENDER_OUTPUT/DerivedData" \
    -resultBundlePath "$RENDER_OUTPUT/Scenes.xcresult" \
    -only-testing:HostedRenderTests/ExperienceOverlaySceneTests \
    -parallel-testing-enabled NO \
    CODE_SIGNING_ALLOWED=NO
else
  echo 'No iPad simulator available; skipped the multi-scene overlay test.' >&2
fi
echo "Rendering fixtures passed. Screenshots: $RENDER_OUTPUT/screenshots"
