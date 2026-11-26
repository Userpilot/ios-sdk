# App Store review

Request the host app's native review prompt with ``Userpilot/requestReview()`` after a meaningful, completed interaction. This API is available on the current development branch.

```swift
userpilot.requestReview()
```

Objective-C:

```objc
[userpilot requestReview];
```

---

## Behavior

- Use your retained Userpilot instance. Identification is not required.
- Calls are safe from any thread; StoreKit runs on the main thread in a foreground window scene on iOS 14+. iOS 13 uses StoreKit's process-level request API.
- A request without an active app, or without a foreground scene on iOS 14+, is dropped. It is not queued for a later launch.
- The prompt concerns the host app's App Store listing, regardless of the Userpilot account token.
- Apple decides whether the prompt appears. There is no completion callback, review result, forced store redirect, or Userpilot analytics event.
- Request at an appropriate pause in the app's flow. Avoid a dedicated review button: Apple's quota can cause the button to appear unresponsive.

This is a native SDK API. Experiences do not invoke it automatically, and wrapper bridges have not been added.

## Testing

Development builds can display a test prompt; a displayed prompt does not prove that a production user will see one. StoreKit ignores these requests in TestFlight. Validate the surrounding app flow without waiting for a review result.

See Apple's [review request guidance](https://developer.apple.com/documentation/storekit/requesting-app-store-reviews) and [testing behavior](https://developer.apple.com/documentation/storekit/skstorereviewcontroller/requestreview%28%29).
