// Appended to the production source by scripts/render-docs.sh.
// This renders the real overlay with scripted values, not a sampling benchmark.
import ImageIO
import UniformTypeIdentifiers

private func docColor(_ value: UInt32) -> Color {
    Color(red: Double((value >> 16) & 255) / 255,
          green: Double((value >> 8) & 255) / 255,
          blue: Double(value & 255) / 255)
}

private struct PresentationCursor: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 1, y: 1))
        p.addLine(to: CGPoint(x: 1, y: 25))
        p.addLine(to: CGPoint(x: 7, y: 19))
        p.addLine(to: CGPoint(x: 12, y: 30))
        p.addLine(to: CGPoint(x: 17, y: 28))
        p.addLine(to: CGPoint(x: 12, y: 18))
        p.addLine(to: CGPoint(x: 23, y: 18))
        p.closeSubpath()
        return p
    }
}

private struct CursorPreview: View {
    let point: CGPoint
    var body: some View {
        PresentationCursor()
            .fill(.black)
            .overlay(PresentationCursor().stroke(.white, lineWidth: 1.3))
            .frame(width: 25, height: 32)
            .position(x: point.x + 11.5, y: point.y + 15)
    }
}

private struct HeroPresentation: View {
    let icon: NSImage
    @ObservedObject var overlay: OverlayModel

    var body: some View {
        ZStack(alignment: .topLeading) {
            docColor(0xF4F6F9)
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    Image(nsImage: icon).resizable().frame(width: 58, height: 58)
                    Text("PrismDrop").font(.system(size: 23, weight: .semibold))
                }
                Spacer().frame(height: 50)
                Text("Color, at the\ntip of your cursor.")
                    .font(.system(size: 43, weight: .semibold))
                    .tracking(-1.4).lineSpacing(-2)
                Text("Hold a shortcut. Pick a pixel.\nKeep your flow.")
                    .font(.system(size: 18)).lineSpacing(5)
                    .foregroundStyle(docColor(0x596375))
                    .padding(.top, 22)
                HStack(spacing: 8) {
                    Text("⌥  ⇧").font(.system(size: 16, weight: .medium))
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(.white, in: RoundedRectangle(cornerRadius: 8))
                    Text("HOLD TO REVEAL").font(.system(size: 10, weight: .semibold)).tracking(1.5)
                }.padding(.top, 31)
            }
            .foregroundStyle(docColor(0x1E293B))
            .position(x: 260, y: 253)
            .frame(width: 490, height: 480)

            ZStack(alignment: .topLeading) {
                HStack(spacing: 0) {
                    docColor(0x4F8BFF).frame(width: 256)
                    VStack(spacing: 0) {
                        docColor(0xB9A3EA)
                        docColor(0x60CEB0)
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("THE COLOR BENEATH YOUR POINTER")
                        .font(.system(size: 9, weight: .semibold)).tracking(1.8)
                        .foregroundStyle(.white.opacity(0.85))
                    Text("#4F8BFF").font(.system(size: 32, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.96))
                }.padding(27)
                OverlayView(model: overlay)
                    .environment(\.colorScheme, .dark)
                    .scaleEffect(1.5)
                    .position(x: 217, y: 221)
                CursorPreview(point: CGPoint(x: 217, y: 170))
                HStack(spacing: 7) {
                    Text("sRGB").fontWeight(.semibold)
                    Text("HEX + RGB").foregroundStyle(.white.opacity(0.72))
                }
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.white)
                .position(x: 100, y: 339)
            }
            .frame(width: 460, height: 378)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.55), lineWidth: 1))
            .position(x: 820, y: 270)

            HStack {
                Text("NATIVE macOS EYEDROPPER")
                Spacer()
                Text("LOCAL BY DESIGN  ·  SWIFTUI + APPKIT")
            }
            .font(.system(size: 9, weight: .semibold)).tracking(1.4)
            .foregroundStyle(docColor(0x768194))
            .frame(width: 1000)
            .position(x: 560, y: 518)
        }.frame(width: 1120, height: 560)
    }
}

@MainActor
private final class DemoState: ObservableObject {
    let overlay = OverlayModel()
    @Published var point = CGPoint(x: 190, y: 153)
    @Published var caption = "Hold ⌥ + ⇧"
}

private struct DemoPresentation: View {
    @ObservedObject var state: DemoState
    var body: some View {
        ZStack(alignment: .topLeading) {
            docColor(0xF4F6F9)
            HStack {
                Text("Hold. Move. Copy.").font(.system(size: 22, weight: .semibold))
                Spacer()
                Text(state.caption).font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(docColor(0x596375))
            }.frame(width: 880).position(x: 480, y: 48)
            HStack(spacing: 0) {
                swatch("BLUE", "#4F8BFF", 0x4F8BFF)
                swatch("LILAC", "#B9A3EA", 0xB9A3EA)
                swatch("MINT", "#60CEB0", 0x60CEB0)
            }
            .frame(width: 880, height: 224)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .position(x: 480, y: 214)
            OverlayView(model: state.overlay)
                .environment(\.colorScheme, .dark)
                .scaleEffect(1.2)
                .position(x: state.point.x, y: state.point.y + 3 + 31 * 1.2)
            CursorPreview(point: state.point)
        }
        .foregroundStyle(docColor(0x1E293B))
        .frame(width: 960, height: 360)
    }

    private func swatch(_ name: String, _ hex: String, _ color: UInt32) -> some View {
        ZStack(alignment: .bottomLeading) {
            docColor(color)
            VStack(alignment: .leading, spacing: 4) {
                Text(name).font(.system(size: 9, weight: .semibold)).tracking(1.5)
                Text(hex).font(.system(size: 14, weight: .medium, design: .monospaced))
            }.foregroundStyle(.white).padding(20)
        }
    }
}

@main
private enum DocumentationMain {
    @MainActor static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        guard CommandLine.arguments.count == 2 else { exit(2) }
        let root = URL(fileURLWithPath: CommandLine.arguments[1])
        guard let icon = NSImage(contentsOf: root.appendingPathComponent("Assets/PrismDrop.png")) else { exit(3) }
        let model = OverlayModel()
        setSample(model, 0x4F8BFF)
        model.isPresented = true
        let window = NSWindow(contentRect: CGRect(x: 160, y: 190, width: 1120, height: 560),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.backgroundColor = .white
        window.isOpaque = true
        window.hasShadow = false
        window.level = .floating
        window.title = "PrismDrop documentation renderer"
        window.contentView = NSHostingView(rootView: HeroPresentation(icon: icon, overlay: model))
        window.orderFrontRegardless()

        Task { @MainActor in
            do {
                try await Task.sleep(for: .milliseconds(700))
                let hero = try await capture(window, width: 2240, height: 1120)
                try writePNG(hero, to: root.appendingPathComponent("docs/assets/hero.png"))

                let demo = DemoState()
                window.setContentSize(NSSize(width: 960, height: 360))
                window.contentView = NSHostingView(rootView: DemoPresentation(state: demo))
                try await Task.sleep(for: .milliseconds(400))
                let url = root.appendingPathComponent("docs/assets/demo.gif")
                guard let output = CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, 36, nil) else { exit(4) }
                CGImageDestinationSetProperties(output, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
                for frame in 0..<36 {
                    let t = Double(frame)
                    demo.point.x = t < 6 ? 190 : t < 24 ? 190 + (t - 6) / 17 * 560 : 750
                    demo.overlay.isPresented = frame >= 4 && frame < 32
                    demo.overlay.copied = frame >= 26 && frame < 32
                    let value: UInt32 = demo.point.x < 333 ? 0x4F8BFF : demo.point.x < 626 ? 0xB9A3EA : 0x60CEB0
                    setSample(demo.overlay, value)
                    demo.caption = frame < 4 ? "Hold ⌥ + ⇧" : frame < 26 ? "Move across a color" : frame < 32 ? "C → HEX copied" : "Release → gone"
                    try await Task.sleep(for: .milliseconds(130))
                    let image = try await capture(window, width: 1440, height: 540)
                    CGImageDestinationAddImage(output, image, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 0.14]] as CFDictionary)
                }
                guard CGImageDestinationFinalize(output) else { exit(5) }
                print("Rendered docs/assets/hero.png and docs/assets/demo.gif")
                window.orderOut(nil)
                app.terminate(nil)
            } catch {
                fputs("Documentation render failed: \(error)\n", stderr)
                exit(1)
            }
        }
        app.run()
    }

    @MainActor private static func setSample(_ model: OverlayModel, _ value: UInt32) {
        let sample = SampledColor(red: UInt8((value >> 16) & 255), green: UInt8((value >> 8) & 255), blue: UInt8(value & 255))
        model.color = sample
        model.haloColor = Color(nsColor: sample.nsColor)
    }

    @MainActor private static func capture(_ window: NSWindow, width: Int, height: Int) async throws -> CGImage {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let ownWindow = content.windows.first(where: { $0.windowID == CGWindowID(window.windowNumber) }) else {
            throw NSError(domain: "PrismDropDocs", code: 1, userInfo: [NSLocalizedDescriptionKey: "Presentation window not found"])
        }
        let configuration = SCStreamConfiguration()
        configuration.width = width
        configuration.height = height
        configuration.showsCursor = false
        configuration.ignoreShadowsSingleWindow = true
        configuration.colorSpaceName = CGColorSpace.sRGB as CFString
        let filter = SCContentFilter(desktopIndependentWindow: ownWindow)
        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
    }

    private static func writePNG(_ image: CGImage, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw NSError(domain: "PrismDropDocs", code: 2)
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw NSError(domain: "PrismDropDocs", code: 3) }
    }
}
