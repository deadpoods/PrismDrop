import AppKit
import SwiftUI
import UniformTypeIdentifiers

enum StudioFeature: String, CaseIterable, Identifiable {
    case picker, history, formats, palettes, contrast
    var id: String { rawValue }
    var title: String {
        switch self {
        case .picker: return "Screen eyedropper"
        case .history: return "Automatic color history"
        case .formats: return "Developer formats"
        case .palettes: return "Image palettes"
        case .contrast: return "Contrast checker"
        }
    }
    var detail: String {
        switch self {
        case .picker: return "Hold your modifier shortcut to read a screen pixel."
        case .history: return "Remember picked colors locally, with 100 recents plus favorites."
        case .formats: return "Choose a default copy format and export code values."
        case .palettes: return "Import, drop, or paste images and save their dominant colors."
        case .contrast: return "Compare text and background colors with WCAG 2.x."
        }
    }
}

enum StudioTab: String, CaseIterable, Identifiable {
    case history = "History", formats = "Formats", palettes = "Palettes", contrast = "Contrast", settings = "Settings"
    var id: String { rawValue }
    var feature: StudioFeature? {
        switch self {
        case .history: return .history
        case .formats: return .formats
        case .palettes: return .palettes
        case .contrast: return .contrast
        case .settings: return nil
        }
    }
}

enum ContrastRole: String { case foreground = "Foreground", background = "Background" }

@MainActor
final class StudioStore: ObservableObject {
    @Published private(set) var library = ColorLibrary()
    @Published private(set) var enabled: Set<StudioFeature>
    @Published var tab: StudioTab = .history
    @Published var selected = SampledColor(red: 94, green: 177, blue: 242)
    @Published var defaultFormat: CopyFormat { didSet { defaults.set(defaultFormat.rawValue, forKey: "defaultCopyFormat") } }
    @Published var foreground = SampledColor(red: 89, green: 99, blue: 117)
    @Published var background = SampledColor.white
    @Published var canvas = SampledColor.white
    @Published var pendingPick: ContrastRole?
    @Published private(set) var extracted: [SampledColor] = []
    @Published private(set) var extractionName = "Image palette"
    @Published private(set) var isExtracting = false
    @Published var errorMessage: String?
    @Published private(set) var persistenceError: String?
    @Published private(set) var copiedText: String?
    var onPickRequested: (() -> Void)?
    var onPickFinished: (() -> Void)?
    var onFeaturesChanged: (() -> Void)?
    let libraryURL: URL
    private let defaults: UserDefaults
    private let writeQueue = DispatchQueue(label: "local.prismdrop.library", qos: .utility)
    private var revision = 0
    private var storageBlocked = false
    private var extractionID = 0
    private var worker: Task<[SampledColor], Error>?
    private var copiedID = 0

    init(defaults: UserDefaults = .standard, libraryURL: URL? = nil) {
        self.defaults = defaults
        self.libraryURL = libraryURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PrismDrop", isDirectory: true).appendingPathComponent("library.json")
        enabled = Set(StudioFeature.allCases.filter { defaults.object(forKey: "feature.\($0.rawValue)") as? Bool ?? true })
        defaultFormat = CopyFormat(rawValue: defaults.string(forKey: "defaultCopyFormat") ?? "hex") ?? .hex
        reload()
    }

    func isEnabled(_ feature: StudioFeature) -> Bool { enabled.contains(feature) }
    var activeFormat: CopyFormat { isEnabled(.formats) ? defaultFormat : .hex }

    func setEnabled(_ feature: StudioFeature, _ value: Bool) {
        if value { enabled.insert(feature) } else { enabled.remove(feature) }
        defaults.set(value, forKey: "feature.\(feature.rawValue)")
        if !value && feature == .palettes { cancelExtraction() }
        if !value && (feature == .contrast || feature == .picker) { pendingPick = nil }
        onFeaturesChanged?()
    }

    func reload() {
        writeQueue.sync {} // Drain old writes before reading or retrying.
        do {
            library = try ColorLibrary.load(from: libraryURL)
            storageBlocked = false; persistenceError = nil
        } catch {
            storageBlocked = true
            persistenceError = "Couldn’t load the color library: \(error.localizedDescription) The original file is unchanged. Restore it, then Retry."
        }
    }

    func persist() {
        guard !storageBlocked else { return }
        revision += 1
        let current = revision, url = libraryURL
        do {
            let data = try library.encoded()
            writeQueue.async { [weak self] in
                do {
                    try ColorLibrary.write(data, to: url)
                    DispatchQueue.main.async { [weak self] in
                        guard let self, self.revision == current else { return }
                        self.persistenceError = nil
                    }
                } catch {
                    let message = "Couldn’t save colors: \(error.localizedDescription) Your changes remain in memory. Retry saving before quitting."
                    DispatchQueue.main.async { [weak self] in
                        guard let self, self.revision == current else { return }
                        self.persistenceError = message
                    }
                }
            }
        } catch { persistenceError = error.localizedDescription }
    }

    func retryPersistence() { if storageBlocked { reload() } else { persist() } }
    func flush() { writeQueue.sync {} }

    func acceptPicked(_ color: SampledColor, finished: Bool) {
        selected = color
        if isEnabled(.history) { library.record(color); persist() }
        if let role = pendingPick, isEnabled(.contrast) {
            useForContrast(color, role: role)
            if finished { pendingPick = nil; onPickFinished?() }
        }
    }

    @discardableResult func copy(_ color: SampledColor, format: CopyFormat? = nil, name: String = "prismdrop") -> Bool {
        selected = color
        let value = (format ?? activeFormat).string(for: color, name: name)
        NSPasteboard.general.clearContents()
        guard NSPasteboard.general.setString(value, forType: .string) else {
            errorMessage = "Couldn’t write to the clipboard. Try copying again."; return false
        }
        copiedID += 1; let id = copiedID
        copiedText = value
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard self?.copiedID == id else { return }; self?.copiedText = nil
        }
        return true
    }

    func renameColor(_ id: UUID, _ name: String) {
        guard let i = library.history.firstIndex(where: { $0.id == id }) else { return }
        library.history[i].name = String(name.prefix(80)); persist()
    }
    func toggleFavorite(_ id: UUID) {
        guard let i = library.history.firstIndex(where: { $0.id == id }) else { return }
        library.history[i].favorite.toggle(); library.trim(); persist()
    }
    func favoriteSelected() {
        guard isEnabled(.history) else { return }
        library.record(selected)
        if let i = library.history.firstIndex(where: { $0.color.identity == selected.identity }) { library.history[i].favorite = true }
        persist()
    }
    func deleteColor(_ id: UUID) { library.history.removeAll { $0.id == id }; persist() }
    func clearHistory() { library.clearHistory(); persist() }

    func useForContrast(_ color: SampledColor, role: ContrastRole) {
        if role == .foreground { foreground = color } else { background = color }
    }
    func requestPick(_ role: ContrastRole) {
        guard isEnabled(.picker), isEnabled(.contrast) else { return }
        pendingPick = role; onPickRequested?()
    }
    func swapContrast() { let previous = foreground; foreground = background; background = previous }

    func importImage() {
        guard isEnabled(.palettes) else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .heic]
        panel.canChooseDirectories = false; panel.allowsMultipleSelection = false
        panel.message = "Extract a palette from a PNG, JPEG, or HEIC image."
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in self?.extract(url: url) }
        }
    }

    func extract(url: URL) {
        startExtraction(name: url.deletingPathExtension().lastPathComponent) {
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            return try PaletteExtractor.extract(url: url)
        }
    }
    func extract(data: Data, name: String = "Pasted image") {
        startExtraction(name: name) { try PaletteExtractor.extract(data: data) }
    }
    private func startExtraction(name: String, operation: @escaping @Sendable () throws -> [SampledColor]) {
        guard isEnabled(.palettes) else { return }
        cancelExtraction(); isExtracting = true; errorMessage = nil
        let id = extractionID
        let task = Task.detached(priority: .userInitiated, operation: operation)
        worker = task
        Task { [weak self] in
            do {
                let colors = try await task.value
                guard let self, self.extractionID == id, self.isEnabled(.palettes) else { return }
                self.extracted = colors; self.extractionName = String(name.prefix(80)); self.isExtracting = false; self.worker = nil
            } catch {
                guard let self, self.extractionID == id else { return }
                self.isExtracting = false; self.worker = nil
                if !(error is CancellationError) { self.errorMessage = error.localizedDescription }
            }
        }
    }
    func cancelExtraction() { extractionID += 1; worker?.cancel(); worker = nil; isExtracting = false }

    func pasteImage() {
        let board = NSPasteboard.general
        if let urls = board.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL], let url = urls.first {
            extract(url: url); return
        }
        for type in board.types ?? [] {
            if let uti = UTType(type.rawValue), uti.conforms(to: .image), let data = board.data(forType: type) {
                extract(data: data); return
            }
        }
        errorMessage = "The clipboard doesn’t contain an image. Copy an image, then try Paste Image again."
    }

    func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard isEnabled(.palettes), let provider = providers.first else { return false }
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            cancelExtraction(); isExtracting = true
            let id = extractionID
            provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { [weak self] data, error in
                Task { @MainActor in
                    guard let self, self.extractionID == id, self.isEnabled(.palettes) else { return }
                    if let data, let url = URL(dataRepresentation: data, relativeTo: nil), url.isFileURL { self.extract(url: url) }
                    else { self.isExtracting = false; self.errorMessage = error?.localizedDescription ?? "The dropped file couldn’t be opened." }
                }
            }
            return true
        }
        guard let type = provider.registeredTypeIdentifiers.first(where: { UTType($0)?.conforms(to: .image) == true }) else { return false }
        cancelExtraction(); isExtracting = true
        let id = extractionID
        provider.loadDataRepresentation(forTypeIdentifier: type) { [weak self] data, error in
            Task { @MainActor in
                guard let self, self.extractionID == id, self.isEnabled(.palettes) else { return }
                if let data { self.extract(data: data, name: "Dropped image") }
                else { self.isExtracting = false; self.errorMessage = error?.localizedDescription ?? "The dropped image couldn’t be read." }
            }
        }
        return true
    }

    func saveExtracted(name: String) {
        guard !extracted.isEmpty, !isExtracting, isEnabled(.palettes) else { return }
        let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
        library.palettes.insert(SavedPalette(name: String((title.isEmpty ? extractionName : title).prefix(80)), colors: extracted), at: 0)
        extracted = []; persist()
    }
    func renamePalette(_ id: UUID, _ name: String) {
        guard let i = library.palettes.firstIndex(where: { $0.id == id }) else { return }
        library.palettes[i].name = String(name.prefix(80)); persist()
    }
    func removePaletteColor(_ id: UUID, at index: Int) {
        guard let i = library.palettes.firstIndex(where: { $0.id == id }), library.palettes[i].colors.indices.contains(index) else { return }
        library.palettes[i].colors.remove(at: index); persist()
    }
    func deletePalette(_ id: UUID) { library.palettes.removeAll { $0.id == id }; persist() }
}
