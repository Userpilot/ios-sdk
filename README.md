# Userpilot iOS SDK
<!-- Banner Image -->

<p align="center">
  <a href="https://userpilot.com/">
    <img alt="userpilot sdk" height="128" src="./.github/resources/banner.png">
  </a>
</p>

<p align="center">
  <a href="https://cocoapods.org/pods/Userpilot">
    <img src="https://img.shields.io/cocoapods/v/Userpilot?style=for-the-badge" alt="Cocoapods">
  </a>
  &nbsp;
  <a href="https://github.com/Userpilot/ios-sdk">
    <img src="https://img.shields.io/badge/-documentation-informational?style=for-the-badge" alt="Documentation">
  </a>
  &nbsp;
  <a href="https://github.com/Userpilot/ios-sdk/blob/main/LICENSE">
    <img src="https://img.shields.io/badge/license-MIT-green.svg?style=for-the-badge" alt="License">
    <a href="https://swiftpackageindex.com/Userpilot/ios-sdk">
    <img src="https://img.shields.io/badge/Swift%20Package%20Manager-compatible-brightgreen?style=for-the-badge" alt="SPM Compatible">
  </a>
    <a href="https://swiftpackageindex.com/Userpilot/ios-sdk">
    <img src="https://img.shields.io/badge/Swift-5.0%2B-blue.svg?style=for-the-badge" alt="Swift 5.0+">
  </a>
</p>


<h6 align="center">Follow us on</h6>
<p align="center">
  <a aria-label="Follow @userpilot on X" href="https://twitter.com/teamuserpilot" target="_blank">
    <img alt="Userpilot on X" src="https://img.shields.io/badge/X-000000?style=for-the-badge&logo=x&logoColor=white" target="_blank" />
  </a>&nbsp;
  <a aria-label="Follow @userpilot on GitHub" href="https://github.com/Userpilot/android-sdk" target="_blank">
    <img alt="Userpilot on GitHub" src="https://img.shields.io/badge/GitHub-222222?style=for-the-badge&logo=github&logoColor=white" target="_blank" />
  </a>&nbsp;
  <a aria-label="Follow @userpilot on Youtube" href="https://www.youtube.com/@userpilot" target="_blank">
    <img alt="Userpilot on Youtube" src="https://img.shields.io/badge/Youtube-FF0000?style=for-the-badge&logo=youtube&logoColor=white" target="_blank" />
  </a>&nbsp;
  <a aria-label="Follow @userpilot on Facebook" href="https://www.facebook.com/userpilot" target="_blank">
    <img alt="Userpilot on Facebook" src="https://img.shields.io/badge/Facebook-4267B2?style=for-the-badge&logo=facebook&logoColor=white" target="_blank" />
  </a>&nbsp;
  <a aria-label="Follow @userpilot on LinkedIn" href="https://www.linkedin.com/company/teamuserpilot/" target="_blank">
    <img alt="Userpilot on LinkedIn" src="https://img.shields.io/badge/LinkedIn-0077B5?style=for-the-badge&logo=linkedin&logoColor=white" target="_blank" />
  </a>
</p>

## Introduction

Userpilot iOS SDK enables you to capture user insights and deliver personalized in-app experiences in real time. With just a one-time setup, you can immediately begin leveraging Userpilot’s analytics and engagement features to understand user behaviors and guide their journeys in-app.

This document provides a step-by-step walkthrough of the installation and initialization process, as well as instructions on using the SDK’s public methods.

## Table of contents

- [Userpilot iOS SDK](#ios-sdk)
  - [🚀 Getting Started](#-getting-started)
    - [Installation](#installation)
      - [Prerequisites](#prerequisites)
      - [Cocoapods](#cocoapods)
      - [Swift Package Manager](#swift-package-manager)
    - [Initializing](#initializing)
    - [Using the SDK](#using-the-SDK)
    - [Configurations](#Configurations-(Optional))
  - [📚 Documentation](#-documentation)
  - [🎬 Samples](#-samples)
  - [📄 License](#-license)

## 🚀 Getting Started

### Installation

Add the Userpilot iOS SDK package to your app. There are several supported installation options.

#### Prerequisites

Before you begin, ensure your iOS project meets the following requirements:

- **iOS Deployment Target:** 13 or higher.
- **Xcode:** Version 15 or higher.

#### CocoaPods

1. Add the Userpilot dependency to your `Podfile`:
    
    ```ruby
    target 'YourTargetName' do
      pod 'Userpilot'
    end
    ```
    
2. Run `pod install` in your project directory.

#### Swift Package Manager

1. In Xcode, navigate to **File -> Add Packages**.
2. Enter the package URL: https://github.com/Userpilot/ios-sdk.
3. For **Dependency Rule**, select **Up to Next Major Version**.
4. Click **Add Package**.

Once integrated, the Userpilot SDK is available throughout your application.

### Initializing

To use Userpilot, initialize it once in your App Delegate or Scene Delegate during app launch. This ensures the SDK is ready as soon as your app starts. Replace `<APP_TOKEN>` with your Application Token, which can be fetched from your [Environments Page](https://run.userpilot.io/environment).

**Example (App Delegate):**

```swift
import Userpilot

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var userpilot: Userpilot?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        userpilot = Userpilot(config: Userpilot.Config(token: "<APP_TOKEN>"))
    }
}
```

### Using the SDK

Once initialized, the SDK provides straightforward methods for identifying users, tracking events, and screen views.

#### Identifying Users (Required)

This method is used to identify unique users and companies (groups of users) and set their properties. Once identified, all subsequent tracked events and screens will be attributed to that user.

**Recommended Usage:**

- **On user authentication (login):** Immediately call `identify` when a user signs in to establish their identity for all future events.
- **On app launch for authenticated users:** If the user has a valid authenticated session, call `identify` at app launch.
- **Upon property updates:** Whenever user or company properties change.

##### &nbsp;&nbsp;&nbsp; Method:

```swift
userpilot?.identify(
    userId: "<USER_ID>",
    userProperties: [
        "name": "John Doe",
        "email": "user@example.com",
        "created_at": "2019-10-17",
        "role": "Admin"
    ],
    company: [
        "id": "<COMPANY_ID>",
        "name": "Acme Labs",
        "created_at": "2019-10-17",
        "plan": "Free"
    ]
)
```

**Properties Guidelines:**

- Key `id` is required in company properties to identify a unique company.
- Userpilot supports String, Numeric, and Date types.
- Send date values in ISO8601 format.
- If you are planning to use Userpilot’s localization features, make sure you are passing user property `locale_code` with a value that adheres to ISO 639-1 format.
- Use reserved property keys:
    - `email` for the user’s email.
    - `name` for the user’s or company’s name.
    - `created_at` for the user’s or company’s signup date.

**Notes:**

- Ensure the User ID source is consistent across Web, Android, and iOS.
- While properties are optional, setting them enhances Userpilot’s segmentation capabilities.

#### Tracking Screens

Call `screen` whenever the user navigates to a particular screen. Tracking screens helps contextualize subsequent events and identifies.

##### &nbsp;&nbsp;&nbsp; Method:

```swift
userpilot.screen("Profile Screen")
```

#### Tracking Events

Log any meaningful action the user performs. Events can be button clicks, form submissions, or any custom activity you want to analyze. Optionally, pass metadata to provide context.

##### &nbsp;&nbsp;&nbsp; Method:

```swift
userpilot.track("Added to Cart", properties: ["itemId": "sku_456", "price": 29.99])
```

#### Logging Out

When a user logs out, call `logout` to clear the current user context. This ensures subsequent events are no longer associated with the previous user.

##### &nbsp;&nbsp;&nbsp; Method:

```swift
userpilot.logout()
```

#### Anonymous Users

If a user is not authenticated, call `anonymous` to track events without a user ID. This is useful for pre-signup flows or guest sessions.

##### &nbsp;&nbsp;&nbsp; Method:

```swift
userpilot.anonymous()
```

**Notes:**

- Anonymous users count towards your Monthly Active Users usage. Consider your MAU limits before using this method.

#### Trigger Experiences

Triggers a specific experience programmatically using its unique ID. This API allows you to manually initiate an experience within your application.

```swift
userpilot.trigger(EXPERIENCE_ID)
```

### Configurations (Optional)

If you have additional configuration needs, you can pass a custom configuration when initializing UserPilot. You can enable logging, provide navigation and experience delegates, and set up analytics listeners.

##### &nbsp;&nbsp;&nbsp; Example:

```swift
userpilot = Userpilot(
    config: Userpilot.Config(token: "APP_TOKEN")
        .logging(true) // Enable or disable logging
        .setNavigationHandler(navigationDelegate: self)
        .setExperienceDelegate(experienceDelegate: self)
)
```

#### Navigation Handler

Defines how your app handles deep link routes triggered by Userpilot experiences. Implement this to route users to the appropriate screens or external URLs.

##### &nbsp;&nbsp;&nbsp; Delegate:

```swift
@objc
public protocol UserpilotNavigationDelegate: AnyObject {
    func navigate(to url: URL, completion: @escaping (Bool) -> Void)
}
```

The UserPilot SDK automatically handles navigation if you haven't implemented the `UserPilotNavigationHandler`. When a deep link is external, the SDK will handle it appropriately. For complete control over link handling, you can override the `UserPilotNavigationHandler` protocol. This allows you to customize the behavior for all types of links as per your requirements.

#### Analytics Delegate

Receives callbacks whenever the SDK tracks an event, screen, or identifies a user. Implement this if you need to integrate with another analytics tool or log events for debugging.

##### &nbsp;&nbsp;&nbsp; Delegate:

```swift
@objc
public protocol UserpilotAnalyticsDelegate: AnyObject {
    func didTrack(analytic: UserpilotAnalytic, value: String, properties: [String: Any]?)
}

```

#### Experience Delegate

Receives callbacks when Userpilot experiences start, complete, or are dismissed, as well as changes in their step-by-step progression. Implement this if you want to pipe these data points to a destination or react to user actions.

##### &nbsp;&nbsp;&nbsp; Delegate:

```swift
@objc
public enum UserpilotExperienceState: Int {
    case started
    case completed
    case dismissed
}

@objc
public protocol UserpilotExperienceDelegate: AnyObject {
    func onExperienceStateChanged(state: UserpilotExperienceState, id: Int, experienceToken: String)
    func onExperienceStepStateChanged(id: Int, experienceToken: String, step: Int, totalSteps: Int)
}
```

## 📚 Documentation

SDK Documentation is available at https://github.com/Userpilot/ios-sdk and full Userpilot documentation is available at https://docs.userpilot.com/

## 🎬 Samples

The `samples` directory in repository contains full example iOS apps demonstrating different methods of installation and providing references for usage of the Userpilot API.

## 📄 License

This project is licensed under the MIT License. See [LICENSE](https://github.com/Userpilot/ios-sdk/blob/main/LICENSE) for more information.
