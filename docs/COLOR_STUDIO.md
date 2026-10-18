# Color Studio

[← Back to PrismDrop](../README.md)

Color Studio is included in PrismDrop 1.1 and later. Open it from the existing menu bar icon → **Open Color Studio…**. The original 186 × 62 point cursor readout retains its native Liquid Glass, reveal animation, and edge positioning.

## Pick, remember, and copy

Hold the selected modifier pair, move to a color, then release. The last successfully sampled color is saved once per pick. Pressing **C** commits and copies the current color while you keep sampling. Intermediate hover pixels are not recorded. A new activation cannot copy a stale color before its first successful sample.

History is ordered newest first. Re-picking a color moves its existing entry to the top and retains its name and favorite status. The limit is **100 non-favorites plus all favorites**. Unfavoriting a very old entry can make it eligible for that limit. Clear History removes only non-favorites; explicit Delete Color can remove any entry.

- Click a history swatch to select it and copy its six-digit HEX, regardless of the default format.
- Edit its name directly. Use the star to favorite it.
- The row menu provides all enabled export formats, foreground/background actions, and deletion.
- The top star saves the selected color as a favorite.

The selected-color **Copy** button and palette swatches use the default format. Select it in the compact top selector or the menu bar’s **Copy Format** submenu. While holding the screen shortcut, **← / →** cycles formats and the bubble shows the current choice. **⌘ ⇧ C** copies the Studio selection; ordinary **⌘ C / V** remain available for editing text.

## Formats and color spaces

All colors share the screen sampler’s **8-bit SDR sRGB** model with an independent floating-point alpha value. HEX input accepts `#RGB`, `#RGBA`, `#RRGGBB`, and `#RRGGBBAA`. Screen pixels are opaque; HEX input, native color wells, and imported images can supply alpha.

| Format | Example / behavior |
| --- | --- |
| HEX | `#5EB1F2`; intentionally omits alpha |
| HEX + alpha | `#5EB1F280`; alpha quantized to eight bits |
| RGB / RGBA | CSS `rgb(94 177 242 / 0.5)` or `rgba(94, 177, 242, 0.5)` |
| HSL / HSLA | CSS hue, saturation, lightness; alpha retained |
| HSV / HSB | Hue, saturation, value/brightness; descriptive tuples, not CSS functions |
| OKLCH | Perceptual lightness, chroma, hue, with optional alpha |
| Display P3 | ColorSync converts sRGB to `color(display-p3 …)`; it does not invent wider-gamut source detail |
| SwiftUI / AppKit | Explicit sRGB constructors with opacity / alpha |
| CSS variable | `--color-name: #RRGGBB;`, using the saved name where available |
| Tailwind | CSS `rgb(…)` values for `theme.colors` or v4 `@theme` color tokens |

Conversions use the standard sRGB transfer curve, HSL/HSV extrema formulas, [Ottosson’s OKLab transforms](https://bottosson.github.io/posts/oklab/), and native ColorSync for Display P3. Decimal formats use a fixed POSIX locale so a system decimal comma cannot break exported code. Precision is appropriate for the shared 8-bit source, rather than HDR or wide-gamut archival work.

## Image palettes

Import a PNG, JPEG, or HEIC image, drop an image/file into the Palettes tab, or choose **Paste Image** (**⌘ ⇧ V**). Images up to 100 MB are supported. Errors leave the previous successful palette available. Start a new import to replace an in-progress one, or use Cancel.

ImageIO applies orientation and decodes a thumbnail with a maximum side of 256 pixels. Core Graphics converts its embedded profile to sRGB. The extractor unpremultiplies alpha, builds a weighted histogram from every visible thumbnail pixel, then performs deterministic weighted **OKLab k-means** with up to eight clusters. Nearby clusters are merged at an OKLab distance of 0.055. Near-invisible pixels (alpha below 0.1) are excluded; returned colors preserve representative alpha. This avoids filling a palette with transparent padding or almost identical colors. Flat or limited-color images can return fewer than five meaningful colors.

Decoding and clustering run outside the main actor. Cancellation and request IDs prevent an older task from replacing a newer result. Images are not retained in the saved library.

Name the result and click **Save Palette**. Rename saved palettes in place. Click a swatch to copy the default format; right-click to export another format, use it in contrast, or remove it. Removing every swatch leaves a named empty palette that can be explicitly deleted.

## Contrast

Set each color using HEX, a native color well, **Use Color → Selected Color / history**, or **Pick on Screen**. The latter hides the panel; hold your normal picker shortcut and release to choose that role. The panel returns after a successful pick. Swap reverses foreground and background.

The preview and calculation composite the background over an explicit **white or black opaque canvas**, then the foreground over that result. Calculations keep double precision through compositing and apply WCAG’s sRGB relative luminance formula. The canvas matters whenever the background has alpha. HEX inputs update live at six/eight digits; submit or leave the field to apply shorthand. Invalid text never replaces the last valid color.

| Text | AA | AAA |
| --- | --- | --- |
| Normal | 4.5:1 | 7:1 |
| Large (18 pt regular / 14 pt bold) | 3:1 | 4.5:1 |

Pass/fail uses the **unrounded** ratio. The suggestion tool finds the closest passing 8-bit sRGB foreground by **Euclidean RGB distance**, preserving the current alpha whenever any passing color exists at that alpha. For each red/green pair, contrast bounds give valid blue intervals; checking the blue nearest the original finds the global minimum across that RGB gamut without testing all 16 million colors. If transparency makes the target impossible, it tries an opaque foreground and labels that change. Each returned color is checked again against the chosen target. Some backgrounds cannot support 7:1 with any foreground. RGB distance is an explicit numeric definition of closeness; it does not guarantee a hue-preserving or perceptually uniform adjustment.

Use **Copy** to copy the suggestion in your default format, or **Use** to apply it. Suggestions run asynchronously; ratios, previews, and pass/fail update immediately. These checks follow [WCAG 2.x contrast guidance](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html) and do not establish accessibility of an entire interface.

## Feature switches and saved data

Use **Settings** or the menu bar’s **Features** submenu to toggle the eyedropper, history, developer formats, palettes, and contrast independently. Disabled tools display a clear turn-on action. Disabling history stops recording; disabling formats restores HEX copying while retaining the preferred format. Disabling palettes cancels extraction. Saved data is kept.

- Library: `~/Library/Application Support/PrismDrop/library.json`, schema version 1.
- Preferences: the existing app’s `UserDefaults`, including the original hotkey choice.
- Writes are atomic and serialized off the main thread, and drained at normal quit.
- Read, validation, and unsupported-schema errors block overwriting the original file. Retry reloads it after repair; Reveal locates it in Finder.
- Write errors keep in-memory changes and expose Retry. Restore storage access and retry before quitting.

## Verification

`./scripts/test.sh` tests conversions against reference values, alpha export, WCAG boundary ratios/compositing, passing suggestions, recency/favorites, JSON reload/corruption protection, PNG/JPEG/HEIC decoding, deterministic extraction and near-color merging, clipboard/paste/drop integration, request cancellation, persistent switches, and the production picker’s input/copy/release/edge paths. It uses temporary libraries and preferences and restores clipboard contents.

`./scripts/render-studio.sh` renders the five production tabs with an isolated fixture library. Universal compilation and bundle validation remain in `./build.sh` and `./scripts/verify.sh`. Direct input-handler tests do not establish actual system event delivery without Input Monitoring; screen sampling and physical hotkey behavior still depend on the installed app’s macOS grants.
