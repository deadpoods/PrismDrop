import AppKit
import CoreGraphics
import Darwin
import ScreenCaptureKit
import SwiftUI

// PrismDrop is intentionally a local, menu-bar-only application. No networking
// framework, analytics, or persistence of captured images is used.

private enum ModifierPair: Int, CaseIterable {
    case optionShift = 0
    case controlShift = 1
    case controlOption = 2

    var title: String {
        switch self {
        case .optionShift: return "Option + Shift"
        case .controlShift: return "Control + Shift"
        case .controlOption: return "Control + Option"
        }
    }

    var shortTitle: String {
        switch self {
        case .optionShift: return "⌥ ⇧"
        case .controlShift: return "⌃ ⇧"
        case .controlOption: return "⌃ ⌥"
        }
    }

    var flags: CGEventFlags {
        switch self {
        case .optionShift: return [.maskAlternate, .maskShift]
        case .controlShift: return [.maskControl, .maskShift]
        case .controlOption: return [.maskControl, .maskAlternate]
        }
    }

    func matches(_ current: CGEventFlags) -> Bool {
        current.intersection(flags) == flags
    }
}

private struct SampledColor: Equatable {
    let red: UInt8
    let green: UInt8
    let blue: UInt8

    var hex: String { String(format: "#%02X%02X%02X", red, green, blue) }
    var nsColor: NSColor {
        NSColor(srgbRed: CGFloat(red) / 255,
                green: CGFloat(green) / 255,
                blue: CGFloat(blue) / 255,
                alpha: 1)
    }
}

@MainActor
private final class OverlayModel: ObservableObject {
    @Published var color: SampledColor?
    @Published var haloColor = Color(red: 0.37, green: 0.77, blue: 1)
    @Published var isPresented = false
    @Published var shortcut = "⌥ ⇧"
    @Published var copied = false
    @Published var message: String?
    @Published var attachment: OverlayAttachment = .below
    @Published var pointerX: CGFloat = 93
}

private struct DropperGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = min(rect.width, rect.height)
        let x = rect.midX
        let y = rect.midY
        // An original, compact dropper silhouette drawn as one connected body.
        path.move(to: CGPoint(x: x + 0.24 * s, y: y - 0.35 * s))
        path.addCurve(to: CGPoint(x: x + 0.37 * s, y: y - 0.22 * s),
                      control1: CGPoint(x: x + 0.32 * s, y: y - 0.43 * s),
                      control2: CGPoint(x: x + 0.44 * s, y: y - 0.30 * s))
        path.addLine(to: CGPoint(x: x + 0.22 * s, y: y - 0.07 * s))
        path.addLine(to: CGPoint(x: x + 0.29 * s, y: y + 0.01 * s))
        path.addLine(to: CGPoint(x: x + 0.15 * s, y: y + 0.15 * s))
        path.addLine(to: CGPoint(x: x + 0.06 * s, y: y + 0.08 * s))
        path.addLine(to: CGPoint(x: x - 0.25 * s, y: y + 0.38 * s))
        path.addLine(to: CGPoint(x: x - 0.39 * s, y: y + 0.40 * s))
        path.addLine(to: CGPoint(x: x - 0.37 * s, y: y + 0.26 * s))
        path.addLine(to: CGPoint(x: x - 0.07 * s, y: y - 0.06 * s))
        path.addLine(to: CGPoint(x: x - 0.14 * s, y: y - 0.15 * s))
        path.addLine(to: CGPoint(x: x + 0.01 * s, y: y - 0.29 * s))
        path.addLine(to: CGPoint(x: x + 0.09 * s, y: y - 0.22 * s))
        path.closeSubpath()
        return path
    }
}

private enum OverlayAttachment {
    case below, above

    var revealAnchor: UnitPoint {
        self == .below ? .top : .bottom
    }
}

private struct CursorBubble: Shape {
    let attachment: OverlayAttachment
    let pointerX: CGFloat

    func path(in rect: CGRect) -> Path {
        let inset: CGFloat = 3
        let radius: CGFloat = 14
        let left = inset
        let right = rect.width - inset
        let tip = min(right - radius - 9, max(left + radius + 9, pointerX))
        let top: CGFloat = attachment == .below ? 9 : 1
        let bottom: CGFloat = attachment == .below ? rect.height - 1 : rect.height - 9
        var path = Path()
        path.move(to: CGPoint(x: left + radius, y: top))
        if attachment == .below {
            path.addLine(to: CGPoint(x: tip - 8, y: top))
            path.addLine(to: CGPoint(x: tip, y: 1))
            path.addLine(to: CGPoint(x: tip + 8, y: top))
        }
        path.addLine(to: CGPoint(x: right - radius, y: top))
        path.addQuadCurve(to: CGPoint(x: right, y: top + radius),
                          control: CGPoint(x: right, y: top))
        path.addLine(to: CGPoint(x: right, y: bottom - radius))
        path.addQuadCurve(to: CGPoint(x: right - radius, y: bottom),
                          control: CGPoint(x: right, y: bottom))
        if attachment == .above {
            path.addLine(to: CGPoint(x: tip + 8, y: bottom))
            path.addLine(to: CGPoint(x: tip, y: rect.height - 1))
            path.addLine(to: CGPoint(x: tip - 8, y: bottom))
        }
        path.addLine(to: CGPoint(x: left + radius, y: bottom))
        path.addQuadCurve(to: CGPoint(x: left, y: bottom - radius),
                          control: CGPoint(x: left, y: bottom))
        path.addLine(to: CGPoint(x: left, y: top + radius))
        path.addQuadCurve(to: CGPoint(x: left + radius, y: top),
                          control: CGPoint(x: left, y: top))
        path.closeSubpath()
        return path
    }
}

private struct OverlayView: View {
    @ObservedObject var model: OverlayModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var swatch: Color {
        guard let color = model.color else { return Color(red: 0.37, green: 0.77, blue: 1) }
        return Color(nsColor: color.nsColor)
    }

    private var rgbLine: String {
        if let color = model.color {
            return "R \(color.red)   G \(color.green)   B \(color.blue)"
        }
        return model.message ?? "SAMPLING PIXEL"
    }

    private var bubble: CursorBubble {
        CursorBubble(attachment: model.attachment, pointerX: model.pointerX)
    }

    @ViewBuilder private var glassSurface: some View {
        if #available(macOS 26.0, *) {
            Color.clear
                .glassEffect(.regular.tint(.black.opacity(0.18)), in: bubble)
        } else {
            bubble.fill(.ultraThinMaterial)
        }
    }

    var body: some View {
        ZStack {
            glassSurface
            bubble.stroke(
                LinearGradient(colors: [.white.opacity(0.60),
                                        model.haloColor.opacity(0.32),
                                        .white.opacity(0.18)],
                               startPoint: .top, endPoint: .bottom),
                lineWidth: 0.8
            )

            HStack(spacing: 7) {
                ZStack {
                    Circle()
                        .strokeBorder(.white.opacity(0.36), lineWidth: 0.8)
                        .frame(width: 31, height: 31)
                    Circle()
                        .fill(swatch)
                        .frame(width: 27, height: 27)
                        .overlay(Circle().strokeBorder(.white.opacity(0.72), lineWidth: 0.8))
                    DropperGlyph()
                        .fill(.black.opacity(0.38))
                        .frame(width: 13, height: 13)
                        .offset(x: 0.5, y: 1)
                    DropperGlyph()
                        .fill(.white)
                        .frame(width: 13, height: 13)
                }
                .frame(width: 31, height: 33)

                VStack(alignment: .leading, spacing: 1) {
                    Text(model.color?.hex ?? "#------")
                        .font(.system(size: 16, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Text(rgbLine)
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.87))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Text(model.copied ? "COPIED" : "\(model.shortcut)  C TO COPY")
                        .font(.system(size: 7, weight: .semibold, design: .rounded))
                        .tracking(0.5)
                        .foregroundStyle(model.copied ? model.haloColor : .white.opacity(0.74))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .frame(width: 180, height: 52)
            .position(x: 93, y: model.attachment == .below ? 35 : 27)
        }
        .frame(width: 186, height: 62)
        .scaleEffect(model.isPresented ? 1 : (reduceMotion ? 1 : 0.93),
                     anchor: model.attachment.revealAnchor)
        .opacity(model.isPresented ? 1 : 0)
        .animation(reduceMotion ? .easeOut(duration: 0.10)
                    : .spring(response: 0.21, dampingFraction: 0.79),
                   value: model.isPresented)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: model.haloColor)
    }
}

@MainActor
private final class OverlayPanel {
    let model = OverlayModel()
    private let panel: NSPanel
    private var presentationID = 0

    init() {
        panel = NSPanel(contentRect: CGRect(x: 0, y: 0, width: 186, height: 62),
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        panel.contentView = NSHostingView(rootView: OverlayView(model: model))
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .none
        panel.orderOut(nil)
    }

    func show(at mouse: CGPoint, shortcut: String) {
        presentationID += 1
        model.shortcut = shortcut
        model.color = nil
        model.message = nil
        model.copied = false
        position(at: mouse, snap: true)
        panel.orderFrontRegardless()
        model.isPresented = true
    }

    func update(_ sample: SampledColor, at mouse: CGPoint) {
        model.color = sample
        model.message = nil
        model.haloColor = Color(nsColor: sample.nsColor)
        position(at: mouse, snap: false)
    }

    func position(at mouse: CGPoint, snap: Bool = false) {
        guard panel.isVisible || snap else { return }
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        let safe = screen?.frame.insetBy(dx: 2, dy: 2) ?? CGRect(x: mouse.x - 400, y: mouse.y - 300, width: 800, height: 600)
        let width: CGFloat = 186
        let height: CGFloat = 62
        let gap: CGFloat = 2
        let below = mouse.y - gap - height >= safe.minY
        let x = min(max(mouse.x - width / 2, safe.minX), safe.maxX - width)
        let y = below ? mouse.y - gap - height : mouse.y + gap
        let attachment: OverlayAttachment = below ? .below : .above
        if model.attachment != attachment { model.attachment = attachment }
        let pointerX = mouse.x - x
        if model.pointerX != pointerX { model.pointerX = pointerX }
        panel.setFrameOrigin(CGPoint(x: x, y: y))
    }

    func showError(_ message: String) {
        model.color = nil
        model.message = message
    }

    func markCopied() {
        model.copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
            self?.model.copied = false
        }
    }

    func hide() {
        presentationID += 1
        let id = presentationID
        model.isPresented = false
        DispatchQueue.main.asyncAfter(deadline: .now() + (NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0.10 : 0.22)) { [weak self] in
            guard let self, self.presentationID == id else { return }
            self.panel.orderOut(nil)
            self.model.color = nil
        }
    }
}

@MainActor
private final class PixelSampler {
    private var displays: [CGDirectDisplayID: SCDisplay] = [:]
    private var isRefreshing = false

    func refreshDisplays() async throws {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        displays = Dictionary(uniqueKeysWithValues: content.displays.map { ($0.displayID, $0) })
    }

    func sample(at point: CGPoint) async throws -> SampledColor {
        var displayID: CGDirectDisplayID = 0
        var count: UInt32 = 0
        let error = CGGetDisplaysWithPoint(point, 1, &displayID, &count)
        guard error == .success, count > 0 else { throw SamplingError.noDisplay }
        if displays[displayID] == nil { try await refreshDisplays() }
        guard let display = displays[displayID] else { throw SamplingError.noDisplay }

        let bounds = CGDisplayBounds(displayID)
        let localX = point.x - bounds.minX
        let localY = point.y - bounds.minY
        guard localX >= 0, localY >= 0, localX < bounds.width, localY < bounds.height else {
            throw SamplingError.noDisplay
        }

        let screen = NSScreen.screens.first {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == displayID
        }
        let scale = screen?.backingScaleFactor ?? 1
        let cellX = floor(localX)
        let cellY = floor(localY)
        let width = max(1, Int(ceil(scale)))
        let config = SCStreamConfiguration()
        config.sourceRect = CGRect(x: cellX, y: cellY, width: 1, height: 1)
        config.width = width
        config.height = width
        config.scalesToFit = false
        config.showsCursor = false
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.colorSpaceName = CGColorSpace.sRGB as CFString
        config.captureResolution = .best
        let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        guard image.width > 0, image.height > 0 else { throw SamplingError.emptyImage }
        let pixelX = min(image.width - 1, max(0, Int((localX - cellX) * CGFloat(image.width))))
        let pixelY = min(image.height - 1, max(0, Int((localY - cellY) * CGFloat(image.height))))
        guard let pixel = image.cropping(to: CGRect(x: pixelX, y: pixelY, width: 1, height: 1)) else {
            throw SamplingError.emptyImage
        }
        var bytes = [UInt8](repeating: 0, count: 4)
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        guard let context = CGContext(data: &bytes, width: 1, height: 1,
                                      bitsPerComponent: 8, bytesPerRow: 4,
                                      space: colorSpace, bitmapInfo: bitmapInfo) else {
            throw SamplingError.emptyImage
        }
        context.interpolationQuality = .none
        context.setBlendMode(.copy)
        context.draw(pixel, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return SampledColor(red: bytes[0], green: bytes[1], blue: bytes[2])
    }

    enum SamplingError: LocalizedError {
        case noDisplay, emptyImage
        var errorDescription: String? {
            switch self {
            case .noDisplay: return "No capture display contains the pointer."
            case .emptyImage: return "ScreenCaptureKit returned no pixel."
            }
        }
    }
}

@MainActor
private final class AppController: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let overlay = OverlayPanel()
    private let sampler = PixelSampler()
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private var timer: Timer?
    private var eventTap: CFMachPort?
    private var eventTapSource: CFRunLoopSource?
    private var isHolding = false
    private var captureInFlight = false
    private var generation = 0
    private var lastColor: SampledColor?
    private var lastCaptureError: String?
    private var lastFailureAt = Date.distantPast
    private var lastPermissionCheck = Date.distantPast
    private var inputAllowed = false
    private var screenAllowed = false
    private var pair = ModifierPair(rawValue: UserDefaults.standard.integer(forKey: "hotkeyPair")) ?? .optionShift

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let image = NSImage(systemSymbolName: "eyedropper", accessibilityDescription: "PrismDrop") {
            image.isTemplate = true
            statusItem.button?.image = image
        } else {
            statusItem.button?.title = "◉"
        }
        statusItem.button?.toolTip = "PrismDrop — hold \(pair.title)"
        menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        rebuildMenu()

        // A listen-only event tap sees modifier-only flagsChanged events systemwide.
        // Polling the current state provides a release fail-safe if the tap is disabled.
        inputAllowed = CGPreflightListenEventAccess()
        screenAllowed = CGPreflightScreenCaptureAccess()
        installEventTapIfAllowed()
        NSLog("PrismDrop startup: screen=%@ input=%@ tap=%@",
              screenAllowed ? "allowed" : "denied",
              inputAllowed ? "allowed" : "denied",
              eventTap == nil ? "unavailable" : "active")
        timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.tick() }
        }
        RunLoop.main.add(timer!, forMode: .common)

        if screenAllowed {
            Task { try? await sampler.refreshDisplays() }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
        if let source = eventTapSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if let tap = eventTap { CFMachPortInvalidate(tap) }
    }

    private func installEventTapIfAllowed() {
        guard inputAllowed, eventTap == nil else { return }
        let mask = (CGEventMask(1) << CGEventType.flagsChanged.rawValue) |
                   (CGEventMask(1) << CGEventType.keyDown.rawValue)
        let refcon = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        eventTap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                                     options: .listenOnly, eventsOfInterest: mask,
                                     callback: { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let controller = Unmanaged<AppController>.fromOpaque(refcon).takeUnretainedValue()
            DispatchQueue.main.async { controller.handleEvent(type: type, event: event) }
            return Unmanaged.passUnretained(event)
        }, userInfo: refcon)
        guard let tap = eventTap else {
            lastCaptureError = "Input Monitoring was allowed, but the event tap could not start. Relaunch PrismDrop."
            return
        }
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        eventTapSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func handleEvent(type: CGEventType, event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return
        }
        if type == .flagsChanged {
            updateHeldState(flags: event.flags)
        } else if type == .keyDown,
                  event.getIntegerValueField(.keyboardEventKeycode) == 8,
                  pair.matches(event.flags), isHolding {
            copyLastHex()
        }
    }

    private func tick() {
        if Date().timeIntervalSince(lastPermissionCheck) >= 1 {
            lastPermissionCheck = Date()
            let allowed = CGPreflightListenEventAccess()
            if allowed != inputAllowed {
                NSLog("PrismDrop Input Monitoring changed: %@", allowed ? "allowed" : "denied")
            }
            inputAllowed = allowed
            if inputAllowed { installEventTapIfAllowed() }
        }
        guard inputAllowed else {
            if isHolding { endSampling() }
            return
        }
        let flags = CGEventSource.flagsState(.combinedSessionState)
        updateHeldState(flags: flags)
        if isHolding {
            overlay.position(at: NSEvent.mouseLocation)
            requestSample()
        }
    }

    private func updateHeldState(flags: CGEventFlags) {
        let shouldHold = pair.matches(flags)
        guard shouldHold != isHolding else { return }
        if shouldHold { beginSampling() } else { endSampling() }
    }

    private func beginSampling() {
        isHolding = true
        generation += 1
        overlay.show(at: NSEvent.mouseLocation, shortcut: pair.shortTitle)
        screenAllowed = CGPreflightScreenCaptureAccess()
        if !screenAllowed {
            overlay.showError("SCREEN ACCESS NEEDED")
            return
        }
        requestSample() // Launch first capture before any reveal animation finishes.
    }

    private func endSampling() {
        isHolding = false
        generation += 1 // Invalidate any capture that finishes after key release.
        overlay.hide()
    }

    private func requestSample() {
        guard isHolding, !captureInFlight, screenAllowed else { return }
        guard let location = CGEvent(source: nil)?.location else { return }
        captureInFlight = true
        let requestGeneration = generation
        Task { @MainActor in
            defer { captureInFlight = false }
            do {
                let sample = try await sampler.sample(at: location)
                guard isHolding, generation == requestGeneration else { return }
                lastColor = sample
                lastCaptureError = nil
                overlay.update(sample, at: NSEvent.mouseLocation)
            } catch {
                guard isHolding, generation == requestGeneration else { return }
                if Date().timeIntervalSince(lastFailureAt) > 2 {
                    lastCaptureError = error.localizedDescription
                    lastFailureAt = Date()
                    overlay.showError("CAPTURE UNAVAILABLE")
                    Task { try? await sampler.refreshDisplays() }
                }
            }
        }
    }

    private func copyLastHex() {
        guard let lastColor else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lastColor.hex, forType: .string)
        overlay.markCopied()
    }

    func menuNeedsUpdate(_ menu: NSMenu) { rebuildMenu() }

    private func rebuildMenu() {
        menu.removeAllItems()
        let title = NSMenuItem(title: "PrismDrop", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        let instruction = NSMenuItem(title: "Hold \(pair.title) to sample", action: nil, keyEquivalent: "")
        instruction.isEnabled = false
        menu.addItem(instruction)
        menu.addItem(.separator())

        let screenGranted = CGPreflightScreenCaptureAccess()
        let inputGranted = CGPreflightListenEventAccess()
        menu.addItem(item("Screen Recording: \(screenGranted ? "Allowed" : "Needs permission")", #selector(requestScreenAccess)))
        menu.addItem(item("Input Monitoring: \(inputGranted ? "Allowed" : "Needs permission")", #selector(requestInputAccess)))
        if !inputGranted || !screenGranted {
            menu.addItem(item("Open Privacy Settings…", #selector(openPrivacySettings)))
        }
        if let error = lastCaptureError {
            let errorItem = NSMenuItem(title: "Issue: \(String(error.prefix(80)))", action: nil, keyEquivalent: "")
            errorItem.isEnabled = false
            menu.addItem(errorItem)
        }
        menu.addItem(.separator())

        let copy = item(lastColor.map { "Copy Last HEX  \($0.hex)" } ?? "Copy Last HEX (none yet)", #selector(copyMenuAction))
        copy.isEnabled = lastColor != nil
        menu.addItem(copy)
        let hotkey = NSMenuItem(title: "Activation hotkey", action: nil, keyEquivalent: "")
        let sub = NSMenu()
        for value in ModifierPair.allCases {
            let choice = item(value.title, #selector(selectHotkey(_:)))
            choice.tag = value.rawValue
            choice.state = value == pair ? .on : .off
            sub.addItem(choice)
        }
        hotkey.submenu = sub
        menu.addItem(hotkey)
        menu.addItem(.separator())
        menu.addItem(item("Quit PrismDrop", #selector(quit)))
    }

    private func item(_ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    @objc private func requestScreenAccess() {
        if !CGPreflightScreenCaptureAccess() { _ = CGRequestScreenCaptureAccess() }
        screenAllowed = CGPreflightScreenCaptureAccess()
        if screenAllowed {
            Task { try? await sampler.refreshDisplays() }
        } else {
            openPrivacySettings()
        }
    }

    @objc private func requestInputAccess() {
        if !CGPreflightListenEventAccess() { _ = CGRequestListenEventAccess() }
        inputAllowed = CGPreflightListenEventAccess()
        if inputAllowed { installEventTapIfAllowed() }
        else { openPrivacySettings() }
    }

    @objc private func openPrivacySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        NSWorkspace.shared.open(url)
    }

    @objc private func copyMenuAction() { copyLastHex() }

    @objc private func selectHotkey(_ sender: NSMenuItem) {
        guard let selection = ModifierPair(rawValue: sender.tag) else { return }
        if isHolding { endSampling() }
        pair = selection
        UserDefaults.standard.set(selection.rawValue, forKey: "hotkeyPair")
        statusItem.button?.toolTip = "PrismDrop — hold \(pair.title)"
    }

    @objc private func quit() { NSApplication.shared.terminate(nil) }
}

@main
private enum PrismDropMain {
    static func main() {
        if CommandLine.arguments.contains("--diagnose") {
            let application = NSApplication.shared
            application.setActivationPolicy(.prohibited)
            print("Screen Recording: \(CGPreflightScreenCaptureAccess() ? "allowed" : "not allowed")")
            print("Input Monitoring: \(CGPreflightListenEventAccess() ? "allowed" : "not allowed")")
            print("AppKit displays: \(NSScreen.screens.count)")
            guard CGPreflightScreenCaptureAccess(), let point = CGEvent(source: nil)?.location else {
                return
            }
            Task { @MainActor in
                do {
                    let color = try await PixelSampler().sample(at: point)
                    print("Current pointer pixel: \(color.hex) / R \(color.red) G \(color.green) B \(color.blue)")
                    exit(0)
                } catch {
                    fputs("Capture failed: \(error.localizedDescription)\n", stderr)
                    exit(1)
                }
            }
            application.run()
            return
        }
        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)
        let delegate = AppController()
        application.delegate = delegate
        application.run()
    }
}
