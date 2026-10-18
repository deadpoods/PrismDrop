# Contributing

Keep PrismDrop small, native, and easy to inspect. Focused issues and pull requests are welcome.

## Build and check

Use Xcode 26 or its Command Line Tools or later with the macOS 26 SDK:

```sh
./build.sh
./scripts/test.sh
./scripts/verify.sh
./scripts/package.sh
```

The workflow performs the same universal build, feature tests, and bundle checks on GitHub's macOS 26 runner. It does not grant privacy permissions or automate real screen sampling.

## Runtime checks that matter

- Hold the selected modifier pair: show and update the readout across known flat colors.
- Press C while held: verify the selected format on the clipboard (HEX by default). Release either modifier: dismiss without stale UI.
- Test display edges, scaling, and any available second monitor.
- Test missing/revoked permissions and recovery after relaunch.
- Check Reduce Motion and the older material fallback on a supported older OS when available.
- Verify a chord passed through to a foreground app does not cause unexpected assumptions about input suppression.

Do not describe a scenario as tested unless it was exercised. Pure compile checks cannot establish runtime compatibility across every supported Mac.

## Source and assets

The app lives in `Source/`; `PrismDrop.swift` retains the original capture and cursor overlay. Build/install scripts are zsh. There are no package dependencies. Keep new behavior consistent with local-only capture and avoid introducing accounts or networking without discussing the product change.

After editing source or configuration, run `python3 scripts/source-listing.py` to refresh the complete listing. To regenerate the icon sizes, run `./scripts/make-icon.sh`. Documentation visuals can be rebuilt with `./scripts/render-docs.sh`; that optional tool requires Screen Recording access for the invoking terminal because it captures only its own presentation window.

`./scripts/render-studio.sh` renders all five production Studio tabs using an isolated temporary library and the app icon as an extraction fixture. It needs no screen permission and writes to `.render-docs/studio/`.

The documentation renderer reuses the production SwiftUI overlay with scripted sample values. Keep those previews honest about what they demonstrate.
