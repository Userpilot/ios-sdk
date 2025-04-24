# Manually Configuring Push Notifications

The Userpilot iOS SDK supports receiving push notification so you can reach your users whenever the moment is right.

There are two options for configuring push notification: automatic or manual.

> Tip: Automatic configuration is the quickest and simplest way to configure push notifications and is recommended for most customers. Refer to <doc:PushNotifications> for automatic configuration instructions.


## Prerequisites

It is recommended to have [configured your iOS push settings in Userpilot Studio](https://run.userpilot.io/settings/mobile) before configuring push notifications in your app.

## Manual App Configuration

### Step 1. Enable push capabilities

In Xcode, navigate to the Signing & Capabilities section of your main app target and add the Push Notifications capability.

### Step 2. Register for push notifications

```swift
// AppDelegate.swift

func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    application.registerForRemoteNotifications()

    // ...
}
```

### Step 3. Set push token for Userpilot

Call ``Userpilot/setPushToken(_:)`` from `UIApplicationDelegate.application(_:didRegisterForRemoteNotificationsWithDeviceToken:)` to pass the APNs token from calling `registerForRemoteNotifications()` to Userpilot.

```swift
// AppDelegate.swift

func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    userpilotInstance.setPushToken(deviceToken)
}
```

### Step 4. Enable push response handling

Update your `AppDelegate` to conform to the `UNUserNotificationCenterDelegate` protocol and assign `self` the delegate in `application(_:didFinishLaunchingWithOptions:)`.

Implement `userNotificationCenter(_:didReceive:withCompletionHandler:)` and pass the received notification response to ``Userpilot/didReceiveNotification(response:completionHandler:)``.

```swift
// AppDelegate.swift

@main
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        application.registerForRemoteNotifications()
        UNUserNotificationCenter.current().delegate = self

        // ...
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if userpilotInstance.didReceiveNotification(response: response, completionHandler: completionHandler) {
            // NOTE: Userpilot calls the completion handler if the notification is an Userpilot notification.
            return
        }

        completionHandler()
    }
}
```


### Step 5. Configure foreground handling

Configure handling of push notifications received while your app is in the foreground by implementing `userNotificationCenter(_:willPresent:withCompletionHandler:)`.

```swift
// AppDelegate.swift

func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    completionHandler([.banner, .list])
}
```


#### Example
For more details refer to [AppDelegate+PushNotification.swif](https://github.com/Userpilot/ios-sdk/blob/main/Sample/UserPilotSample/UserpilotSample/AppDelegate+PushNotification.swift)
