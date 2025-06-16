# Userpilot SDK - Deep Link Integration

## Overview

The **Userpilot SDK** supports deep linking to navigate to specific screens in your app using a custom URL scheme or an external URL. This guide will walk you through how to configure deep links in your Android app to trigger your app screens.


## Custom URL Format

To trigger a deep link, use the following custom URL format:

```
{SCHEMA}://{HOST}
```

For example:  
`userpilot-sample://news_feed`


### Step 1: Initialize the SDK and Set a Navigation Delegate

During the SDK initialization, pass a `navigationDelegate` to handle deep link navigation:

```swift
Userpilot(config: Userpilot.Config(token: appToken)
    .setNavigationHandler(navigationDelegate: self))
```


### Step 2: Implement the Navigation Delegate

Conform to the `UserpilotNavigationDelegate` protocol to handle the deep link URL and navigate to the appropriate screen:

```swift
extension CustomClass: UserpilotNavigationDelegate {

    func navigate(to url: URL) {
        if url.scheme == "userpilot-example" {
            guard let destination = url.host else {
                return
            }
            if destination == "demo" {
                FlowRoutingManager.shared.openViewController(DeepLinkViewController.newInstance())
            } else if destination == "identify" {
                FlowRoutingManager.shared.openViewController(IdentifyViewController.newInstance())
            } else if destination == "screen_one" {
                FlowRoutingManager.shared.openViewController(ScreenOneViewController.newInstance())
            } else if destination == "screen_two" {
                FlowRoutingManager.shared.openViewController(ScreenTwoViewController.newInstance())
            }
        } else if url.scheme?.contains("http") == true || url.scheme?.contains("https") == true {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
}
```

