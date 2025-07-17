# Userpilot Objective-C Example App

This is a simple iOS app that integrates with Userpilot iOS SDK using [Swift Package Manager](https://swift.org/package-manager/).

## 🚀 Setup

This example app requires you to fill in an Userpilot Token before the app will compile. You can enter your own values found in [Environments Page](https://run.userpilot.io/environment)

## ✨ Functionality

The example app demonstrates the core functionality of the Userpilot iOS SDK across 4 screens.

### Identify Screen

This screen is identified as `Identify` for screen targeting.

Provide a User ID for use with `[Userpilot identifyWithUserId:]` or select an anonymous ID using `[Userpilot anonymous]`.

### Events Screen

This screen is identified as `Trigger Events` for screen targeting.

Two buttons demonstrate `[Userpilot trackWithEventName:]` calls.

### Screens Flow

This screen is identified as `Screen One & Screen Two` for screen targeting.
