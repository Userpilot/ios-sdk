# Configuring the Userpilot URL Scheme

The Userpilot iOS SDK includes support for a custom URL scheme that supports previewing Userpilot experiences.

## Overview

Configuring the Userpilot URL scheme involves adding a `CFBundleURLTypes` value and then directing the incoming URL to the Userpilot iOS SDK.

## Register the Custom URL Scheme

Update your `Info.plist` to register the custom URL scheme. Replace `USERPILOT_TOKEN` in the snippet below with your app's Userpilot Token. This value can be obtained from your [Environments Page](https://run.userpilot.io/environment).

For example, if your Userpilot Token is `NX-12345678` your url scheme value would be `userpilot-nx-12345678`.

```
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLName</key>
        <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>userpilot-USERPILOT_TOKEN</string>
        </array>
    </dict>
</array>
```

## Handle the Custom URL Scheme

Custom URL's should be handled with a call to ``Userpilot/filterAndHandle(_:)`` or ``Userpilot/didHandleURL(_:)``. If the URL being opened is an Userpilot URL, the URL will be handled.

If your app uses a Scene delegate, add the following:

```swift
func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
    // Handle Userpilot deep links.
    let unhandledURLContexts = userpilot.filterAndHandle(connectionOptions.urlContexts)

    // Handle any links remaining in unhandledURLContexts.
}

func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    // Handle Userpilot deep links.
    let unhandledURLContexts = userpilot.filterAndHandle(URLContexts)

    // Handle any links remaining in unhandledURLContexts.
}
```

If your app uses only an App delegate, add the following:

```swift
func application(_ application: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:] ) -> Bool {
    // Handle Userpilot deep links.
    guard !userpilot.didHandleURL(url) else { return true }

    // Handle a non-Userpilot URL.
    return false
}
```

A SwiftUI app can handle the custom URL scheme as part of the `onOpenURL` modifier associated with the `Scene` of your main `App`:

```swift
var body: some Scene {
    WindowGroup {
        MyApp()
        .onOpenURL { url in
            guard !userpilot.didHandleURL(url) else { return }
        }
    }
}
```
