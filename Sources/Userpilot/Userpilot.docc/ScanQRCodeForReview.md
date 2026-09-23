# Scan a QR Code to Review an Experience

Review a draft Flow or Survey on a physical device or simulator before publishing it. The Mobile Builder QR code contains a Userpilot custom URL that opens your app and asks the SDK to fetch the draft experience.

## URL contract

The SDK accepts preview URLs with this exact structure:

```text
userpilot-{token}://sdk/experience_preview/{experience_id}
```

The URL must satisfy all of these checks:

- The scheme is `userpilot-` followed by the token passed to ``Userpilot/Config``, lowercased.
- The host is exactly `sdk`.
- The path contains `experience_preview` followed by a nonempty experience ID.
- Any query items, such as locale or experience type, are forwarded to the preview request.

A staging token keeps its prefix. For example, `STG-NX-12345678` maps to `userpilot-stg-nx-12345678`.

## Register the scheme

Add the token-based scheme to the app target's `Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLName</key>
        <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>userpilot-APP_TOKEN</string>
        </array>
    </dict>
</array>
```

Replace `APP_TOKEN` with the same lowercased token used to initialize the SDK.

## Forward every URL entry point

For scene-based apps, handle both cold-launch and already-running delivery:

```swift
func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
) {
    let unhandled = userpilot.filterAndHandle(connectionOptions.urlContexts)
    // Route any contexts left in `unhandled` through your app.
}

func scene(_ scene: UIScene, openURLContexts contexts: Set<UIOpenURLContext>) {
    let unhandled = userpilot.filterAndHandle(contexts)
    // Route any contexts left in `unhandled` through your app.
}
```

For an app-delegate or SwiftUI entry point, pass the individual URL to ``Userpilot/didHandleURL(_:)``. A return value of `false` means the URL belongs to the host app.

```swift
func application(
    _ application: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
) -> Bool {
    if userpilot.didHandleURL(url) { return true }
    return false
}
```

The SDK queues a valid preview action until a window scene becomes active. This allows a QR scan to start the app without losing the preview while the UI is still connecting.

## Test without the Builder

Open a known preview URL in the booted simulator:

```bash
xcrun simctl openurl booted \
  "userpilot-nx-12345678://sdk/experience_preview/12345"
```

Replace the scheme and experience ID with values for your environment. Enable SDK logging while testing.

## Failure boundaries

- **No app opens:** the scheme is absent from `Info.plist` or does not match the initialized token.
- **The app opens but `didHandleURL` returns `false`:** check the `sdk` host, path, environment token, and experience ID.
- **The app opens but no preview appears:** confirm every URL entry point forwards to Userpilot and the same environment created the QR code.
- **Your own links stop routing:** continue handling URL contexts returned by ``Userpilot/filterAndHandle(_:)`` and URLs for which ``Userpilot/didHandleURL(_:)`` returns `false`.

See <doc:URLSchemeConfiguring> for the complete custom URL scheme integration.
