import AppKit

final class WattsApp: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let input = NSMenuItem()
    private let battery = NSMenuItem()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(input)
        menu.addItem(battery)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit ChargeWatts", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu

        statusItem.button?.image = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: "Charger input")
        statusItem.button?.imagePosition = .imageLeading

        update()
        let timer = Timer.scheduledTimer(timeInterval: 10, target: self, selector: #selector(update), userInfo: nil, repeats: true)
        timer.tolerance = 1
    }

    func menuWillOpen(_ menu: NSMenu) {
        update()
    }

    @objc private func update() {
        let reading = PowerReading.read()
        let title = reading?.inputWatts.map { String(format: "%.0f W", $0) } ?? "—"
        if statusItem.button?.title != title {
            statusItem.button?.title = title
        }

        if reading?.connected == false {
            input.title = "No external power"
            battery.isHidden = true
            return
        }

        input.title = reading?.inputWatts.map { String(format: "Charger input  %.1f W", $0) } ?? "Charger input  Unavailable"
        battery.isHidden = false
        if let watts = reading?.batteryWatts {
            let label = watts < 0 ? "Battery discharge" : "Battery charging"
            battery.title = String(format: "%@  %.1f W", label, abs(watts))
        } else {
            battery.title = "Battery charging  Unavailable"
        }
    }
}

let app = NSApplication.shared
let delegate = WattsApp()
app.delegate = delegate
app.run()
