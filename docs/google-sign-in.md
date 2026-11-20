# Google sign in and sign out

Android and iOS share GoogleAccountProvider and AuthRepository. UI and task code must not use SDK-specific accounts or platform checks. Android uses AuthorizationClient pinned to an account chosen through Android; iOS uses google_sign_in. Tokens are held in memory and never logged or saved.

## Configuration

Android: enable the Tasks API and configure an Android OAuth client for chimin.remindme and the signing certificate used by the build. No Google identity login or server refresh token is needed.

iOS: copy ios/Flutter/Google.example.xcconfig to the ignored Google.xcconfig and supply the iOS OAuth client ID and reversed client ID. Also pass --dart-define=GOOGLE_IOS_CLIENT_ID=<the same client ID> when building/running Flutter. Configure the iOS OAuth bundle ID and enable Tasks API. The adapter reports a configuration error when the Dart client ID is missing. GOOGLE_WEB_CLIENT_ID remains optional for the iOS adapter.

## Behavior

A signed-out foreground app immediately starts sign in. Cancellation blocks task access with Retry; it does not repeatedly reopen Google UI. Signed-in users can work with cached task lists offline. Signing in again always targets the saved email. Signing out discards local data only after confirmation and does not revoke Google access.

Old caches have no recorded owner. Signing in after an upgrade verifies access to all remembered task-list IDs before uploads; if the list has been deleted or belongs to another account, users must choose their original account or explicitly discard the cache. No automatic account fallback is allowed.

Background workers restore the same provider without an Activity. A process-wide storage lease prevents concurrent foreground/worker Hive access. Workers defer while the foreground engine owns storage. Both platforms retain the daily schedule, subject to OS scheduling; Android force-stop and iOS force-quit prevent expected background execution. iOS validates on a macOS host with Xcode and real OAuth configuration.

## Patrol E2E prerequisite

Before every run, manually revoke Remind Me access from the dedicated test Google account so the Google Tasks consent prompt appears again. The test never revokes Google consent automatically. Clearing local app data is not enough.

Both the full lifecycle test and the sign-in-only check must observe the Google Tasks permission description and capture `04_tasks_consent.png`. Reaching Home without that prompt fails the test and explains the manual reset requirement.
