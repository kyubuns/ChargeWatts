import Foundation
import IOKit

struct PowerAdapter {
    let name: String?
    let maxWatts: Double?
    let voltage: Double?
    let current: Double?

    static func read(from battery: io_service_t) -> PowerAdapter? {
        guard let details = IORegistryEntryCreateCFProperty(
            battery, "AdapterDetails" as CFString, kCFAllocatorDefault, 0
        )?.takeRetainedValue() as? [String: Any] else { return nil }

        return PowerAdapter(
            name: details["Name"] as? String,
            maxWatts: positiveNumber(details["Watts"]),
            voltage: positiveNumber(details["AdapterVoltage"]).map { $0 / 1_000 },
            current: positiveNumber(details["Current"]).map { $0 / 1_000 }
        )
    }

    private static func positiveNumber(_ value: Any?) -> Double? {
        guard let number = (value as? NSNumber)?.doubleValue, number > 0 else { return nil }
        return number
    }
}

struct PowerReading {
    let connected: Bool
    let inputWatts: Double?
    let batteryWatts: Double?
    let adapter: PowerAdapter?

    var menuBarTitle: String {
        guard connected else { return "—" }
        let input = inputWatts.map { String(format: "%.1f", $0) } ?? "—"
        let maximum = adapter?.maxWatts.map { String(format: "%.0f", $0) } ?? "—"
        return "\(input) / \(maximum) W"
    }

    static func read() -> PowerReading? {
        let battery = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard battery != IO_OBJECT_NULL else { return nil }
        defer { IOObjectRelease(battery) }

        guard let connected = IORegistryEntryCreateCFProperty(
            battery, "ExternalConnected" as CFString, kCFAllocatorDefault, 0
        )?.takeRetainedValue() as? Bool else { return nil }
        guard connected else {
            return PowerReading(connected: false, inputWatts: nil, batteryWatts: nil, adapter: nil)
        }

        let telemetry = IORegistryEntryCreateCFProperty(
            battery, "PowerTelemetryData" as CFString, kCFAllocatorDefault, 0
        )?.takeRetainedValue() as? [String: NSNumber]

        // Telemetry reports milliwatts. A negative battery reading indicates discharge.
        let input = telemetry?["SystemPowerIn"]?.int64Value
        let batteryPower = telemetry?["BatteryPower"]?.int64Value
        return PowerReading(
            connected: true,
            inputWatts: input.flatMap { $0 >= 0 ? Double($0) / 1_000 : nil },
            batteryWatts: batteryPower.map { Double($0) / 1_000 },
            adapter: PowerAdapter.read(from: battery)
        )
    }
}
