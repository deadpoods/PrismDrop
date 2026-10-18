import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ColorSwatch: View {
    let color: SampledColor
    var size: CGFloat = 36
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9).fill(.white)
            Path { p in
                let cell = size / 4
                for y in 0..<4 { for x in 0..<4 where (x + y).isMultiple(of: 2) {
                    p.addRect(CGRect(x: CGFloat(x) * cell, y: CGFloat(y) * cell, width: cell, height: cell))
                } }
            }.fill(.gray.opacity(0.3))
            Color(nsColor: color.nsColor)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(.primary.opacity(0.12), lineWidth: 0.7))
        .accessibilityLabel(color.alpha < 1 ? color.hexAlpha : color.hex)
    }
}

struct StudioView: View {
    @ObservedObject var store: StudioStore
    var shortcut: String = "Option + Shift"

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 34, height: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text("PrismDrop").font(.system(size: 17, weight: .semibold))
                    Text("Color, at the tip of your cursor.").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text("Hold \(shortcut)").font(.caption).foregroundStyle(.secondary)
            }.padding(.horizontal, 22).padding(.top, 17).padding(.bottom, 16)
            HStack(spacing: 12) {
                ColorSwatch(color: store.selected, size: 40)
                VStack(alignment: .leading, spacing: 3) {
                    Text(store.selected.alpha < 1 ? store.selected.hexAlpha : store.selected.hex)
                        .font(.system(.title3, design: .monospaced).weight(.semibold)).textSelection(.enabled)
                    Text(store.copiedText == nil ? "Selected color · sRGB" : "Copied to clipboard")
                        .font(.caption).foregroundStyle(store.copiedText == nil ? Color.secondary : Color.accentColor)
                }
                Spacer(minLength: 4)
                if store.isEnabled(.formats) {
                    Picker("Copy format", selection: $store.defaultFormat) {
                        ForEach(CopyFormat.allCases) { Text($0.title).tag($0) }
                    }.labelsHidden().frame(width: 137).help("Default format for the picker and palette swatches")
                }
                Button("Copy") { store.copy(store.selected) }.keyboardShortcut("c", modifiers: [.command, .shift])
                if store.isEnabled(.history) {
                    Button { store.favoriteSelected() } label: { Image(systemName: "star") }
                        .help("Save selected color as a favorite").accessibilityLabel("Favorite selected color")
                }
            }
            .padding(14).background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 20)

            Picker("Tool", selection: $store.tab) {
                ForEach(StudioTab.allCases) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented).labelsHidden().padding(.horizontal, 20).padding(.vertical, 16)

            if let message = store.persistenceError {
                HStack(alignment: .top) {
                    Image(systemName: "externaldrive.badge.exclamationmark")
                    Text(message).font(.caption).textSelection(.enabled)
                    Spacer(minLength: 4)
                    Button("Retry") { store.retryPersistence() }
                    Button("Reveal") { NSWorkspace.shared.selectFile(store.libraryURL.path, inFileViewerRootedAtPath: store.libraryURL.deletingLastPathComponent().path) }
                }.padding(12).background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10)).padding(.horizontal, 20).padding(.bottom, 10)
            }
            if let message = store.errorMessage {
                HStack(alignment: .top) {
                    Image(systemName: "exclamationmark.triangle")
                    Text(message).font(.caption)
                    Spacer()
                    Button { store.errorMessage = nil } label: { Image(systemName: "xmark") }.buttonStyle(.plain).accessibilityLabel("Dismiss error")
                }.padding(12).background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10)).padding(.horizontal, 20).padding(.bottom, 10)
            }
            if let feature = store.tab.feature, !store.isEnabled(feature) {
                VStack(spacing: 12) {
                    Image(systemName: "pause.circle").font(.system(size: 32)).foregroundStyle(.secondary)
                    Text("\(feature.title) is off").font(.headline)
                    Text("Your saved colors and palettes stay on this Mac.").font(.callout).foregroundStyle(.secondary)
                    Button("Turn on \(feature.title)") { store.setEnabled(feature, true) }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Group {
                    switch store.tab {
                    case .history: HistoryView(store: store)
                    case .formats: FormatListView(store: store)
                    case .palettes: PalettesView(store: store)
                    case .contrast: ContrastView(store: store)
                    case .settings: FeatureSettingsView(store: store)
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Divider().padding(.top, 10)
            HStack {
                Image(systemName: "lock.shield").font(.caption)
                Text("On your Mac. No accounts, uploads, or tracking.").font(.caption2)
                Spacer()
                if let role = store.pendingPick {
                    Text("Hold \(shortcut), then release to set \(role.rawValue.lowercased()).").font(.caption2)
                    Button("Cancel") { store.pendingPick = nil }.controlSize(.small)
                }
            }.foregroundStyle(.secondary).padding(.horizontal, 20).padding(.vertical, 11)
        }
        .frame(minWidth: 600, minHeight: 610)
        .background(.ultraThinMaterial)
    }
}

private struct HistoryView: View {
    @ObservedObject var store: StudioStore
    @State private var favoritesOnly = false
    @State private var confirmingClear = false
    private var entries: [SavedColor] { store.library.history.filter { !favoritesOnly || $0.favorite } }
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("\(store.library.history.filter { !$0.favorite }.count) recents · \(store.library.history.filter(\.favorite).count) favorites").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Toggle("Favorites", isOn: $favoritesOnly).toggleStyle(.checkbox).font(.caption)
                Button("Clear History…") { confirmingClear = true }.controlSize(.small)
                    .disabled(!store.library.history.contains { !$0.favorite })
            }.padding(.horizontal, 22)
            if entries.isEmpty {
                emptyState("No colors yet", symbol: "clock", detail: "Pick a screen color and release the shortcut to save it here. Click a saved swatch to copy HEX.")
            } else {
                ScrollView {
                    LazyVStack(spacing: 7) {
                        ForEach(entries) { entry in
                            HStack(spacing: 10) {
                                Button { store.copy(entry.color, format: .hex) } label: {
                                    HStack(spacing: 10) {
                                        ColorSwatch(color: entry.color, size: 32)
                                        Text(entry.color.alpha < 1 ? entry.color.hexAlpha : entry.color.hex)
                                            .font(.system(.callout, design: .monospaced)).frame(width: 90, alignment: .leading)
                                    }
                                }.buttonStyle(.plain).help("Copy \(entry.color.hex)")
                                TextField("Name this color", text: Binding(get: { store.library.history.first { $0.id == entry.id }?.name ?? "" }, set: { store.renameColor(entry.id, $0) }))
                                    .textFieldStyle(.plain).font(.callout).accessibilityLabel("Color name for \(entry.color.hex)")
                                Spacer(minLength: 0)
                                Button { store.toggleFavorite(entry.id) } label: { Image(systemName: entry.favorite ? "star.fill" : "star").foregroundStyle(entry.favorite ? Color.orange : Color.secondary) }
                                    .buttonStyle(.plain).accessibilityLabel(entry.favorite ? "Unfavorite color" : "Favorite color")
                                Menu { ColorActions(store: store, color: entry.color, name: entry.name)
                                    Divider()
                                    Button("Delete Color", role: .destructive) { store.deleteColor(entry.id) }
                                } label: { Image(systemName: "ellipsis") }
                                    .menuStyle(.borderlessButton)
                                    .menuIndicator(.hidden)
                                    .frame(width: 22)
                                    .accessibilityLabel("Color actions")
                            }
                            .padding(10).background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
                        }
                    }.padding(.horizontal, 20).padding(.bottom, 8)
                }
            }
        }
        .confirmationDialog("Clear recent color history?", isPresented: $confirmingClear) {
            Button("Clear History", role: .destructive) { store.clearHistory() }
        } message: { Text("Favorites will be kept. This can’t be undone.") }
    }
}

private struct ColorActions: View {
    @ObservedObject var store: StudioStore
    let color: SampledColor
    var name = "prismdrop"
    var body: some View {
        Button("Select Color") { store.selected = color }
        if store.isEnabled(.formats) {
            Menu("Copy As") {
                ForEach(CopyFormat.allCases) { format in Button(format.title) { store.copy(color, format: format, name: name) } }
            }
        } else { Button("Copy HEX") { store.copy(color, format: .hex) } }
        if store.isEnabled(.contrast) {
            Button("Use as Foreground") { store.useForContrast(color, role: .foreground); store.tab = .contrast }
            Button("Use as Background") { store.useForContrast(color, role: .background); store.tab = .contrast }
        }
    }
}

private struct FormatListView: View {
    @ObservedObject var store: StudioStore
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("Click any format to copy. The selector above sets your default for the screen picker and palettes.")
                    .font(.caption).foregroundStyle(.secondary).padding(.bottom, 6)
                ForEach(CopyFormat.allCases) { format in
                    Button { store.copy(store.selected, format: format) } label: {
                        HStack(spacing: 14) {
                            Text(format.title).font(.callout.weight(.medium)).frame(width: 110, alignment: .leading)
                            Text(format.string(for: store.selected)).font(.system(.caption, design: .monospaced))
                                .lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                            Image(systemName: "doc.on.doc").foregroundStyle(.secondary)
                        }.padding(12).background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
                    }.buttonStyle(.plain).accessibilityLabel("Copy \(format.title)")
                }
                Text("HEX omits alpha by definition. Use HEX + alpha to include it. HSV / HSB are descriptive values, not CSS functions. Tailwind values work in theme.colors or @theme CSS tokens.")
                    .font(.caption2).foregroundStyle(.secondary).padding(.top, 6)
            }.padding(.horizontal, 20).padding(.bottom, 12)
        }
    }
}

private struct PalettesView: View {
    @ObservedObject var store: StudioStore
    @State private var dropTarget = false
    @State private var paletteName = ""
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(spacing: 9) {
                    if store.isExtracting {
                        HStack { ProgressView().controlSize(.small); Text("Finding dominant colors…"); Button("Cancel") { store.cancelExtraction() } }
                    } else {
                        Image(systemName: "photo.on.rectangle.angled").font(.system(size: 26)).foregroundStyle(.secondary)
                        Text("Drop an image to find its colors").font(.headline)
                        Text("PNG, JPEG, HEIC · up to 8 distinct colors").font(.caption).foregroundStyle(.secondary)
                    }
                    HStack { Button("Import Image…") { store.importImage() }; Button("Paste Image") { store.pasteImage() }.keyboardShortcut("v", modifiers: [.command, .shift]) }
                }
                .frame(maxWidth: .infinity).padding(22)
                .background(dropTarget ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(dropTarget ? Color.accentColor : Color.secondary.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [5, 4])))

                if !store.extracted.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            TextField("Palette name", text: $paletteName).textFieldStyle(.roundedBorder).accessibilityLabel("New palette name")
                            Button("Save Palette") { store.saveExtracted(name: paletteName) }.disabled(store.isExtracting)
                        }
                        paletteSwatches(store.extracted)
                        if store.extracted.count < 5 { Text("This image has fewer than five distinct dominant colors.").font(.caption).foregroundStyle(.secondary) }
                    }
                    .padding(14).background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 14))
                    .onAppear { paletteName = store.extractionName }
                    .onChange(of: store.extractionName) { _, name in paletteName = name }
                }
                if store.library.palettes.isEmpty {
                    Text("Saved palettes stay here between launches. Click a swatch to copy in your default format; right-click for every export format.")
                        .font(.callout).foregroundStyle(.secondary).padding(.vertical, 12)
                } else {
                    Text("SAVED PALETTES").font(.caption2.weight(.semibold)).tracking(1).foregroundStyle(.secondary)
                    ForEach(store.library.palettes) { palette in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                TextField("Palette name", text: Binding(get: { store.library.palettes.first { $0.id == palette.id }?.name ?? "" }, set: { store.renamePalette(palette.id, $0) })).textFieldStyle(.plain).font(.headline)
                                Spacer()
                                Button(role: .destructive) { store.deletePalette(palette.id) } label: { Image(systemName: "trash") }.buttonStyle(.plain).help("Delete palette").accessibilityLabel("Delete \(palette.name)")
                            }
                            if palette.colors.isEmpty { Text("All colors removed. Delete this palette or import another image.").font(.caption).foregroundStyle(.secondary) }
                            paletteSwatches(palette.colors, paletteID: palette.id, name: palette.name)
                        }.padding(14).background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 14))
                    }
                }
            }.padding(.horizontal, 20).padding(.bottom, 12)
        }
        .onDrop(of: [UTType.fileURL, UTType.image], isTargeted: $dropTarget) { store.handleDrop($0) }
    }

    private func paletteSwatches(_ colors: [SampledColor], paletteID: UUID? = nil, name: String = "palette") -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 62), spacing: 8)], spacing: 10) {
            ForEach(Array(colors.enumerated()), id: \.offset) { index, color in
                Button { store.copy(color, name: name) } label: {
                    VStack(spacing: 5) {
                        ColorSwatch(color: color, size: 48)
                        Text(color.hex).font(.system(size: 9, design: .monospaced)).foregroundStyle(.secondary)
                    }
                }.buttonStyle(.plain).help("Copy \(store.activeFormat.title): \(color.hex)")
                    .contextMenu {
                        ColorActions(store: store, color: color, name: name)
                        if let paletteID {
                            Divider()
                            Button("Remove Color", role: .destructive) { store.removePaletteColor(paletteID, at: index) }
                        }
                    }
            }
        }
    }
}

private struct ContrastKey: Hashable { let foreground: SampledColor; let background: SampledColor; let canvas: SampledColor; let target: Double }

private struct ContrastView: View {
    @ObservedObject var store: StudioStore
    @State private var target = 4.5
    @State private var suggestion: SampledColor?
    @State private var suggesting = false
    private var result: ContrastResult { ContrastResult(foreground: store.foreground, background: store.background, canvas: store.canvas) }
    private var key: ContrastKey { ContrastKey(foreground: store.foreground, background: store.background, canvas: store.canvas, target: target) }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    ContrastColorField(store: store, role: .foreground)
                    Button { store.swapContrast() } label: { Image(systemName: "arrow.left.arrow.right") }.help("Swap foreground and background").accessibilityLabel("Swap colors").padding(.top, 30)
                    ContrastColorField(store: store, role: .background)
                }
                HStack {
                    Text("Transparency over").font(.caption).foregroundStyle(.secondary)
                    Picker("Canvas", selection: $store.canvas) { Text("White canvas").tag(SampledColor.white); Text("Black canvas").tag(SampledColor.black) }
                        .labelsHidden().frame(width: 142)
                    Spacer()
                }
                VStack(alignment: .leading, spacing: 7) {
                    Text("Color speaks.").font(.system(size: 24, weight: .semibold))
                    Text("The small details make the difference.").font(.system(size: 14))
                }
                .foregroundStyle(Color(nsColor: store.foreground.nsColor))
                .frame(maxWidth: .infinity, minHeight: 55, alignment: .leading).padding(14)
                .background(Color(nsColor: store.background.nsColor))
                .background(Color(nsColor: store.canvas.nsColor))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.primary.opacity(0.12), lineWidth: 1))
                HStack(alignment: .firstTextBaseline) {
                    Text(String(format: "%.2f:1", result.ratio)).font(.system(size: 31, weight: .semibold, design: .rounded)).monospacedDigit()
                    Text("WCAG 2.x contrast").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                }
                HStack(spacing: 8) {
                    contrastBadge("AA normal", result.normalAA, "4.5:1")
                    contrastBadge("AAA normal", result.normalAAA, "7:1")
                    contrastBadge("AA large", result.largeAA, "3:1")
                    contrastBadge("AAA large", result.largeAAA, "4.5:1")
                }
                Text("Large text: at least 18 pt regular or 14 pt bold. Ratios are evaluated before rounding.")
                    .font(.caption2).foregroundStyle(.secondary)
                Divider()
                HStack {
                    Text("Accessible foreground").font(.callout.weight(.semibold))
                    Spacer()
                    Picker("Target", selection: $target) {
                        Text("AA normal").tag(4.5); Text("AAA normal").tag(7.0); Text("AA large").tag(3.0)
                    }.labelsHidden().frame(width: 142)
                }
                if result.ratio >= target {
                    Label("Your foreground already passes this target.", systemImage: "checkmark.circle").font(.callout).foregroundStyle(.secondary)
                } else if let suggestion {
                    HStack(spacing: 10) {
                        ColorSwatch(color: suggestion, size: 34)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(suggestion.alpha < 1 ? suggestion.hexAlpha : suggestion.hex).font(.system(.callout, design: .monospaced))
                            Text(suggestion.alpha != store.foreground.alpha ? "Opacity increased to meet the target" : "Closest passing sRGB foreground")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Copy") { store.copy(suggestion) }
                        Button("Use") { store.foreground = suggestion }
                    }
                } else if suggesting { ProgressView("Finding a passing shade…").controlSize(.small) }
                else { Text("No foreground can reach this target on the current background. Try changing the background.").font(.callout).foregroundStyle(.secondary) }
            }.padding(.horizontal, 20).padding(.bottom, 12)
        }
        .task(id: key) {
            suggestion = nil
            let input = key
            guard result.ratio < target else { suggesting = false; return }
            suggesting = true
            let task = Task.detached(priority: .userInitiated) {
                ContrastResult(foreground: input.foreground, background: input.background, canvas: input.canvas).suggestion(target: input.target, canvas: input.canvas)
            }
            let value = await withTaskCancellationHandler(operation: { await task.value }, onCancel: { task.cancel() })
            guard !Task.isCancelled, key == input else { return }
            suggestion = value; suggesting = false
        }
    }

    private func contrastBadge(_ title: String, _ pass: Bool, _ threshold: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.caption2.weight(.medium))
            Label(pass ? "Pass" : "Fail", systemImage: pass ? "checkmark.circle.fill" : "xmark.circle")
                .font(.caption.weight(.semibold)).foregroundStyle(pass ? Color.green : Color.secondary)
            Text(threshold).font(.caption2).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(10).background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct ContrastColorField: View {
    @ObservedObject var store: StudioStore
    let role: ContrastRole
    @State private var draft = ""
    @State private var invalid = false
    @FocusState private var focused: Bool
    private var color: SampledColor { role == .foreground ? store.foreground : store.background }
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(role.rawValue).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ColorPicker(role.rawValue, selection: Binding(get: { Color(nsColor: color.nsColor) }, set: { value in
                    if let c = NSColor(value).usingColorSpace(.sRGB) {
                        store.useForContrast(SampledColor.from([c.redComponent, c.greenComponent, c.blueComponent], alpha: c.alphaComponent), role: role)
                    }
                }), supportsOpacity: true).labelsHidden()
                TextField("#RRGGBB", text: $draft).font(.system(.body, design: .monospaced)).textFieldStyle(.roundedBorder).focused($focused)
                    .accessibilityLabel("\(role.rawValue) HEX").onSubmit { apply() }
            }
            if invalid { Text("Use 3, 4, 6, or 8 HEX digits.").font(.caption2).foregroundStyle(.red) }
            HStack(spacing: 7) {
                Menu("Use Color") {
                    Button("Selected Color") { store.useForContrast(store.selected, role: role) }
                    if store.isEnabled(.history) {
                        Divider()
                        ForEach(store.library.history) { entry in
                            Button("\(entry.favorite ? "★ " : "")\(entry.name.isEmpty ? entry.color.hex : entry.name)  \(entry.color.hex)") { store.useForContrast(entry.color, role: role) }
                        }
                    }
                }.controlSize(.small)
                if store.isEnabled(.picker) { Button("Pick on Screen") { store.requestPick(role) }.controlSize(.small) }
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
        .onAppear { sync() }
        .onChange(of: color) { _, _ in if !focused { sync() } }
        .onChange(of: focused) { _, value in if !value { apply() } }
        .onChange(of: draft) { _, value in
            let digits = value.hasPrefix("#") ? value.count - 1 : value.count
            if digits == 6 || digits == 8 { apply() }
            else { invalid = SampledColor(hex: value) == nil }
        }
    }
    private func sync() { draft = color.alpha < 1 ? color.hexAlpha : color.hex; invalid = false }
    private func apply() {
        guard let value = SampledColor(hex: draft) else { invalid = true; return }
        invalid = false; store.useForContrast(value, role: role)
    }
}

private struct FeatureSettingsView: View {
    @ObservedObject var store: StudioStore
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Make PrismDrop yours").font(.headline)
                Text("Turn off anything you don’t use. Disabling a feature keeps its saved data and preferences.")
                    .font(.callout).foregroundStyle(.secondary).padding(.bottom, 4)
                ForEach(StudioFeature.allCases) { feature in
                    Toggle(isOn: Binding(get: { store.isEnabled(feature) }, set: { store.setEnabled(feature, $0) })) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(feature.title).font(.callout.weight(.medium))
                            Text(feature.detail).font(.caption).foregroundStyle(.secondary)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }.toggleStyle(.switch).padding(14).background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
                }
                Text("Library: ~/Library/Application Support/PrismDrop/library.json\nAll formats describe the same SDR sRGB color. Image profiles are converted to sRGB before extraction.")
                    .font(.caption2).foregroundStyle(.secondary).textSelection(.enabled).padding(.top, 4)
            }.padding(.horizontal, 20).padding(.bottom, 12)
        }
    }
}

private func emptyState(_ title: String, symbol: String, detail: String) -> some View {
    VStack(spacing: 12) {
        Image(systemName: symbol).font(.system(size: 31)).foregroundStyle(.tertiary)
        Text(title).font(.headline)
        Text(detail).font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 310)
    }.frame(maxWidth: .infinity, maxHeight: .infinity)
}

@MainActor
final class StudioWindow {
    let window: NSWindow
    init(store: StudioStore, shortcut: String) {
        window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 650, height: 700),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "PrismDrop"
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 620, height: 650)
        window.contentView = NSHostingView(rootView: StudioView(store: store, shortcut: shortcut))
        window.center()
    }
    func show() { window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) }
}
