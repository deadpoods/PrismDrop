import AppKit
import SwiftUI

@MainActor
private final class StudioRenderer: NSObject, NSApplicationDelegate {
    var window: StudioWindow!
    func applicationDidFinishLaunching(_ notification: Notification) {
        let root = URL(fileURLWithPath: CommandLine.arguments[1])
        let output = root.appendingPathComponent(".render-docs/studio", isDirectory: true)
        try! FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let suite = "PrismDrop.Rendering.\(UUID())", defaults = UserDefaults(suiteName: suite)!
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        let store = StudioStore(defaults: defaults, libraryURL: temporary.appendingPathComponent("library.json"))
        NSApp.applicationIconImage = NSImage(contentsOf: root.appendingPathComponent("Assets/PrismDrop.png"))
        let colors = ["5EB1F2", "A4A6E8", "70C7AB", "EBAF82", "D77C9D", "273443"].map { SampledColor(hex: $0)! }
        for color in colors.reversed() { store.acceptPicked(color, finished: true) }
        for (index, entry) in store.library.history.enumerated() { store.renameColor(entry.id, ["Daylight", "Iris", "Sea glass", "Apricot", "Rose", "Ink"][index]) }
        store.toggleFavorite(store.library.history[0].id)
        store.defaultFormat = .oklch
        store.selected = colors[0]
        store.foreground = SampledColor(hex: "#9A8EB0")!
        store.background = SampledColor(hex: "#F4F1F8")!
        window = StudioWindow(store: store, shortcut: "Option + Shift")
        window.window.appearance = NSAppearance(named: .aqua)
        window.show()
        Task { @MainActor in
            for tab in StudioTab.allCases {
                store.tab = tab
                if tab == .palettes {
                    // Exercise the actual asynchronous extractor on the app's artwork.
                    store.extract(url: root.appendingPathComponent("Assets/PrismDrop.png"))
                    while store.isExtracting { try? await Task.sleep(for: .milliseconds(30)) }
                    store.saveExtracted(name: "PrismDrop glass")
                }
                try? await Task.sleep(for: .milliseconds(700))
                let view = window.window.contentView!
                view.layoutSubtreeIfNeeded(); view.displayIfNeeded()
                guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { fatalError("No bitmap") }
                view.cacheDisplay(in: view.bounds, to: bitmap)
                try! bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("\(tab.rawValue.lowercased()).png"))
            }
            store.flush()
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: temporary)
            print("Rendered all five production Studio tabs at \(output.path)")
            NSApp.terminate(nil)
        }
    }
}

@main
private enum RenderStudioMain {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let delegate = StudioRenderer(); app.delegate = delegate; app.run()
    }
}
