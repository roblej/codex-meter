import AppKit
import Combine
import SwiftUI

@main
enum CodexMeterApplication {
    @MainActor
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        application.run()
        withExtendedLifetime(delegate) {}
    }
}

@MainActor
private final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private let store = UsageStore()
    private var popover: NSPopover?
    private var statusItem: NSStatusItem!
    private var storeObserver: AnyCancellable?
    private var globalMouseMonitor: Any?
    private var refreshTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(togglePopover)
        button.sendAction(on: .leftMouseUp)
        button.imagePosition = .imageLeading

        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            DispatchQueue.main.async {
                self?.closePopover()
            }
        }

        storeObserver = store.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateStatusItem()
                self?.schedulePopoverAlignment()
            }
        }
        updateStatusItem()

        Task {
            await store.refresh()
        }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.store.refresh()
            }
        }

        if ProcessInfo.processInfo.arguments.contains("--show-popover") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.showPopover()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        refreshTimer?.invalidate()
        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
        }
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
    }

    @objc private func togglePopover() {
        if popover?.isShown == true {
            closePopover()
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }

        let newPopover = NSPopover()
        newPopover.behavior = .transient
        newPopover.animates = true
        newPopover.delegate = self
        newPopover.contentSize = NSSize(width: 340, height: 322)
        newPopover.contentViewController = NSHostingController(
            rootView: MenuContentView(store: store)
        )
        popover = newPopover
        newPopover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        schedulePopoverAlignment()
    }

    private func schedulePopoverAlignment() {
        DispatchQueue.main.async { [weak self] in
            self?.alignPopoverToMenuBar()
            DispatchQueue.main.async { [weak self] in
                self?.alignPopoverToMenuBar()
            }
        }
    }

    private func alignPopoverToMenuBar() {
        guard
            let popover,
            popover.isShown,
            let button = statusItem.button,
            let popoverWindow = popover.contentViewController?.view.window,
            let screen = button.window?.screen ?? popoverWindow.screen ?? NSScreen.main
        else { return }

        var origin = popoverWindow.frame.origin
        origin.y = screen.visibleFrame.maxY - popoverWindow.frame.height
        popoverWindow.setFrameOrigin(origin)
    }

    private func closePopover() {
        guard let popover, popover.isShown else { return }
        popover.performClose(nil)
    }

    func popoverDidClose(_ notification: Notification) {
        popover?.contentViewController = nil
        popover = nil
    }

    private func updateStatusItem() {
        guard let button = statusItem.button else { return }

        let image = NSImage(systemSymbolName: store.menuIcon, accessibilityDescription: "Codex 사용량")
        image?.isTemplate = true
        button.image = image

        if let usedPercent = store.snapshot?.usedPercent {
            button.title = " \(usedPercent)%"
        } else {
            button.title = ""
        }
    }
}
