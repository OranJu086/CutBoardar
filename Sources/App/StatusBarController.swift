import AppKit
import SwiftUI

@MainActor
final class StatusBarController: NSObject
{
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private var closeObserver: NSObjectProtocol?

    override init()
    {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        if let button = statusItem.button
        {
            let image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "CutBoardar")
            image?.isTemplate = true
            button.image = image
            button.imagePosition = .imageOnly
            button.target = self
            button.action = #selector(togglePopover)
            button.toolTip = "CutBoardar · ⇧⌘V"
        }

        popover.behavior = .transient
        popover.animates = false
        popover.contentViewController = NSHostingController(rootView: MenuBarView())

        closeObserver = NotificationCenter.default.addObserver(forName: .cbClosePopover, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.close() }
        }
    }

    @objc private func togglePopover()
    {
        guard let button = statusItem.button else { return }

        if popover.isShown
        {
            close()
            return
        }

        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    func close()
    {
        if popover.isShown { popover.performClose(nil) }
    }
}
