# Recovery QR

Recovery QR is an EdgeTX color-screen widget that turns the model's latest
valid GPS telemetry position into a QR code. Scanning the code opens that
position in Google Maps.

The widget keeps the last position visible when telemetry is lost and restores
it after the radio restarts. Positions are stored separately for each model.

## Requirements

- EdgeTX 3.0 or later with the Lua LVGL API
- A color-screen radio
- A configured GPS telemetry sensor

## Setup

1. Add **Recovery QR** to a widget zone.
2. Open the widget settings.
3. Select the model's GPS telemetry source.
4. Double-tap the widget to display the large, scannable QR code.

## States

- **LIVE GPS**: valid coordinates are currently arriving.
- **LAST KNOWN**: telemetry is unavailable and the last received position is
  displayed.
- **WAITING FOR GPS**: no valid position has been received or restored.

The first valid position is saved immediately. While telemetry remains live,
the widget checkpoints at most once every 15 seconds. The newest position is
also saved immediately when telemetry is lost. This limits SD-card writes while
preserving the most useful recovery coordinate.

Saved positions use model-specific files in `/WIDGETS/RecoveryQR/`. A
full-screen confirmation button can clear a stored position when telemetry is
not live.

## Notes

- The QR code contains a URL in the form
  `https://maps.google.com/?q=latitude,longitude`.
- The widget itself does not make a network request or transmit coordinates.
- A receiver that publishes `0,0` before obtaining a fix is treated as not
  having a valid position.
- The last telemetry coordinate is a recovery aid, not a guarantee of the
  aircraft's final resting position.

This widget implements the color-radio use case described in
[EdgeTX issue #4614](https://github.com/EdgeTX/edgetx/issues/4614).

## Development check

The repository includes a host-side test covering GPS validation, state
transitions, persistence recovery, model isolation, LVGL layout construction,
and all supported color-screen dimensions:

```sh
lua5.3 tests/recovery_qr_widget_test.lua
```
