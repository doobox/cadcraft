import Observation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
@Observable
final class DrawingDocument {
    var snapshot = DrawingSnapshot.empty
    var cursorFeedback = CursorFeedback.empty
    var commandText = ""
    var dynamicEntry = ""
    private(set) var commandCatalog: [CommandSuggestion] = []
    var presentedError: EngineError?
    var showsToolSidebar = true
    var showsInspector = true
    var showsLayerManager = false
    var showsCommandHistory = false
    var showsDrawingRecovery = false
    var commandFocusRevision = 0
    private(set) var recentDrawingURLs: [URL] = []
    private(set) var recoveryItems: [DrawingRecoveryItem] = []

    var canEditSelection: Bool {
        snapshot.selectionCount > 0
    }

    var canPasteDrawing: Bool {
        NSPasteboard.general.availableType(from: [drawingPasteboardType]) != nil
    }

    var isPresentingError: Bool {
        get { presentedError != nil }
        set {
            if !newValue {
                presentedError = nil
            }
        }
    }

    private var engine: EngineSession?
    private var mirroredClipboardSerial: UInt64?
    private var commandHistory: [String] = []
    private var commandHistoryIndex: Int?
    private var viewportSize = CGSize(width: 1, height: 1)
    private var hasFitInitialViewport = false
    private(set) var commandSuggestionIndex = 0
    private let drawingPasteboardType = NSPasteboard.PasteboardType("com.garysimpson.arcworks.dxf-selection")

    init() {
        do {
            engine = try EngineSession()
            commandCatalog = try engine?.commandCatalog() ?? []
            configureAutosave()
            refresh()
            refreshRecentDrawings()
        } catch {
            presentedError = error as? EngineError ?? .message(error.localizedDescription)
        }
    }

    func submitCommand() {
        let command = commandText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !command.isEmpty else {
            enter()
            return
        }
        let shouldRemember = isAwaitingCommand
        commandText = ""
        commandHistoryIndex = nil
        if shouldRemember, commandHistory.last != command {
            commandHistory.append(command)
            if commandHistory.count > 100 {
                commandHistory.removeFirst(commandHistory.count - 100)
            }
        }
        submit(command)
    }

    var commandSuggestions: [CommandSuggestion] {
        let query = commandText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard isAwaitingCommand, !query.isEmpty, !query.contains(where: \.isWhitespace) else { return [] }
        return commandCatalog
            .filter { suggestion in
                suggestion.id.lowercased().contains(query)
                    || suggestion.label.lowercased().contains(query)
                    || suggestion.aliases.contains { $0.lowercased().contains(query) }
            }
            .sorted { lhs, rhs in
                let lhsRank = commandSuggestionRank(lhs, query: query)
                let rhsRank = commandSuggestionRank(rhs, query: query)
                return lhsRank == rhsRank ? lhs.label.localizedCaseInsensitiveCompare(rhs.label) == .orderedAscending : lhsRank < rhsRank
            }
    }

    func commandTextDidChange() {
        commandSuggestionIndex = 0
        guard let commandHistoryIndex else { return }
        if commandText != commandHistory[commandHistoryIndex] {
            self.commandHistoryIndex = nil
        }
    }

    func recallPreviousCommand() {
        if moveCommandSuggestion(by: -1) { return }
        guard isAwaitingCommand, !commandHistory.isEmpty else { return }
        let index = max(0, (commandHistoryIndex ?? commandHistory.count) - 1)
        commandHistoryIndex = index
        commandText = commandHistory[index]
    }

    func recallNextCommand() {
        if moveCommandSuggestion(by: 1) { return }
        guard isAwaitingCommand, let commandHistoryIndex else { return }
        let index = commandHistoryIndex + 1
        if index < commandHistory.count {
            self.commandHistoryIndex = index
            commandText = commandHistory[index]
        } else {
            self.commandHistoryIndex = nil
            commandText = ""
        }
    }

    func completeCommand() {
        let suggestions = Array(commandSuggestions.prefix(8))
        guard !suggestions.isEmpty else { return }
        let suggestion = suggestions[min(commandSuggestionIndex, suggestions.count - 1)]
        commandHistoryIndex = nil
        commandText = suggestion.id.uppercased()
    }

    var selectedCommandSuggestionID: String? {
        let suggestions = Array(commandSuggestions.prefix(8))
        guard !suggestions.isEmpty else { return nil }
        return suggestions[min(commandSuggestionIndex, suggestions.count - 1)].id
    }

    func beginCommandEntry(with characters: String) {
        guard isAwaitingCommand, !characters.isEmpty else { return }
        commandHistoryIndex = nil
        commandText = characters
        commandFocusRevision += 1
    }

    func toggleCommandHistory() {
        showsCommandHistory.toggle()
    }

    func toggleToolSidebar() {
        showsToolSidebar.toggle()
    }

    func toggleInspector() {
        showsInspector.toggle()
    }

    func selectLayout(_ name: String) {
        guard name != snapshot.currentLayout else { return }
        if !isAwaitingCommand {
            cancel(showErrors: false)
        }
        do {
            try engine?.setLayout(name)
            resetInteractionState()
            refresh()
            zoomExtents()
        } catch {
            present(error)
        }
    }

    func createLayout() {
        if !isAwaitingCommand {
            cancel(showErrors: false)
        }
        do {
            try engine?.createLayout()
            resetInteractionState()
            refresh()
            zoomExtents()
        } catch {
            present(error)
        }
    }

    func setAnnotationScale(_ name: String) {
        guard name != snapshot.currentAnnotationScale else { return }
        do {
            try engine?.setAnnotationScale(name)
            refresh()
        } catch {
            present(error)
        }
    }

    func runCommand(_ suggestion: CommandSuggestion) {
        commandText = suggestion.id
        submitCommand()
    }

    func newDrawing() {
        guard confirmSaveIfNeeded() else { return }
        do {
            try engine?.newDrawing(metric: true)
            resetInteractionState()
            refresh()
            zoomExtents()
        } catch {
            present(error)
        }
    }

    func openDrawing() {
        let panel = NSOpenPanel()
        panel.title = "Open Drawing"
        panel.prompt = "Open"
        panel.allowedContentTypes = drawingTypes
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.openDrawing(at: url)
        }
    }

    func openDrawing(at url: URL) {
        if let path = snapshot.path,
           URL(filePath: path).standardizedFileURL == url.standardizedFileURL {
            return
        }
        guard confirmSaveIfNeeded() else { return }
        do {
            try engine?.open(url)
            resetInteractionState()
            refresh()
            zoomExtents()
            rememberRecentDrawing(url)
        } catch {
            present(error)
        }
    }

    func saveDrawing() {
        guard snapshot.path != nil else {
            saveDrawingAs()
            return
        }
        do {
            try engine?.save()
            refresh()
        } catch {
            present(error)
        }
    }

    func saveDrawingAs() {
        let panel = makeSavePanel()
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.save(to: url)
        }
    }

    func exportDrawing() {
        let panel = NSSavePanel()
        panel.title = "Export Drawing"
        panel.prompt = "Export"
        panel.allowedContentTypes = exportTypes
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = exportFileName
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try self?.engine?.export(to: url)
            } catch {
                self?.present(error)
            }
        }
    }

    func runAutosaveLoop() async {
        while !Task.isCancelled {
            autosaveTick()
            do {
                try await Task.sleep(for: .seconds(30))
            } catch is CancellationError {
                return
            } catch {
                return
            }
        }
    }

    func presentDrawingRecovery() {
        showsDrawingRecovery = !recoveryItems.isEmpty
    }

    func dismissDrawingRecovery() {
        showsDrawingRecovery = false
    }

    func recoverDrawing(_ item: DrawingRecoveryItem) {
        guard confirmSaveIfNeeded() else { return }
        do {
            try engine?.recover(item)
            recoveryItems.removeAll { $0.id == item.id }
            showsDrawingRecovery = !recoveryItems.isEmpty
            resetInteractionState()
            refresh()
            zoomExtents()
        } catch {
            present(error)
        }
    }

    func discardRecovery(_ item: DrawingRecoveryItem) {
        do {
            try engine?.discardRecovery(item)
            recoveryItems.removeAll { $0.id == item.id }
            showsDrawingRecovery = !recoveryItems.isEmpty
        } catch {
            present(error)
        }
    }

    func prepareForTermination() -> Bool {
        guard confirmSaveIfNeeded() else { return false }
        do {
            try engine?.shutdownAutosave()
        } catch {
            present(error)
        }
        return true
    }

    func clearRecentDrawings() {
        NSDocumentController.shared.clearRecentDocuments(nil)
        refreshRecentDrawings()
    }

    func undo() {
        guard snapshot.undoLabel != nil else { return }
        submit("u")
    }

    func redo() {
        guard snapshot.redoLabel != nil else { return }
        submit("redo")
    }

    func cutSelection() {
        copySelection(command: "cutclip")
    }

    func copySelection() {
        copySelection(command: "copyclip")
    }

    func pasteSelection() {
        do {
            guard let text = NSPasteboard.general.string(forType: drawingPasteboardType) else { return }
            try engine?.loadClipboard(text)
            try engine?.submit("pasteclip")
            refresh()
        } catch {
            present(error)
        }
    }

    func deleteSelection() {
        guard canEditSelection else { return }
        submit("erase.selection")
    }

    func selectAll() {
        submit("selectall")
    }

    func submit(_ command: String) {
        do {
            try engine?.submit(command)
            refresh()
        } catch {
            presentedError = error as? EngineError ?? .message(error.localizedDescription)
        }
    }

    func updateDynamicEntry(_ value: String) {
        dynamicEntry = value
    }

    func submitDynamicEntry() {
        let value = dynamicEntry.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            enter()
            return
        }
        dynamicEntry = ""
        submit(value)
    }

    func toggleDrafting(_ setting: DraftingSetting) {
        do {
            try engine?.toggleDrafting(setting)
            refresh()
        } catch {
            presentedError = error as? EngineError ?? .message(error.localizedDescription)
        }
    }

    func setCurrentLayer(_ layer: LayerSummary) {
        guard !layer.current else { return }
        do {
            try engine?.setCurrentLayer(layer.name)
            refresh()
        } catch {
            presentedError = error as? EngineError ?? .message(error.localizedDescription)
        }
    }

    func setSelectionLayer(_ layer: LayerSummary) {
        do {
            try engine?.setSelectionLayer(layer.name)
            refresh()
        } catch {
            presentedError = error as? EngineError ?? .message(error.localizedDescription)
        }
    }

    func setSelectionProperty(_ row: PropertyRow, valueJson: String) {
        guard row.editable else { return }
        do {
            try engine?.setSelectionProperty(key: row.key, valueJson: valueJson)
            refresh()
        } catch {
            presentedError = error as? EngineError ?? .message(error.localizedDescription)
        }
    }

    func createLayer(named name: String) {
        performLayerAction(.create, name: name)
    }

    func renameLayer(_ layer: LayerSummary, to name: String) {
        performLayerAction(.rename, name: layer.name, value: name)
    }

    func setLayerColor(_ layer: LayerSummary, color: LayerColorOption) {
        performLayerAction(.color, name: layer.name, value: color.rawValue)
    }

    func setLayerColor(_ layer: LayerSummary, value: String) {
        performLayerAction(.color, name: layer.name, value: value)
    }

    func toggleLayerVisibility(_ layer: LayerSummary) {
        performLayerAction(.toggleOn, name: layer.name)
    }

    func toggleLayerFrozen(_ layer: LayerSummary) {
        performLayerAction(.toggleFrozen, name: layer.name)
    }

    func toggleLayerLocked(_ layer: LayerSummary) {
        performLayerAction(.toggleLocked, name: layer.name)
    }

    func toggleLayerPlot(_ layer: LayerSummary) {
        performLayerAction(.togglePlot, name: layer.name)
    }

    func setLayerLinetype(_ layer: LayerSummary, value: String) {
        performLayerAction(.linetype, name: layer.name, value: value)
    }

    func setLayerLineweight(_ layer: LayerSummary, value: String) {
        performLayerAction(.lineweight, name: layer.name, value: value)
    }

    func setLayerTransparency(_ layer: LayerSummary, value: Int) {
        performLayerAction(.transparency, name: layer.name, value: String(value))
    }

    func setLayerDescription(_ layer: LayerSummary, value: String) {
        performLayerAction(.description, name: layer.name, value: value)
    }

    func setLayerPlotStyle(_ layer: LayerSummary, value: String) {
        performLayerAction(.plotStyle, name: layer.name, value: value)
    }

    func toggleLayerNewViewportFrozen(_ layer: LayerSummary) {
        performLayerAction(.toggleNewViewportFrozen, name: layer.name)
    }

    func toggleLayerViewportFrozen(_ layer: LayerSummary) {
        performLayerAction(.toggleViewportFrozen, name: layer.name)
    }

    func setLayerViewportColor(_ layer: LayerSummary, value: String) {
        performLayerAction(.viewportColor, name: layer.name, value: value)
    }

    func clearLayerViewportColor(_ layer: LayerSummary) {
        performLayerAction(.clearViewportColor, name: layer.name)
    }

    func loadLinetype(named name: String) {
        performLayerAction(.loadLinetype, name: name)
    }

    func saveLayerState(named name: String) {
        performLayerAction(.saveState, name: name)
    }

    func restoreLayerState(named name: String) {
        performLayerAction(.restoreState, name: name)
    }

    func deleteLayerState(named name: String) {
        performLayerAction(.deleteState, name: name)
    }

    func renameLayerState(named name: String, to newName: String) {
        performLayerAction(.renameState, name: name, value: newName)
    }

    func deleteLayer(_ layer: LayerSummary) {
        performLayerAction(.delete, name: layer.name)
    }

    func presentLayerManager() {
        showsLayerManager = true
    }

    func dismissLayerManager() {
        showsLayerManager = false
    }

    func activateTool(_ command: String) {
        if snapshot.prompt != "Command:" {
            cancel(showErrors: false)
        }
        submit(command)
    }

    func submit(point: WorldPoint, shift: Bool, viewportSize: CGSize) {
        do {
            try engine?.submit(point: point, shift: shift, viewportSize: viewportSize)
            cursorFeedback = .empty
            dynamicEntry = ""
            refresh()
        } catch {
            presentedError = error as? EngineError ?? .message(error.localizedDescription)
        }
    }

    func updateCursor(
        point: WorldPoint,
        shift: Bool,
        worldPerPixel: Double,
        viewportSize: CGSize,
        timestamp: TimeInterval
    ) {
        do {
            guard let engine else { return }
            cursorFeedback = try engine.updateCursor(
                point: point,
                shift: shift,
                worldPerPixel: worldPerPixel,
                viewportSize: viewportSize,
                timestamp: timestamp
            )
        } catch {
            cursorFeedback = .empty
        }
    }

    func selectWindow(from start: WorldPoint, to end: WorldPoint, shift: Bool, viewportSize: CGSize) {
        do {
            try engine?.selectWindow(from: start, to: end, shift: shift, viewportSize: viewportSize)
            cursorFeedback = .empty
            refresh()
        } catch {
            presentedError = error as? EngineError ?? .message(error.localizedDescription)
        }
    }

    func beginGrip(_ grip: GripPrimitive) {
        do {
            try engine?.beginGrip(grip)
            refresh()
        } catch {
            presentedError = error as? EngineError ?? .message(error.localizedDescription)
        }
    }

    func enter() {
        do {
            try engine?.enter()
            cursorFeedback = .empty
            dynamicEntry = ""
            refresh()
        } catch {
            presentedError = error as? EngineError ?? .message(error.localizedDescription)
        }
    }

    func cancel() {
        cancel(showErrors: true)
    }

    func zoomExtents() {
        do {
            try engine?.zoomExtents(viewportSize: viewportSize)
            refresh()
        } catch {
            present(error)
        }
    }

    func zoomIn() {
        zoomView(factor: 1.25, at: CGPoint(x: viewportSize.width / 2, y: viewportSize.height / 2), viewportSize: viewportSize)
    }

    func zoomOut() {
        zoomView(factor: 0.8, at: CGPoint(x: viewportSize.width / 2, y: viewportSize.height / 2), viewportSize: viewportSize)
    }

    func updateViewportSize(_ size: CGSize) {
        guard size.width.isFinite, size.height.isFinite else { return }
        viewportSize = CGSize(width: max(size.width, 1), height: max(size.height, 1))
        guard !hasFitInitialViewport, size.width > 1, size.height > 1 else { return }
        hasFitInitialViewport = true
        Task { [weak self] in
            self?.zoomExtents()
        }
    }

    func panView(screenDelta: CGSize, viewportSize: CGSize) {
        do {
            updateViewportSize(viewportSize)
            try engine?.panView(screenDelta: screenDelta, viewportSize: self.viewportSize)
            refresh()
        } catch {
            present(error)
        }
    }

    func zoomView(factor: Double, at screenPoint: CGPoint, viewportSize: CGSize) {
        do {
            updateViewportSize(viewportSize)
            try engine?.zoomView(factor: factor, at: screenPoint, viewportSize: self.viewportSize)
            refresh()
        } catch {
            present(error)
        }
    }

    func refresh() {
        do {
            guard let engine else { throw EngineError.unavailable }
            snapshot = try engine.snapshot()
            mirrorEngineClipboardIfNeeded()
        } catch {
            presentedError = error as? EngineError ?? .message(error.localizedDescription)
        }
    }

    func dismissError() {
        presentedError = nil
    }

    private func cancel(showErrors: Bool) {
        do {
            try engine?.cancel()
            commandText = ""
            commandHistoryIndex = nil
            commandSuggestionIndex = 0
            cursorFeedback = .empty
            dynamicEntry = ""
            refresh()
        } catch {
            if showErrors {
                presentedError = error as? EngineError ?? .message(error.localizedDescription)
            }
        }
    }

    private func copySelection(command: String) {
        guard canEditSelection else { return }
        do {
            try engine?.submit(command)
            refresh()
        } catch {
            present(error)
        }
    }

    private func mirrorEngineClipboardIfNeeded() {
        guard let serial = snapshot.clipboardSerial, serial != mirroredClipboardSerial else { return }
        guard let engine, let text = try? engine.clipboardText() else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: drawingPasteboardType)
        mirroredClipboardSerial = serial
    }

    var isAwaitingCommand: Bool {
        snapshot.prompt.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare("Command:") == .orderedSame
    }

    private func commandSuggestionRank(_ suggestion: CommandSuggestion, query: String) -> Int {
        let id = suggestion.id.lowercased()
        let label = suggestion.label.lowercased()
        let aliases = suggestion.aliases.map { $0.lowercased() }
        if id == query || aliases.contains(query) { return 0 }
        if id.hasPrefix(query) { return 1 }
        if aliases.contains(where: { $0.hasPrefix(query) }) { return 2 }
        if label.hasPrefix(query) { return 3 }
        return 4
    }

    private func moveCommandSuggestion(by offset: Int) -> Bool {
        let suggestions = Array(commandSuggestions.prefix(8))
        guard !suggestions.isEmpty else { return false }
        commandSuggestionIndex = (commandSuggestionIndex + offset + suggestions.count) % suggestions.count
        return true
    }

    private var drawingTypes: [UTType] {
        ["dxf", "dwg", "dwt"].compactMap { UTType(filenameExtension: $0) }
    }

    private var suggestedFileName: String {
        if let path = snapshot.path {
            return URL(filePath: path).lastPathComponent
        }
        let title = snapshot.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? "Drawing.dxf" : "\(title).dxf"
    }

    private var exportTypes: [UTType] {
        [UTType.pdf, UTType.png, UTType(filenameExtension: "svg")].compactMap { $0 }
    }

    private var exportFileName: String {
        let baseName = snapshot.path.map { URL(filePath: $0).deletingPathExtension().lastPathComponent }
            ?? snapshot.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(baseName.isEmpty ? "Drawing" : baseName).pdf"
    }

    private func confirmSaveIfNeeded() -> Bool {
        guard snapshot.dirty else { return true }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Do you want to save the changes to “\(snapshot.title)”?"
        alert.informativeText = "Your changes will be lost if you don’t save them."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Don’t Save")
        alert.buttons[2].hasDestructiveAction = true

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            return saveBeforeReplacingDrawing()
        case .alertThirdButtonReturn:
            return true
        default:
            return false
        }
    }

    private func saveBeforeReplacingDrawing() -> Bool {
        if snapshot.path != nil {
            do {
                try engine?.save()
                refresh()
                return true
            } catch {
                present(error)
                return false
            }
        }

        let panel = makeSavePanel()
        guard panel.runModal() == .OK, let url = panel.url else { return false }
        do {
            try engine?.saveAs(url)
            refresh()
            return true
        } catch {
            present(error)
            return false
        }
    }

    private func makeSavePanel() -> NSSavePanel {
        let panel = NSSavePanel()
        panel.title = "Save Drawing As"
        panel.prompt = "Save"
        panel.allowedContentTypes = drawingTypes
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = suggestedFileName
        return panel
    }

    private func save(to url: URL) {
        do {
            try engine?.saveAs(url)
            refresh()
            rememberRecentDrawing(url)
        } catch {
            present(error)
        }
    }

    private func rememberRecentDrawing(_ url: URL) {
        NSDocumentController.shared.noteNewRecentDocumentURL(url)
        refreshRecentDrawings()
    }

    private func refreshRecentDrawings() {
        let supportedExtensions = Set(["dxf", "dwg", "dwt"])
        recentDrawingURLs = NSDocumentController.shared.recentDocumentURLs
            .filter { supportedExtensions.contains($0.pathExtension.lowercased()) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
            .prefix(10)
            .map(\.standardizedFileURL)
    }

    private func resetInteractionState() {
        cursorFeedback = .empty
        dynamicEntry = ""
        commandText = ""
        commandHistoryIndex = nil
        commandSuggestionIndex = 0
    }

    private func configureAutosave() {
        guard let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appending(path: "ArcWorks", directoryHint: .isDirectory)
            .appending(path: "Autosave", directoryHint: .isDirectory)
        else { return }
        do {
            recoveryItems = try engine?.configureAutosave(directory: directory, minutes: 10) ?? []
            showsDrawingRecovery = !recoveryItems.isEmpty
        } catch {
            present(error)
        }
    }

    private func autosaveTick() {
        do {
            try engine?.autosaveTick()
        } catch {
            present(error)
        }
    }

    private func present(_ error: Error) {
        presentedError = error as? EngineError ?? .message(error.localizedDescription)
    }

    private func performLayerAction(_ action: LayerAction, name: String, value: String = "") {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        do {
            try engine?.performLayerAction(action, name: trimmedName, value: trimmedValue)
            refresh()
        } catch {
            presentedError = error as? EngineError ?? .message(error.localizedDescription)
        }
    }
}

