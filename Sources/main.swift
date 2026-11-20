import AppKit
import IOKit.ps
import ServiceManagement

final class WattsApp: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let loginItem = NSMenuItem()
    private var powerSource: CFRunLoopSource?
    private var timer: Timer?
    private var fastRefreshUntil: TimeInterval?
    private var waitingForCharger = false
    private var reading: PowerReading?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        statusItem.button?.image = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: "Maximum charger power")
        statusItem.button?.imagePosition = .imageLeading

        powerSource = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            let app = Unmanaged<WattsApp>.fromOpaque(context).takeUnretainedValue()
            app.powerSourceDidChange()
        }, Unmanaged.passUnretained(self).toOpaque())?.takeRetainedValue()

        if let powerSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), powerSource, .commonModes)
        }
        apply(PowerReading.read())
        populateMenu(menu)
    }

    private func powerSourceDidChange() {
        // Power-source notifications can also report changes unrelated to the charger.
        guard let change = PowerReading.read(whenConnectionChangesFrom: reading?.connected) else { return }
        apply(change)
    }

    @objc private func refresh() {
        waitingForCharger = false
        apply(PowerReading.read())
    }

    private func apply(_ reading: PowerReading?) {
        let now = ProcessInfo.processInfo.systemUptime
        if reading?.connected == false {
            waitingForCharger = false
            fastRefreshUntil = nil
        } else if self.reading?.connected == false && reading?.connected == true {
            // USB-C power telemetry can still reflect the initial connection while PD negotiates.
            waitingForCharger = true
            fastRefreshUntil = now + 5
        }
        self.reading = reading
        let title = waitingForCharger ? "…" : reading?.menuBarTitle ?? "—"
        if statusItem.button?.title != title {
            statusItem.button?.title = title
        }

        if reading?.connected == false && powerSource != nil {
            timer?.invalidate()
            timer = nil
            return
        }

        let interval: TimeInterval = (fastRefreshUntil ?? now) > now ? 1 : 10
        guard timer?.timeInterval != interval else { return }

        timer?.invalidate()
        let nextTimer = Timer(timeInterval: interval, target: self, selector: #selector(refresh), userInfo: nil, repeats: true)
        nextTimer.tolerance = interval == 1 ? 0.1 : 2
        timer = nextTimer
        RunLoop.main.add(nextTimer, forMode: .common)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        apply(PowerReading.read(includeTelemetry: true))
        populateMenu(menu)
    }

    private func populateMenu(_ menu: NSMenu) {
        menu.removeAllItems()

        if waitingForCharger {
            menu.addItem(withTitle: "Reading charger power…", action: nil, keyEquivalent: "")
        } else if reading?.connected == false {
            menu.addItem(withTitle: "No external power", action: nil, keyEquivalent: "")
        } else {
            let input = reading?.inputWatts.map { String(format: "%.1f W", $0) } ?? "Unavailable"
            menu.addItem(withTitle: "Charger input  \(input)", action: nil, keyEquivalent: "")

            if let adapter = reading?.adapter {
                let name = adapter.name ?? "Unavailable"
                menu.addItem(withTitle: "Adapter  \(name)", action: nil, keyEquivalent: "")
                if let maxWatts = adapter.maxWatts {
                    menu.addItem(withTitle: String(format: "Available maximum  %.1f W", maxWatts), action: nil, keyEquivalent: "")
                }
                if let voltage = adapter.voltage, let current = adapter.current {
                    let electricalRating = String(format: "Negotiated  %.3g V · %.3g A", voltage, current)
                    menu.addItem(withTitle: electricalRating, action: nil, keyEquivalent: "")
                }
            }

            if let watts = reading?.batteryWatts {
                let label = watts < 0 ? "Battery discharge" : "Battery charging"
                menu.addItem(withTitle: String(format: "%@  %.1f W", label, abs(watts)), action: nil, keyEquivalent: "")
            }
        }

        menu.addItem(.separator())
        if #available(macOS 13, *) {
            let status = SMAppService.mainApp.status
            loginItem.title = status == .requiresApproval ? "Open Login Items Settings…" : "Launch at Login"
            loginItem.state = status == .enabled ? .on : .off
            loginItem.target = self
            loginItem.action = #selector(toggleLoginItem)
            menu.addItem(loginItem)
        }
        menu.addItem(withTitle: "Quit ChargeWatts", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    }

    @available(macOS 13, *)
    @objc private func toggleLoginItem() {
        let service = SMAppService.mainApp
        do {
            switch service.status {
            case .enabled:
                try service.unregister()
            case .requiresApproval:
                SMAppService.openSystemSettingsLoginItems()
            default:
                try service.register()
            }
        } catch {
            let alert = NSAlert(error: error)
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
    }
}

if #available(macOS 13, *), CommandLine.arguments.dropFirst() == ["--enable-login-item"] {
    let service = SMAppService.mainApp
    do {
        if service.status == .notRegistered || service.status == .notFound {
            try service.register()
        }
        if service.status == .enabled {
            print("Launch at Login is enabled.")
            exit(EXIT_SUCCESS)
        }
        fputs("Check Login Items in System Settings. Status: \(service.status.rawValue)\n", stderr)
    } catch {
        fputs("Could not enable Launch at Login: \(error.localizedDescription)\n", stderr)
    }
    exit(EXIT_FAILURE)
}

let app = NSApplication.shared
let delegate = WattsApp()
app.delegate = delegate
app.run()
