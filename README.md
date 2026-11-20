# ChargeWatts

ChargeWatts shows how much power your Mac is drawing from its charger in the menu bar. Click the wattage to see the input and how much power is going into the battery. When the battery is discharging while plugged in, the menu shows the discharge rate.

ChargeWatts reads the Mac's power telemetry directly through IOKit. It updates every 10 seconds and when you open the menu. It requires neither administrator privileges nor additional apps at runtime.

## Build and run

Use an Apple silicon MacBook that exposes power telemetry in IOKit. Building requires the Xcode Command Line Tools.

```sh
./build.sh
open build/ChargeWatts.app
```
