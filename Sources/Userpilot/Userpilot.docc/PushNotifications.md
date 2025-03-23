# Configuring Push Notifications

The Userpilot iOS SDK supports receiving push notification so you can reach your users whenever the moment is right.

There are two options for configuring push notification: automatic or manual.

> Tip: Automatic configuration is the quickest and simplest way to configure push notifications and is recommended for most customers. Refer to <doc:PushNotificationsManually> for manual configuration instructions.

## Prerequisites

It is recommended to have [configured your iOS push settings in Userpilot settings Studio](https://nxtg-dev-nxtapp-11707.userpilot.io/settings/mobile) before configuring push notifications in your app.

## Enabling Push Notification Capabilities

In Xcode, navigate to the Signing & Capabilities section of your main app target and add the Push Notifications capability.

## Automatic App Configuration

Automatic configuration takes advantage of swizzling to automatically provide the necessary implementations of the required `UIApplicationDelegate` and `UNUserNotificationCenterDelegate` methods.

To enable automatic configuration, call ``Userpilot/enableAutomaticPushConfig()`` from `UIApplicationDelegate.application(_:didFinishLaunchingWithOptions:)`.

```swift
// AppDelegate.swift

func application(
    _ application: UIApplication, didFinishLaunchingWithOptions
    launchOptions: [UIApplication.LaunchOptionsKey: Any]?
) -> Bool {
    // Automatically configure for push notifications
    Userpilot.enableAutomaticPushConfig()

    // Override point for customization after application launch.
}
```

Automatic configuration seamlessly integrates with your app's existing push notification handling. It processes only Userpilot notifications, while ensuring that all other notifications continue to be handled by your app’s original logic.

