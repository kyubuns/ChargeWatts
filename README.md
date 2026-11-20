# ChargeWatts

ChargeWatts shows charger input and available maximum power in the macOS menu bar, for example `88.6 / 94 W`. Click to see the adapter name, negotiated voltage and current, and battery charging or discharge rate. The maximum is the wattage macOS reports for the current adapter connection.

## Power use

Minimizing battery drain is the top priority. Read power data directly through IOKit and keep routine work off the battery whenever possible. During external power use, sample every 10 seconds with timer tolerance and refresh on demand when opening the menu. On battery, stop periodic sampling and use the macOS power-source notification to resume when external power is connected. If the notification source is unavailable, periodic sampling keeps the display usable. Keep subprocesses and background activity out of the monitoring path. When changing refresh behavior, check CPU use both while plugged in and on battery.

## Build and run

Use an Apple silicon MacBook that exposes power telemetry in IOKit. Building requires the Xcode Command Line Tools.

```sh
./build.sh
open build/ChargeWatts.app
```

To launch at login on macOS 13 or later, move the app to Applications and select **Launch at Login** from its menu.
