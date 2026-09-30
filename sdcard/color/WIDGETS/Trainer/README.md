# Trainer widget

The Trainer widget shows the instructor radio's trainer-link state and whether
student control is requested.

It is intended for the instructor (master) radio. The widget cannot read the
model's trainer mode, so it only reports whether valid trainer input is being
received. On a student (slave) radio, or with the trainer mode set to **OFF**,
no trainer input is received and the widget will show **Waiting**.

It distinguishes between a link that has never connected and one that was
lost after connecting. Enabled model special functions using the **Trainer**
action are discovered automatically, so the widget does not need a duplicate
control-switch setting.

The widget supports top-bar, compact, medium, and large color-screen zones. It
uses EdgeTX's built-in trainer glyph and drawing primitives, with no bitmap
assets.

## States

- **Waiting**: no trainer input has been received yet (also shown when the
  radio is in slave mode or the trainer mode is OFF).
- **Connected**: the link is ready and the instructor has control.
- **Student control**: the link is connected and a Trainer special function is active.
- **Link lost**: a previously connected trainer link disconnected.
- **No link**: student control is requested without a valid trainer link.

Requires EdgeTX 2.9 or later for `getTrainerStatus()`.
