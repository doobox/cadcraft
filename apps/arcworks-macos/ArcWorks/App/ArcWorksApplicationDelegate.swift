import AppKit

@MainActor
final class ArcWorksApplicationDelegate: NSObject, NSApplicationDelegate {
    weak var document: DrawingDocument?

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        document?.prepareForTermination() == false ? .terminateCancel : .terminateNow
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            sender.windows.first?.makeKeyAndOrderFront(nil)
        }
        return true
    }
}
