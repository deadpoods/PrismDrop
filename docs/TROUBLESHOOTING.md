# Troubleshooting

[← Back to PrismDrop](../README.md)

## No menu bar icon

Open `~/Applications/PrismDrop.app` and check hidden menu bar items. PrismDrop intentionally has no Dock icon or main window. Activity Monitor can confirm whether the process is running.

## The shortcut does nothing

Check **Input Monitoring** in PrismDrop's menu. Allow the exact installed bundle and quit/reopen it. Try on the desktop or in a plain text editor; secure input fields and other system shortcuts can interfere with global key observations. Both selected modifiers must be held.

## Screen access needed or capture unavailable

Enable **Screen & System Audio Recording** / **Screen Recording**, then quit and reopen. See [how to add the app with the + button](INSTALLATION.md#if-the-app-is-missing-from-a-list). If a monitor was changed and capture stays unavailable, relaunch to refresh the display list. The menu includes the most recent capture error.

## Permissions after a rebuild

A freshly ad-hoc signed app may fail to match an existing macOS privacy entry. Confirm the installed path first. If toggling that specific app's grant does not help, clear only PrismDrop's stale screen entry:

```sh
tccutil reset ScreenCapture local.prismdrop.app
```

Quit and reopen PrismDrop, request Screen Recording from its menu, enable it in settings, then reopen once more. If Input Monitoring has the same problem, reset it separately:

```sh
tccutil reset ListenEvent local.prismdrop.app
```

These commands remove PrismDrop's existing approvals; they do not grant access. The user must approve the installed app through macOS again. Avoid systemwide permission resets.

## Color appears different

Compare well inside a known flat SDR sRGB fill, away from antialiased edges and the pointer graphic. The app reports captured sRGB bytes. It does not measure physical screen light, display brightness, or retain arbitrary HDR and wide-gamut colors. Protected content can be blacked out by macOS. During fast movement, wait for the latest capture to arrive.

## Copy does not work or types into another app

Hold both selected modifiers and press **C** once. Check Input Monitoring. **Copy Last HEX** in the menu is an alternative after a successful sample. Because the event tap is listen-only, the chord also passes to the foreground app.

## Build cannot find glassEffect

Select Xcode 26 or Command Line Tools for Xcode 26 or later. The macOS 26 SDK is needed at compile time even though the app checks API availability at runtime and targets macOS 14. Inspect the selected tools with:

```sh
xcode-select -p
xcrun --show-sdk-version
xcrun swiftc --version
```

## Local diagnostic

```sh
~/Applications/PrismDrop.app/Contents/MacOS/PrismDrop --diagnose
```

This prints display information and a sample. macOS can attribute a shell-launched process's privacy checks to **Terminal**, so its reported grants can differ from the installed app's. Prefer the menu for app permission status.

When opening an issue, include macOS version, architecture, display arrangement/scaling, permission state, expected behavior, and the reproduction steps. Review logs or images for private information before sharing.
