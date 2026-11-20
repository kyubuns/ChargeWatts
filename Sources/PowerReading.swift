import Foundation
import IOKit

struct PowerReading {
    let connected: Bool
    let inputWatts: Double?
    let batteryWatts: Double?

    static func read() -> PowerReading? {
        let battery = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard battery != IO_OBJECT_NULL else { return nil }
        defer { IOObjectRelease(battery) }

        guard let connected = IORegistryEntryCreateCFProperty(
            battery, "ExternalConnected" as CFString, kCFAllocatorDefault, 0
        )?.takeRetainedValue() as? Bool else { return nil }
        guard connected else {
            return PowerReading(connected: false, inputWatts: nil, batteryWatts: nil)
        }

        let telemetry = IORegistryEntryCreateCFProperty(
            battery, "PowerTelemetryData" as CFString, kCFAllocatorDefault, 0
        )?.takeRetainedValue() as? [String: NSNumber]

        // Telemetry reports milliwatts. A negative battery reading indicates discharge.
        let input = telemetry?["SystemPowerIn"]?.int64Value
        let batteryPower = telemetry?["BatteryPower"]?.int64Value
        return PowerReading(
            connected: true,
            inputWatts: input.map { max(0, Double($0) / 1_000) },
            batteryWatts: batteryPower.map { Double($0) / 1_000 }
        )
    }
}
