// Appended to PrismDrop.swift without its @main entry by scripts/test.sh.
// Exercise production input handling directly; never post synthetic system input.
extension AppController {
    @MainActor static func regressionChecks(store: StudioStore) async throws {
        let controller = AppController(studio: store)
        controller.pair = .optionShift
        controller.captureInFlight = true // Keep this deterministic, without screen permission.
        let flags: CGEventFlags = [.maskAlternate, .maskShift]
        for pair in ModifierPair.allCases { expect(pair.matches(pair.flags), "modifier pair recognized") }
        expect(!ModifierPair.optionShift.matches(.maskAlternate), "partial shortcut rejected")
        controller.updateHeldState(flags: flags)
        expect(controller.isHolding && controller.overlay.model.isPresented, "production hotkey reveals overlay")
        let red = SampledColor(red: 255, green: 0, blue: 0)
        controller.sessionColor = red; controller.lastColor = red
        controller.overlay.update(red, at: NSEvent.mouseLocation)
        expect(controller.overlay.model.color == red, "sample updates production readout")
        store.setEnabled(.history, true); store.defaultFormat = .rgba
        let event = CGEvent(keyboardEventSource: nil, virtualKey: 8, keyDown: true)!
        event.flags = flags
        controller.handleEvent(type: .keyDown, event: event)
        expect(NSPasteboard.general.string(forType: .string) == "rgba(255, 0, 0, 1)", "existing C shortcut uses selected format")
        expect(controller.overlay.model.copied, "existing copied feedback")
        let before = controller.generation
        controller.updateHeldState(flags: .maskShift)
        expect(!controller.isHolding && !controller.overlay.model.isPresented && controller.generation > before, "release hides and invalidates old captures")
        expect(store.library.history.first?.color == red, "release integrates history")
        controller.updateHeldState(flags: flags)
        let clipboardBefore = NSPasteboard.general.string(forType: .string)
        controller.handleEvent(type: .keyDown, event: event)
        expect(controller.sessionColor == nil && NSPasteboard.general.string(forType: .string) == clipboardBefore && !controller.overlay.model.copied, "new activation cannot copy stale previous sample")
        if let screen = NSScreen.main {
            controller.overlay.position(at: CGPoint(x: screen.frame.midX, y: screen.frame.minY + 1), snap: true)
            expect(controller.overlay.model.attachment == .above, "bottom edge flips bubble above")
            controller.overlay.position(at: CGPoint(x: screen.frame.midX, y: screen.frame.midY), snap: true)
            expect(controller.overlay.model.attachment == .below && near(Double(controller.overlay.model.pointerX), 93), "normal bubble stays centered below cursor")
        }
        controller.endSampling()
        store.setEnabled(.picker, false)
        controller.updateHeldState(flags: flags)
        expect(!controller.isHolding, "disabled eyedropper ignores activation")
        store.setEnabled(.picker, true)
        try await Task.sleep(for: .milliseconds(260))
    }
}
