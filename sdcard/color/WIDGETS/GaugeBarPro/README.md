# Gauge Bar Pro

Gauge Bar Pro (`BarPro` in the widget picker) is the linear member of the
Gauge Pro telemetry family for EdgeTX color radios.

This is the first public beta. Feedback about radio compatibility, missing
features, configuration options, layout behavior and visual improvements is
welcome.

## Features

- Responsive horizontal and vertical layouts from small zones to full screen.
- Continuous, gradient, blocks, hex, ticks, signal-steps and dual-rail faces.
- Configurable origin, direction, thickness, ends, scale marks, value and label
  placement, palettes and contrast assistance.
- Ascending or descending ranges, warning and critical thresholds, history
  markers and optional motion smoothing.
- Numeric telemetry, timers, sticks, channels, GVars, transmitter battery and
  battery-cell interpretation.

EdgeTX 2.11 exposes the stable ten-option compatibility set. EdgeTX 2.12 and
later expose the complete 42-option set.

## Installation

The official color SD-card packages install both required parts:

```text
/WIDGETS/GaugeBarPro/main.lua
/SCRIPTS/TOOLS/GaugeCore/*.lua
```

For a manual installation, copy both directories from `sdcard/color/`. The
widget cannot run if only its `main.lua` frontend is copied.

## Beta feedback and safety

When reporting a problem, include the radio model, exact EdgeTX version,
telemetry source, widget-zone size, theme, non-default options and a screenshot
or simulator log when possible.

Back up the SD card and model configuration before testing. Do not use this
beta widget as the only warning for a flight-critical condition; retain the
radio's normal alarms and telemetry failsafes.
