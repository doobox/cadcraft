import SwiftUI

@main
struct ArcWorksApp: App {
    @NSApplicationDelegateAdaptor(ArcWorksApplicationDelegate.self) private var appDelegate
    @State private var document = DrawingDocument()

    var body: some Scene {
        Window("ArcWorks", id: "main") {
            WorkspaceView(document: document)
                .frame(minWidth: 900, minHeight: 620)
                .onOpenURL(perform: document.openDrawing(at:))
                .onAppear {
                    appDelegate.document = document
                }
        }
        .defaultSize(width: 1280, height: 820)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            ArcWorksCommands(document: document)
        }
    }
}

