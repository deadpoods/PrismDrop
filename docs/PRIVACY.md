# Privacy

[← Back to PrismDrop](../README.md)

PrismDrop runs locally. The app has no networking code, telemetry, account system, or analytics. It does not write captured images to disk and does not request audio capture.

## What it observes

While the app is running and Input Monitoring is allowed, a listen-only event tap observes modifier changes and key-down events. PrismDrop uses them to recognize the selected modifier pair and the C copy key while sampling. It does not record keystroke history, suppress keys, or post input.

While the activation pair is held, ScreenCaptureKit requests the one-point region beneath the pointer. The app converts the relevant captured pixel to sRGB. Screen Recording is a broad operating-system grant even though the app requests only this small region.

## What persists

- The selected hotkey pair is stored locally in `UserDefaults`.
- The last sampled color stays in the running process so **Copy Last HEX** can work after dismissal.
- A copied HEX is placed on the macOS clipboard when you request it. Other software with clipboard access may read it, as with any copied text.
- Permission state and capture errors may appear in local macOS diagnostic logs. Screen images are not logged by PrismDrop.

Quit the app or revoke its grants in **System Settings → Privacy & Security** to stop access. The GitHub repository, image assets, and documentation are separate from the app's runtime; external badges in the README are loaded by GitHub or your browser, not PrismDrop.
