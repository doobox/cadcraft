import SwiftUI

struct ArcWorksCommands: Commands {
    let document: DrawingDocument

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Drawing", action: document.newDrawing)
                .keyboardShortcut("n", modifiers: [.command])
            Button("Open…", action: document.openDrawing)
                .keyboardShortcut("o", modifiers: [.command])
            Menu("Open Recent") {
                if document.recentDrawingURLs.isEmpty {
                    Button("No Recent Drawings") {}
                        .disabled(true)
                } else {
                    ForEach(document.recentDrawingURLs, id: \.self) { url in
                        Button(url.lastPathComponent) {
                            document.openDrawing(at: url)
                        }
                        .help(url.path(percentEncoded: false))
                    }
                    Divider()
                    Button("Clear Menu", action: document.clearRecentDrawings)
                }
            }
            Button("Drawing Recovery…", action: document.presentDrawingRecovery)
                .disabled(document.recoveryItems.isEmpty)
        }
        CommandGroup(replacing: .saveItem) {
            Button("Save", action: document.saveDrawing)
                .keyboardShortcut("s", modifiers: [.command])
            Button("Save As…", action: document.saveDrawingAs)
                .keyboardShortcut("s", modifiers: [.command, .shift])
        }
        CommandGroup(after: .saveItem) {
            Button("Export…", action: document.exportDrawing)
                .keyboardShortcut("e", modifiers: [.command, .shift])
        }
        CommandGroup(replacing: .undoRedo) {
            Button(document.snapshot.undoLabel.map { "Undo \($0)" } ?? "Undo", action: document.undo)
                .keyboardShortcut("z", modifiers: [.command])
                .disabled(document.snapshot.undoLabel == nil)
            Button(document.snapshot.redoLabel.map { "Redo \($0)" } ?? "Redo", action: document.redo)
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .disabled(document.snapshot.redoLabel == nil)
        }
        CommandGroup(replacing: .pasteboard) {
            Button("Cut", action: document.cutSelection)
                .keyboardShortcut("x", modifiers: [.command])
                .disabled(!document.canEditSelection)
            Button("Copy", action: document.copySelection)
                .keyboardShortcut("c", modifiers: [.command])
                .disabled(!document.canEditSelection)
            Button("Paste", action: document.pasteSelection)
                .keyboardShortcut("v", modifiers: [.command])
                .disabled(!document.canPasteDrawing)
        }
        CommandGroup(replacing: .textEditing) {
            Button("Delete", action: document.deleteSelection)
                .keyboardShortcut(.delete, modifiers: [])
                .disabled(!document.canEditSelection)
            Divider()
            Button("Select All", action: document.selectAll)
                .keyboardShortcut("a", modifiers: [.command])
        }
        CommandMenu("Draw") {
            Button("Line") { document.activateTool("line") }
            Button("Circle") { document.activateTool("circle") }
            Button("Rectangle") { document.activateTool("rectang") }
        }
        CommandMenu("Drafting") {
            Button("Object Snap", action: { document.toggleDrafting(.objectSnap) })
                .keyboardShortcut(KeyEquivalent(Character("\u{F706}")), modifiers: [])
            Button("Grid Display", action: { document.toggleDrafting(.grid) })
                .keyboardShortcut(KeyEquivalent(Character("\u{F70A}")), modifiers: [])
            Button("Ortho Mode", action: { document.toggleDrafting(.ortho) })
                .keyboardShortcut(KeyEquivalent(Character("\u{F70B}")), modifiers: [])
            Button("Snap Mode", action: { document.toggleDrafting(.snap) })
                .keyboardShortcut(KeyEquivalent(Character("\u{F70C}")), modifiers: [])
            Button("Polar Tracking", action: { document.toggleDrafting(.polar) })
                .keyboardShortcut(KeyEquivalent(Character("\u{F70D}")), modifiers: [])
            Button("Object Snap Tracking", action: { document.toggleDrafting(.objectSnapTracking) })
                .keyboardShortcut(KeyEquivalent(Character("\u{F70E}")), modifiers: [])
            Button("Dynamic Input", action: { document.toggleDrafting(.dynamicInput) })
                .keyboardShortcut(KeyEquivalent(Character("\u{F70F}")), modifiers: [])
        }
        CommandGroup(after: .undoRedo) {
            Divider()
            Button("Zoom In", action: document.zoomIn)
                .keyboardShortcut("+", modifiers: [.command])
            Button("Zoom Out", action: document.zoomOut)
                .keyboardShortcut("-", modifiers: [.command])
            Button("Zoom Extents", action: document.zoomExtents)
                .keyboardShortcut("0", modifiers: [.command])
            Button("Cancel Command", action: document.cancel)
                .keyboardShortcut(.escape, modifiers: [])
        }
        CommandGroup(after: .sidebar) {
            Button(document.showsToolSidebar ? "Hide Tools" : "Show Tools", action: document.toggleToolSidebar)
            Button(document.showsInspector ? "Hide Inspector" : "Show Inspector", action: document.toggleInspector)
            .keyboardShortcut("i", modifiers: [.command, .option])
            Button(document.showsCommandHistory ? "Hide Command History" : "Show Command History", action: document.toggleCommandHistory)
                .keyboardShortcut(KeyEquivalent(Character("\u{F705}")), modifiers: [])
        }
    }
}

