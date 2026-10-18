# PrismDrop artwork

`PrismDrop.png` is the master image for the app icon. `PrismDrop.icns` packages standard macOS icon sizes from 16 to 1024 pixels. Regenerate the package with:

```sh
./scripts/make-icon.sh
```

The artwork was created using the built-in image generation tool, then resized and packaged locally. It combines the name's two ideas: a droplet silhouette and a faceted optical prism, rendered in clear glass over a frosted tile. It is artwork for the app identity; the runtime Liquid Glass UI is supplied separately by Apple's native SwiftUI API.

## Final artwork brief

> One front-facing macOS app icon: a large clear glass droplet with broad optical prism facets, restrained spectral refraction, crisp white highlights, and a pale frosted silver-blue rounded-square tile. Keep a simple silhouette readable at small sizes, even transparent margins, and no text, heavy black shadow, neon glow, or extra objects. Refine the tile silhouette and remove detached marks outside it.

The master retains the generated alpha channel. The icon conversion changes size and format; it does not recolor the artwork.
