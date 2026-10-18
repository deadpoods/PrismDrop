import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

private var checks = 0
private func expect(_ condition: @autoclosure () throws -> Bool, _ message: String, file: StaticString = #filePath, line: UInt = #line) {
    checks += 1
    let passed: Bool
    do { passed = try condition() } catch { fputs("Unexpected error: \(error)\n", stderr); exit(1) }
    if !passed { fputs("FAIL \(file):\(line): \(message)\n", stderr); exit(1) }
}
private func near(_ a: Double, _ b: Double, _ tolerance: Double = 0.0001) -> Bool { abs(a - b) < tolerance }
private func image(_ colors: [SampledColor], stripe: Int = 20) -> CGImage {
    let width = colors.count * stripe, height = 32
    var bytes = [UInt8]()
    for _ in 0..<height { for x in 0..<width {
        let c = colors[x / stripe]
        bytes += [UInt8((Double(c.red) * c.alpha).rounded()), UInt8((Double(c.green) * c.alpha).rounded()), UInt8((Double(c.blue) * c.alpha).rounded()), UInt8((255 * c.alpha).rounded())]
    } }
    return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                   space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                   provider: CGDataProvider(data: Data(bytes) as CFData)!, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
}
private func encoded(_ image: CGImage, type: UTType) -> Data? {
    let data = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(data, type.identifier as CFString, 1, nil) else { return nil }
    CGImageDestinationAddImage(destination, image, nil)
    return CGImageDestinationFinalize(destination) ? data as Data : nil
}

@main
private enum FeatureTests {
    @MainActor static func main() async throws {
        let app = NSApplication.shared; app.setActivationPolicy(.accessory)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PrismDropTests-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let black = SampledColor.black, white = SampledColor.white, red = SampledColor(hex: "#FF0000")!

        // Independent published/reference values, including alpha and achromatic hues.
        expect(SampledColor(hex: "#abc")?.hex == "#AABBCC", "short HEX")
        expect(SampledColor(hex: "abcd")?.hexAlpha == "#AABBCCDD", "short alpha HEX")
        expect(SampledColor(hex: "#01020380")?.hexAlpha == "#01020380", "8-bit alpha roundtrip")
        for invalid in ["", "#12", "#gg0000", "#1234567", "#１２３", "red", "0xFF0000"] { expect(SampledColor(hex: invalid) == nil, "reject invalid HEX \(invalid)") }
        expect(near(red.hslHSV.h, 0) && near(red.hslHSV.s, 1) && near(red.hslHSV.l, 0.5), "red HSL")
        expect(near(SampledColor(hex: "00FF00")!.hslHSV.h, 120), "green hue")
        expect(near(SampledColor(hex: "0000FF")!.hslHSV.h, 240), "blue hue")
        expect(near(black.hslHSV.s, 0) && near(white.hslHSV.sv, 0), "achromatic saturation")
        expect(near(red.lab[0], 0.62795536) && near(red.lab[1], 0.22486306) && near(red.lab[2], 0.1258463), "OKLab red reference")
        for c in [black, white, red, SampledColor(hex: "#17A29C")!] {
            let back = SampledColor.fromLab(c.lab)
            expect(abs(Int(c.red) - Int(back.red)) <= 1 && abs(Int(c.green) - Int(back.green)) <= 1 && abs(Int(c.blue) - Int(back.blue)) <= 1, "OKLab inverse roundtrip")
        }
        expect(CopyFormat.hsl.string(for: red) == "hsl(0 100% 50%)", "CSS HSL syntax")
        expect(CopyFormat.rgb.string(for: red) == "rgb(255 0 0)", "CSS RGB syntax")
        let translucent = SampledColor(red: 12, green: 34, blue: 56, alpha: 0.5)
        expect(CopyFormat.hexAlpha.string(for: translucent) == "#0C223880", "alpha HEX rounding")
        for f in [CopyFormat.rgb, .rgba, .hsl, .hsla, .hsv, .hsb, .oklch, .displayP3, .swiftUI, .appKit, .tailwind] {
            expect(f.string(for: translucent).contains("0.5"), "alpha preserved in \(f.title)")
        }
        expect(CopyFormat.cssVariable.string(for: translucent, name: "Brand Blue") == "--color-brand-blue: #0C223880;", "valid named CSS token")
        let p3 = red.nsColor.usingColorSpace(.displayP3)!
        expect(near(p3.redComponent, 0.91749, 0.002) && near(p3.greenComponent, 0.20029, 0.002) && near(p3.blueComponent, 0.13856, 0.002), "ColorSync sRGB red to Display P3 reference")
        expect(CopyFormat.allCases.allSatisfy { !$0.string(for: red).isEmpty }, "all formats export")

        // WCAG reference ratios, encoded source-over, and strict pass boundaries.
        expect(near(ContrastResult(foreground: black, background: white).ratio, 21), "black/white 21:1")
        expect(near(ContrastResult(foreground: red, background: white).ratio, 3.99847677), "red/white reference")
        let gray = SampledColor(hex: "#777777")!
        expect(!ContrastResult(foreground: gray, background: white).normalAA, "4.478:1 fails 4.5, no rounded pass")
        expect(ContrastResult(foreground: gray, background: white).largeAA, "same color passes large AA")
        let halfBlack = SampledColor(red: 0, green: 0, blue: 0, alpha: 0.5)
        expect(near(ContrastResult(foreground: halfBlack, background: white).ratio, 3.976653), "alpha foreground not quantized")
        expect(near(ContrastResult(foreground: black, background: halfBlack).ratio, 5.280823), "alpha background composited over white")
        expect(near(ContrastResult(foreground: black, background: halfBlack, canvas: black).ratio, 1), "explicit black canvas")
        expect(ContrastResult(foreground: black, background: white).normalAAA, "AAA normal")
        expect(ContrastResult(foreground: white, background: white).suggestion() != nil, "suggestion exists")
        for c in [white, gray, SampledColor(red: 0, green: 0, blue: 0, alpha: 0)] {
            let suggestion = ContrastResult(foreground: c, background: white).suggestion()!
            expect(ContrastResult(foreground: suggestion, background: white).ratio >= 4.5, "suggestions actually pass")
        }
        let closest = ContrastResult(foreground: gray, background: white).suggestion()!
        let squaredDistance = pow(Double(closest.red) - 119, 2) + pow(Double(closest.green) - 119, 2) + pow(Double(closest.blue) - 119, 2)
        expect(near(squaredDistance, 1), "closest RGB suggestion changes only one channel by one step at boundary")
        expect(ContrastResult(foreground: black, background: white).suggestion() == nil, "no unnecessary suggestion")
        expect(ContrastResult(foreground: gray, background: gray).suggestion(target: 7) == nil, "impossible AAA on mid gray")

        // Persistence survives reload and protects favorites from recency pruning.
        let url = root.appendingPathComponent("library.json")
        var library = ColorLibrary()
        library.record(red)
        let originalID = library.history[0].id
        library.history[0].favorite = true; library.history[0].name = "Brand red"
        for n in 0..<125 { library.record(SampledColor(red: 0, green: UInt8(n), blue: 42)) }
        expect(library.history.count == 101 && library.history.contains { $0.id == originalID }, "100 recents plus favorite")
        library.record(red)
        expect(library.history.first?.id == originalID && library.history.first?.name == "Brand red", "duplicate moves to top preserving metadata")
        expect(library.history.filter { $0.color == red }.count == 1, "duplicate not inserted")
        library.palettes = [SavedPalette(name: "Brand", colors: [red, translucent])]
        try ColorLibrary.write(library.encoded(), to: url)
        expect(try ColorLibrary.load(from: url) == library, "complete JSON roundtrip")
        library.clearHistory(); expect(library.history.count == 1 && library.history[0].favorite, "clear keeps favorites")
        library.history[0].favorite = false; library.trim(); expect(library.history.count == 1, "unfavorite remains recent")
        let corrupt = root.appendingPathComponent("corrupt.json"); try Data("broken".utf8).write(to: corrupt)
        do { _ = try ColorLibrary.load(from: corrupt); expect(false, "corrupt library rejected") } catch { expect(true, "corruption error") }
        expect(try Data(contentsOf: corrupt) == Data("broken".utf8), "corrupt file untouched")
        expect(try ColorLibrary.load(from: root.appendingPathComponent("missing.json")).history.isEmpty, "first launch empty")

        // Balanced synthetic bands have known dominant colors; no random seeds.
        let fixtureColors = ["FF0000", "00FF00", "0000FF", "FFFF00", "00FFFF", "FF00FF", "000000", "FFFFFF"].map { SampledColor(hex: $0)! }
        let fixture = image(fixtureColors)
        let extracted = try PaletteExtractor.quantize(fixture)
        expect(extracted.count == 8, "eight separated dominant colors")
        expect(try PaletteExtractor.quantize(fixture) == extracted, "deterministic extraction")
        for c in fixtureColors {
            expect(extracted.contains { zip($0.lab, c.lab).reduce(0) { $0 + pow($1.0 - $1.1, 2) } < 0.0001 }, "expected dominant \(c.hex)")
        }
        expect(try PaletteExtractor.quantize(image([red, SampledColor(hex: "#FE0101")!])).count == 1, "near identical merged")
        expect(try PaletteExtractor.quantize(image([red])).count == 1, "flat image returns one color")
        let alphaPalette = try PaletteExtractor.quantize(image([SampledColor(red: 255, green: 0, blue: 0, alpha: 0.5)]))
        expect(near(alphaPalette[0].alpha, 128 / 255.0, 0.005), "image alpha retained/unpremultiplied")
        do { _ = try PaletteExtractor.quantize(image([SampledColor(red: 0, green: 0, blue: 0, alpha: 0)])); expect(false, "invisible image must fail") } catch { expect(true, "transparent image error") }
        do { _ = try PaletteExtractor.extract(data: Data("invalid".utf8)); expect(false, "invalid image must fail") } catch { expect(true, "invalid image error") }
        let png = encoded(fixture, type: .png)!
        let pngURL = root.appendingPathComponent("fixture.png"); try png.write(to: pngURL)
        expect(try PaletteExtractor.extract(url: pngURL).count == 8, "PNG file pipeline")
        for type in [UTType.jpeg, UTType.heic] {
            guard let data = encoded(fixture, type: type) else { throw NSError(domain: "Image fixture encoder unavailable: \(type)", code: 1) }
            expect((5...8).contains(try PaletteExtractor.extract(data: data).count), "\(type) decode and extraction")
        }

        // Real store integration: settings, clipboard, library/palettes and async flows.
        let suite = "PrismDrop.Tests.\(UUID())", defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let storeURL = root.appendingPathComponent("store/library.json")
        let store = StudioStore(defaults: defaults, libraryURL: storeURL)
        let clipboard = NSPasteboard.general
        let oldItems = (clipboard.pasteboardItems ?? []).map { item -> NSPasteboardItem in
            let copy = NSPasteboardItem(); for type in item.types { if let data = item.data(forType: type) { copy.setData(data, forType: type) } }; return copy
        }
        defer { clipboard.clearContents(); clipboard.writeObjects(oldItems) }
        store.defaultFormat = .rgba
        store.acceptPicked(translucent, finished: true)
        expect(store.library.history.count == 1, "picker commits history")
        expect(store.copy(translucent) && clipboard.string(forType: .string) == "rgba(12, 34, 56, 0.5)", "default clipboard integration")
        store.copy(translucent, format: .hex)
        expect(clipboard.string(forType: .string) == "#0C2238", "history explicit HEX regardless of default")
        store.renameColor(store.library.history[0].id, "Glass"); store.toggleFavorite(store.library.history[0].id)
        store.setEnabled(.history, false); store.acceptPicked(red, finished: true)
        expect(store.library.history.count == 1, "disabled history records nothing")
        store.setEnabled(.formats, false)
        expect(store.activeFormat == .hex, "formats off falls back to HEX")
        store.setEnabled(.formats, true); expect(store.activeFormat == .rgba, "format preference retained")
        store.requestPick(.foreground); store.acceptPicked(red, finished: true)
        expect(store.foreground == red && store.pendingPick == nil, "screen color to contrast")
        store.useForContrast(white, role: .background); store.swapContrast()
        expect(store.foreground == white && store.background == red, "swap contrast")
        store.extract(data: png, name: "Bands")
        for _ in 0..<500 where store.isExtracting { try await Task.sleep(for: .milliseconds(10)) }
        expect(!store.isExtracting && store.extracted.count == 8, "async extraction completes")
        store.saveExtracted(name: "Rainbow")
        expect(store.library.palettes.first?.colors.count == 8, "save extracted palette")
        let paletteID = store.library.palettes[0].id
        store.renamePalette(paletteID, "Spectrum"); store.removePaletteColor(paletteID, at: 0)
        expect(store.library.palettes[0].name == "Spectrum" && store.library.palettes[0].colors.count == 7, "rename palette/remove color")
        clipboard.clearContents(); clipboard.setData(png, forType: .png); store.pasteImage()
        for _ in 0..<500 where store.isExtracting { try await Task.sleep(for: .milliseconds(10)) }
        expect(store.extracted.count == 8, "paste image integration")
        let provider = NSItemProvider(item: png as NSData, typeIdentifier: UTType.png.identifier)
        expect(store.handleDrop([provider]), "image drop accepted")
        for _ in 0..<500 {
            try await Task.sleep(for: .milliseconds(10))
            if store.extractionName == "Dropped image" && !store.isExtracting { break }
        }
        expect(store.extractionName == "Dropped image" && store.extracted.count == 8, "drop representation completes")
        let fileProvider = NSItemProvider(item: pngURL as NSURL, typeIdentifier: UTType.fileURL.identifier)
        expect(store.handleDrop([fileProvider]), "file URL drop accepted")
        for _ in 0..<500 {
            try await Task.sleep(for: .milliseconds(10))
            if store.extractionName == "fixture" && !store.isExtracting { break }
        }
        expect(store.extractionName == "fixture" && store.extracted.count == 8, "Finder-style file drop completes")
        store.extract(data: png); store.setEnabled(.palettes, false)
        try await Task.sleep(for: .milliseconds(100))
        expect(!store.isExtracting, "feature off cancels extraction")
        store.flush()
        let reopened = StudioStore(defaults: defaults, libraryURL: storeURL)
        expect(reopened.library == store.library, "app relaunch restores history names favorites palettes")
        expect(!reopened.isEnabled(.history) && !reopened.isEnabled(.palettes) && reopened.defaultFormat == .rgba, "feature and format prefs survive relaunch")
        let brokenStore = StudioStore(defaults: defaults, libraryURL: corrupt)
        brokenStore.setEnabled(.history, true)
        brokenStore.favoriteSelected(); brokenStore.flush()
        expect(try brokenStore.persistenceError != nil && Data(contentsOf: corrupt) == Data("broken".utf8), "failed load cannot overwrite original")
        let blockedParent = root.appendingPathComponent("blocked")
        try Data("file".utf8).write(to: blockedParent)
        let failedStore = StudioStore(defaults: defaults, libraryURL: blockedParent.appendingPathComponent("library.json"))
        // The missing child is initially empty; its parent cannot accept a directory.
        failedStore.favoriteSelected(); failedStore.flush()
        try await Task.sleep(for: .milliseconds(30))
        expect(failedStore.persistenceError != nil, "write failure shown to user")
        try FileManager.default.removeItem(at: blockedParent)
        failedStore.retryPersistence(); failedStore.flush()
        try await Task.sleep(for: .milliseconds(30))
        expect(try failedStore.persistenceError == nil && ColorLibrary.load(from: failedStore.libraryURL).history.count == 1, "write failure recoverable by retry")
        try ColorLibrary.write(ColorLibrary().encoded(), to: corrupt)
        brokenStore.retryPersistence()
        expect(brokenStore.persistenceError == nil && brokenStore.library.history.isEmpty, "load recovery retries original file")
        store.deletePalette(paletteID); store.clearHistory(); store.deleteColor(store.library.history[0].id)
        expect(store.library.history.isEmpty && store.library.palettes.isEmpty, "explicit deletes work")
        store.flush()
        try await AppController.regressionChecks(store: store)
        store.flush()
        print("PASS: \(checks) color, persistence, extraction, contrast, clipboard, and store checks")
    }
}
