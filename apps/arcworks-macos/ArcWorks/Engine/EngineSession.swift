import ArcWorksBridge
import Foundation

@MainActor
final class EngineSession {
    private let pointer: OpaquePointer

    init() throws {
        guard let pointer = arcworks_session_new() else {
            throw EngineError.unavailable
        }
        self.pointer = pointer
    }

    isolated deinit {
        arcworks_session_free(pointer)
    }

    func newDrawing(metric: Bool) throws {
        try check(decode(arcworks_session_new_drawing(pointer, metric)))
    }

    func commandCatalog() throws -> [CommandSuggestion] {
        let response = try decode(arcworks_command_catalog())
        try check(response)
        return response.commands ?? []
    }

    func open(_ url: URL) throws {
        let response = try url.path.withCString { path in
            try decode(arcworks_session_open(pointer, path))
        }
        try check(response)
    }

    func save() throws {
        try check(decode(arcworks_session_save(pointer)))
    }

    func saveAs(_ url: URL) throws {
        let response = try url.path.withCString { path in
            try decode(arcworks_session_save_as(pointer, path))
        }
        try check(response)
    }

    func export(to url: URL) throws {
        let response = try url.path.withCString { path in
            try decode(arcworks_session_export(pointer, path))
        }
        try check(response)
    }

    func configureAutosave(directory: URL, minutes: UInt32) throws -> [DrawingRecoveryItem] {
        let response = try directory.path.withCString { path in
            try decode(arcworks_session_autosave_configure(pointer, path, minutes))
        }
        try check(response)
        return response.recoveries ?? []
    }

    func autosaveTick() throws {
        try check(decode(arcworks_session_autosave_tick(pointer)))
    }

    func recover(_ item: DrawingRecoveryItem) throws {
        let response = try item.path.withCString { path in
            try item.drawing.withCString { title in
                try decode(arcworks_session_recover(pointer, path, title))
            }
        }
        try check(response)
    }

    func discardRecovery(_ item: DrawingRecoveryItem) throws {
        let response = try item.path.withCString { path in
            try decode(arcworks_session_discard_recovery(pointer, path))
        }
        try check(response)
    }

    func shutdownAutosave() throws {
        try check(decode(arcworks_session_autosave_shutdown(pointer)))
    }

    func submit(_ command: String) throws {
        let response = try command.withCString { text in
            try decode(arcworks_session_command(pointer, text))
        }
        try check(response)
    }

    func clipboardText() throws -> String? {
        let response = try decode(arcworks_session_clipboard_text(pointer))
        try check(response)
        return response.clipboardText
    }

    func loadClipboard(_ text: String) throws {
        let response = try text.withCString { value in
            try decode(arcworks_session_load_clipboard(pointer, value))
        }
        try check(response)
    }

    func panView(screenDelta: CGSize, viewportSize: CGSize) throws {
        try check(
            decode(
                arcworks_session_view_pan(
                    pointer,
                    screenDelta.width,
                    screenDelta.height,
                    viewportSize.width,
                    viewportSize.height
                )
            )
        )
    }

    func zoomView(factor: Double, at screenPoint: CGPoint, viewportSize: CGSize) throws {
        try check(
            decode(
                arcworks_session_view_zoom(
                    pointer,
                    factor,
                    screenPoint.x,
                    screenPoint.y,
                    viewportSize.width,
                    viewportSize.height
                )
            )
        )
    }

    func zoomExtents(viewportSize: CGSize) throws {
        try check(
            decode(
                arcworks_session_zoom_extents(
                    pointer,
                    viewportSize.width,
                    viewportSize.height
                )
            )
        )
    }

    func submit(point: WorldPoint, shift: Bool, viewportSize: CGSize) throws {
        let response = try decode(
            arcworks_session_point(
                pointer,
                Double(point.x),
                Double(point.y),
                shift,
                viewportSize.width,
                viewportSize.height
            )
        )
        try check(response)
    }

    func updateCursor(
        point: WorldPoint,
        shift: Bool,
        worldPerPixel: Double,
        viewportSize: CGSize,
        timestamp: TimeInterval
    ) throws -> CursorFeedback {
        let response = try decode(
            arcworks_session_cursor(
                pointer,
                Double(point.x),
                Double(point.y),
                shift,
                worldPerPixel,
                viewportSize.width,
                viewportSize.height,
                timestamp
            )
        )
        guard response.ok, let cursor = response.cursor else {
            throw EngineError.message(response.error ?? "The cursor preview could not be rendered.")
        }
        return cursor
    }

    func selectWindow(from start: WorldPoint, to end: WorldPoint, shift: Bool, viewportSize: CGSize) throws {
        let response = try decode(
            arcworks_session_window(
                pointer,
                Double(start.x),
                Double(start.y),
                Double(end.x),
                Double(end.y),
                shift,
                viewportSize.width,
                viewportSize.height
            )
        )
        try check(response)
    }

    func beginGrip(_ grip: GripPrimitive) throws {
        let response = try grip.handle.withCString { handle in
            try decode(arcworks_session_begin_grip(pointer, handle, grip.index))
        }
        try check(response)
    }

    func toggleDrafting(_ setting: DraftingSetting) throws {
        let response = try setting.rawValue.withCString { value in
            try decode(arcworks_session_drafting_toggle(pointer, value))
        }
        try check(response)
    }

    func setLayout(_ name: String) throws {
        let response = try name.withCString { value in
            try decode(arcworks_session_set_layout(pointer, value))
        }
        try check(response)
    }

    func createLayout() throws {
        try check(decode(arcworks_session_create_layout(pointer)))
    }

    func setAnnotationScale(_ name: String) throws {
        let response = try name.withCString { value in
            try decode(arcworks_session_set_annotation_scale(pointer, value))
        }
        try check(response)
    }

    func setCurrentLayer(_ name: String) throws {
        let response = try name.withCString { value in
            try decode(arcworks_session_set_current_layer(pointer, value))
        }
        try check(response)
    }

    func setSelectionLayer(_ name: String) throws {
        let response = try name.withCString { value in
            try decode(arcworks_session_set_selection_layer(pointer, value))
        }
        try check(response)
    }

    func setSelectionProperty(key: String, valueJson: String) throws {
        let response = try key.withCString { keyValue in
            try valueJson.withCString { propertyValue in
                try decode(arcworks_session_set_selection_property(pointer, keyValue, propertyValue))
            }
        }
        try check(response)
    }

    func performLayerAction(_ action: LayerAction, name: String, value: String = "") throws {
        let response = try action.rawValue.withCString { actionValue in
            try name.withCString { nameValue in
                try value.withCString { parameterValue in
                    try decode(arcworks_session_layer_action(pointer, actionValue, nameValue, parameterValue))
                }
            }
        }
        try check(response)
    }

    func enter() throws {
        try check(decode(arcworks_session_enter(pointer)))
    }

    func cancel() throws {
        try check(decode(arcworks_session_cancel(pointer)))
    }

    func snapshot() throws -> DrawingSnapshot {
        let response = try decode(arcworks_session_snapshot(pointer))
        guard response.ok, let snapshot = response.snapshot else {
            throw EngineError.message(response.error ?? "The drawing could not be rendered.")
        }
        return snapshot
    }

    private func decode(_ pointer: UnsafeMutablePointer<CChar>?) throws -> BridgeResponse {
        guard let pointer else {
            throw EngineError.invalidResponse
        }
        defer { arcworks_string_free(pointer) }
        let data = Data(String(cString: pointer).utf8)
        return try JSONDecoder().decode(BridgeResponse.self, from: data)
    }

    private func check(_ response: BridgeResponse) throws {
        guard response.ok else {
            throw EngineError.message(response.error ?? "The command could not be completed.")
        }
    }
}

