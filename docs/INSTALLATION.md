# Install PrismDrop

[← Back to PrismDrop](../README.md)

## Requirements

| To run | To build |
| --- | --- |
| macOS 14 or later | macOS with Xcode 26 or Command Line Tools for Xcode 26 or later |
| Intel or Apple silicon | macOS 26 SDK, `swiftc`, `lipo`, `codesign` |
| Screen Recording and Input Monitoring grants | No third-party packages |

Native Liquid Glass is available on macOS 26 and later. The app uses an ultra-thin material on older supported versions.

## Download the app

1. Download the universal ZIP from [Releases](https://github.com/deadpoods/PrismDrop/releases).
2. Unzip it and move **PrismDrop.app** into your home Applications folder: `~/Applications`.
3. Open it. Look for the eyedropper icon in the menu bar; there is no Dock icon or main window.

The ZIP includes an ad-hoc signed app, not a Developer ID signed or notarized distribution. If Gatekeeper blocks it, inspect the repository and build locally, or review **System Settings → Privacy & Security → Open Anyway** for this specific app. Avoid disabling Gatekeeper systemwide.

An adjacent `.sha256` release file lets you check a downloaded archive:

```sh
shasum -a 256 -c PrismDrop-1.0.0-universal.zip.sha256
```

Run that command from the directory containing both the ZIP and its checksum file.

## Build and install

```sh
git clone https://github.com/deadpoods/PrismDrop.git
cd PrismDrop
./build.sh
./install.sh
```

`build.sh` compiles Intel and Apple silicon slices, combines them into `build/PrismDrop.app`, adds the icon, and ad-hoc signs the bundle. `install.sh` installs into `~/Applications` and launches it. You can also open the build directly:

```sh
open build/PrismDrop.app
```

Keep one installed copy and grant permissions for that copy. Moving between differently built copies can confuse macOS's privacy identity checks.

## Permissions

PrismDrop needs two grants in **System Settings → Privacy & Security**:

| Permission | Why it is needed |
| --- | --- |
| **Screen & System Audio Recording** / **Screen Recording** | Read the screen region beneath the cursor. PrismDrop does not request audio capture. |
| **Input Monitoring** | Observe the global modifier pair and copy key through a listen-only Core Graphics event tap. |

1. Click PrismDrop's menu bar icon.
2. Choose **Screen Recording: Needs permission** and allow the macOS request.
3. Choose **Input Monitoring: Needs permission** and allow that request.
4. Enable the exact installed **PrismDrop.app** in the relevant settings lists.
5. Quit and reopen PrismDrop. Its menu should show both as **Allowed**.

### If the app is missing from a list

In **Screen & System Audio Recording**, click the **+** beneath the screen-recording list. Authenticate with Touch ID or your Mac password if asked. In the file chooser, press **Command + Shift + G**, enter `~/Applications/PrismDrop.app`, press Return, and click **Open**. Enable the app, then quit and reopen it.

Use the same file-chooser steps in **Input Monitoring** if necessary. On versions that organize these panes differently, use the settings search field to locate the permission by name.

### After rebuilding

An ad-hoc signature can change after a rebuild. macOS may require a new approval even if the same app name is visible. `install.sh` reuses an unchanged build to reduce this churn. Follow the [targeted permission recovery steps](TROUBLESHOOTING.md#permissions-after-a-rebuild) if toggling a grant is not enough.

## First use

Hold **Option + Shift** over a color. The readout should appear and update as you move. While holding, press **C** and paste the result into a text field to check the copied HEX. Release either modifier to dismiss the bubble.

## Remove

From the cloned project:

```sh
./uninstall.sh
```

Or quit PrismDrop and remove `~/Applications/PrismDrop.app` in Finder. The script does not remove your local hotkey preference or reset privacy grants; those can be removed separately in macOS settings.
