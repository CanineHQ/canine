import AppKit
import SwiftUI

@main
enum Entry {
    static func main() {
        if let index = CommandLine.arguments.firstIndex(of: "--snapshot") {
            let dir = CommandLine.arguments.dropFirst(index + 1).first ?? "snapshots"
            MainActor.assumeIsolated { Snapshot.run(into: URL(fileURLWithPath: dir)) }
        } else {
            CanineConnectApp.main()
        }
    }
}

struct CanineConnectApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            PopoverView()
                .environmentObject(model)
                .onAppear { appDelegate.model = model }
        } label: {
            Image(nsImage: Brand.menuBarIcon(for: model.connection))
                .onAppear { appDelegate.model = model }
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var model: AppModel?

    /// Receives canine-connect:// URLs (the OAuth callback). An Apple Event handler rather than SwiftUI's
    /// onOpenURL, which only fires while a view is on screen, and the popover is closed while you're in the browser.
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURL(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    @objc private func handleGetURL(_ event: NSAppleEventDescriptor, withReplyEvent reply: NSAppleEventDescriptor) {
        guard let string = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: string) else { return }
        Task { @MainActor in
            guard let model = self.model else { return }
            await model.handleCallback(url)
            // Bring the result into view: the person is still looking at their browser.
            MenuBarPopover.show()
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let model else { return .terminateNow }
        Task { @MainActor in
            await model.shutdown()
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}

/// Opens the menu bar popover from code. MenuBarExtra has no API for it, so this clicks its status item button.
@MainActor
enum MenuBarPopover {
    static func show() {
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows where window.className.contains("NSStatusBarWindow") {
            if let button = findButton(in: window.contentView) {
                // Already open? A click would close it.
                if NSApp.windows.contains(where: { $0.isVisible && $0.className.contains("MenuBarExtraWindow") }) { return }
                button.performClick(nil)
                return
            }
        }
    }

    private static func findButton(in view: NSView?) -> NSStatusBarButton? {
        guard let view else { return nil }
        if let button = view as? NSStatusBarButton { return button }
        for subview in view.subviews {
            if let button = findButton(in: subview) { return button }
        }
        return nil
    }
}

enum Brand {
    static let accent = Color(red: 0.05, green: 0.62, blue: 0.78)
    static let connected = Color(red: 0.16, green: 0.72, blue: 0.45)
    static let connectedEnd = Color(red: 0.07, green: 0.62, blue: 0.70)

    static let logo: NSImage = {
        if let url = Bundle.main.url(forResource: "logo", withExtension: "png"), let image = NSImage(contentsOf: url) {
            return image
        }
        // Running unbundled (swift run / --snapshot from .build): fall back to the source tree.
        let source = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Resources/logo.png")
        return NSImage(contentsOf: source) ?? NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: nil)!
    }()

    /// The dog's silhouette as a template image, so macOS tints it for light/dark menu bars. Solid when
    /// connected, faded when not, half-faded while changing.
    static func menuBarIcon(for connection: AppModel.Connection) -> NSImage {
        let alpha: CGFloat
        switch connection {
        case .connected: alpha = 1
        case .connecting, .disconnecting: alpha = 0.6
        case .disconnected: alpha = 0.35
        }
        return silhouettes[alpha] ?? makeSilhouette(alpha: alpha)
    }

    private static var silhouettes: [CGFloat: NSImage] = [:]

    /// The logo's colored body without its white sticker border, as an alpha mask.
    private static let glyphMask: NSImage = {
        guard let tiff = logo.tiffRepresentation, let source = NSBitmapImageRep(data: tiff) else { return logo }
        let (w, h) = (source.pixelsWide, source.pixelsHigh)
        guard let mask = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h, bitsPerSample: 8,
                                          samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                          bytesPerRow: 0, bitsPerPixel: 0) else { return logo }
        for y in 0..<h {
            for x in 0..<w {
                guard let c = source.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { continue }
                // Drop the white border (bright, unsaturated); keep the colored dog and its dark outlines.
                let isBorder = c.brightnessComponent > 0.9 && c.saturationComponent < 0.15
                let a = isBorder ? 0 : c.alphaComponent
                mask.setColor(NSColor(deviceRed: 0, green: 0, blue: 0, alpha: a), atX: x, y: y)
            }
        }
        let image = NSImage(size: logo.size)
        image.addRepresentation(mask)
        return image
    }()

    private static func makeSilhouette(alpha: CGFloat) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            glyphMask.draw(in: rect)
            NSColor.black.withAlphaComponent(alpha).set()
            rect.fill(using: .sourceIn)
            // Stripes across the body, echoing the logo's bands.
            for y in [4.4, 7.6] {
                NSRect(x: 0, y: y, width: 13.2, height: 1.1).fill(using: .clear)
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Canine Connect"
        silhouettes[alpha] = image
        return image
    }
}

/// `CanineConnect --snapshot <dir>` renders the popover in each state to PNGs, for checking the design
/// without clicking through the menu bar.
@MainActor
enum Snapshot {
    static func run(into dir: URL) {
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let states: [(String, AppModel)] = [
            ("signed-out", AppModel(preview: .disconnected, signedIn: false)),
            ("waiting-for-browser", AppModel(preview: .disconnected, signedIn: false, awaitingBrowser: true)),
            ("disconnected", AppModel(preview: .disconnected)),
            ("connecting", AppModel(preview: .connecting("Connecting to production…"))),
            ("connected", AppModel(preview: .connected)),
            ("error", AppModel(preview: .disconnected, error: "Telepresence needs administrator access to create the network tunnel."))
        ]

        for (name, connection) in [("disconnected", AppModel.Connection.disconnected), ("connected", .connected)] {
            let icon = Brand.menuBarIcon(for: connection)
            let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 72, pixelsHigh: 72, bitsPerSample: 8,
                                       samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                       bytesPerRow: 0, bitsPerPixel: 0)!
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
            NSColor.white.setFill()
            NSRect(x: 0, y: 0, width: 72, height: 72).fill()
            icon.draw(in: NSRect(x: 0, y: 0, width: 72, height: 72))
            NSGraphicsContext.restoreGraphicsState()
            let file = dir.appendingPathComponent("menubar-\(name).png")
            try? rep.representation(using: .png, properties: [:])?.write(to: file)
            print(file.path)
        }

        for appearance in [NSAppearance.Name.darkAqua, .aqua] {
            for (name, model) in states {
                let view = PopoverView()
                    .environmentObject(model)
                    .background(Color(nsColor: .windowBackgroundColor))
                let host = NSHostingView(rootView: view)
                host.appearance = NSAppearance(named: appearance)
                host.frame.size = host.fittingSize

                let window = NSWindow(contentRect: host.frame, styleMask: .borderless, backing: .buffered, defer: false)
                window.appearance = NSAppearance(named: appearance)
                window.contentView = host
                host.layoutSubtreeIfNeeded()
                RunLoop.main.run(until: Date().addingTimeInterval(0.3))

                guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { continue }
                host.cacheDisplay(in: host.bounds, to: rep)
                let suffix = appearance == .darkAqua ? "dark" : "light"
                let file = dir.appendingPathComponent("\(name)-\(suffix).png")
                try? rep.representation(using: .png, properties: [:])?.write(to: file)
                print(file.path)
            }
        }
    }
}
