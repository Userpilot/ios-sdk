# Offline mode

Offline mode is available in SDK **1.4.0 and later**. It is always enabled and
requires no additional configuration. Identify a user, or call `anonymous()`,
before collecting events for that user.

## Supported events

When the device is offline, the SDK stores these events locally:

- Identify calls, screen views, custom events, and Auto Capture events.
- Flow views, dismissals, completions, and step views and completions.
- Survey views, dismissals, completions, responses, and step views, skips, and submissions.
- NPS views, dismissals, and feedback submissions.
- Push-notification opens, excluding test notifications.

Stored events survive app restarts. When the connection returns, the SDK sends
them together in a batch ordered by their stored timestamps, before processing
pending live events. Experience interactions and push opens are associated with
the current identified or anonymous user; they are not persisted without a user ID.

## Storage and delivery limits

- All supported event types share a limit of **3 MB** or **5,000 events**, whichever
  limit is reached first.
- New events that would exceed a limit are not stored until space becomes available.
- Switching users or logging out clears stored events to prevent them from being
  replayed for another user.
- Stored events are removed before the batch is sent. If the send fails or times
  out, that batch is not retried.
- Persistence applies when the SDK detects that the device is offline. A closed
  socket while the device still has network connectivity uses an in-memory queue;
  those queued events do not survive an app restart.

## Experiences and push notifications

Loading new experiences and themes requires a network connection. Interactions
with an experience that is already displayed can be recorded while offline.
Content/theme requests, push-token updates, and logout events are not persisted
in the offline batch. Push-token synchronization is handled separately when the
connection returns.

Tapping an already-delivered push notification can navigate within your app
without waiting for the analytics connection. The destination may still need a
network connection to load its content.
