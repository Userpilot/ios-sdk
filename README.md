# Userpilot iOS SDK

![version](https://img.shields.io/github/v/tag/Userpilot/ios-sdk?label=version)
[![Documentation](https://img.shields.io/badge/Documentation-blue.svg)](https://docs.userpilot.com/article/313-install-userpilot-on-your-ios-app)
[![Swift Package Manager compatible](https://img.shields.io/badge/Swift%20Package%20Manager-compatible-brightgreen.svg)](https://github.com/apple/swift-package-manager)
[![CocoaPods compatible](https://img.shields.io/badge/CocoaPods-compatible-red.svg)](https://cocoapods.org/pods/Userpilot)
[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](https://github.com/Userpilot/ios-sdk/blob/main/LICENSE)
[![Platform](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FUserpilot%2Fios-sdk%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/Userpilot/ios-sdk)
[![Swift version](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FUserpilot%2Fios-sdk%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/Userpilot/ios-sdk)

## Introduction

Userpilot iOS SDK enables you to capture user insights and deliver personalized in-app experiences in real time. With just a one-time setup, you can immediately begin leveraging Userpilot’s analytics and engagement features to understand user behaviors and guide their journeys in-app.

This document provides a step-by-step walkthrough of the installation and initialization process, as well as instructions on using the SDK’s public APIs.

## Table of contents

- [Userpilot iOS SDK](#ios-sdk)
  - [🚀 Getting Started](#-getting-started)
    - [Installation](#installation)
      - [Prerequisites](#prerequisites)
      - [Cocoapods](#cocoapods)
      - [Swift Package Manager](#swift-package-manager)
    - [Initializing](#initializing)
    - [Using the SDK](#using-the-SDK)
    - [Configurations](#configurations-optional)
    - [Push Notification](#push-notification)
 - [📝 Documentation](#-documentation)
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

##### &nbsp;&nbsp;&nbsp; App Delegate:

```swift

func application(_ application: UIApplication,
                didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    userpilot = Userpilot(config: Userpilot.Config(token: "<APP_TOKEN>"))
}

```

### Using the SDK

Once initialized, the SDK provides straightforward APIs for identifying users, tracking events, and screen views.

#### Identifying Users (Required)

This API is used to identify unique users and companies (groups of users) and set their properties. Once identified, all subsequent tracked events and screens will be attributed to that user.

**Recommended Usage:**

- **On user authentication (login):** Immediately call `identify` when a user signs in to establish their identity for all future events.
- **On app launch for authenticated users:** If the user has a valid authenticated session, call `identify` at app launch.
- **Upon property updates:** Whenever user or company properties change.

```swift
identify(
    userId: "<USER_ID>",
    properties: [String: Any]? = nil,
    company: [String: Any]? = nil
)
```

##### &nbsp;&nbsp;&nbsp; Example:

```swift
userpilot.identify(
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

#### Tracking Screens (Required)

Calling screen is crucial for unlocking Userpilot’s core engagement and analytics capabilities. When a user navigates to a particular screen, invoking screen records that view and triggers any eligible in-app experiences. Subsequent events are also attributed to the most recently tracked screen, providing context for richer analytical insights. For these reasons, we strongly recommend tracking all of your app’s screen views.

```swift
userpilot.screen("Profile")
```

#### Tracking Events

Log any meaningful action the user performs. Events can be button clicks, form submissions, or any custom activity you want to analyze. Optionally, pass metadata to provide context.

```swift
userpilot.track("Added to Cart", properties: ["itemId": "sku_456", "price": 29.99])
```

#### Logging Out

When a user logs out, call `logout` to clear the current user context. This ensures subsequent events are no longer associated with the previous user.

```swift
userpilot.logout()
```

#### Anonymous Users

If a user is not authenticated, call `anonymous` to track events without a user ID. This is useful for pre-signup flows or guest sessions.

```swift
userpilot.anonymous()
```

**Notes:**

- Anonymous users count towards your Monthly Active Users usage. Consider your MAU limits before using this API.

#### Trigger Experiences

Triggers a specific experience programmatically using its unique ID. This API allows you to manually initiate an experience within your application.

```swift
userpilot.triggerExperience("<EXPERIENCE_ID>")
```

### **Configurations (Optional)**

If you have additional configuration needs, you can pass a custom configuration when initializing Userpilot. You can enable logging, provide navigation and experience delegates, and set up analytics listeners.

```swift
userpilot = Userpilot(
    config: Userpilot.Config(token: "APP_TOKEN")
        .logging(true) // Enable or disable logging.
        .enableUseInAppBrowser(enabled: true) // Enable Open external link In-app browser using SFSafariViewController.
        .disableRequestPushNotificationsPermission() // Disable request push notifications permission by SDK.
)
userpilot.navigationDelegate = self
userpilot.analyticsDelegate = self
userpilot.experienceDelegate = self
```

#### Navigation Handler

Defines how your app handles deep link routes triggered by Userpilot experiences. Implement this to route users to the appropriate screens or external URLs.

```swift
@objc
public protocol UserpilotNavigationDelegate: AnyObject {
    func navigate(to url: URL)
}
```

The Userpilot SDK automatically handles navigation if you haven't implemented the `UserpilotNavigationHandler`. When a deep link is external, the SDK will handle it appropriately. For complete control over link handling, you can override the `UserpilotNavigationHandler` protocol. This allows you to customize the behavior for all types of links as per your requirements.

#### Analytics Delegate

Receives callbacks whenever the SDK tracks an event, screen, or identifies a user. Implement this if you need to integrate with another analytics tool or log events for debugging.

```swift
@objc
public enum UserpilotExperienceType: Int {
    case flow
    case survey
    case nps
}

@objc
public enum UserpilotExperienceState: Int {
    case started
    case completed
    case dismissed
    case skipped
    case submitted
}

/// A protocol to observe and respond to state changes in Userpilot experiences.
@objc
public protocol UserpilotExperienceDelegate: AnyObject {

    /// Called when the state of a Userpilot experience changes.
    ///
    /// - Parameters:
    ///   - experienceType: The current experience type.
    ///   - experienceId: A unique identifier for the experience.
    ///   - experienceState: The current state of the experience.
    func onExperienceStateChanged(
        experienceType: UserpilotExperienceType,
        experienceId: NSNumber?, // Optional Int
        experienceState: UserpilotExperienceState
    )

    /// Called when the state of a specific step within a Userpilot experience changes.
    ///
    /// - Parameters:
    ///   - experienceType: The current experience type.
    ///   - experienceId: A unique identifier for the experience.
    ///   - stepId: A unique identifier for the step.
    ///   - stepState: The current state of the step.
    ///   - step: The current step number in the experience.
    ///   - totalSteps: The total number of steps in the experience.
    func onExperienceStepStateChanged(
        experienceType: UserpilotExperienceType,
        experienceId: NSNumber,
        stepId: NSNumber,
        stepState: UserpilotExperienceState,
        step: NSNumber?,
        totalSteps: NSNumber?
    )
}

```

#### Experience Delegate

Receives callbacks when Userpilot experiences start, complete, or are dismissed, as well as changes in their step-by-step progression. Implement this if you want to pipe these data points to a destination or react to user actions.

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

### Push Notification

Userpilot SDK supports handling push notifications to help you deliver targeted messages and enhance user engagement. For setup instructions, and integration details, please refer to the [Push Notifications Guide](https://docs.userpilot.com/article/313-install-userpilot-on-your-ios-app).

## 📝 Documentation

Full documentation is available at [Userpilot Documentation](https://docs.userpilot.com/)

## 🎬 Samples

The `Sample` directory in repository contains a full example swift app providing references for usage of the Userpilot API.

## 📄 License

This project is licensed under the MIT License. See [LICENSE](https://github.com/Userpilot/ios-sdk/blob/main/LICENSE) for more information.
