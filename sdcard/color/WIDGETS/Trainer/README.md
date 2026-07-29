# Trainer widget

The Trainer widget shows the instructor radio's trainer-link state and whether
student control is requested.

It distinguishes between a link that has never connected and one that was
lost after connecting. Enabled model special functions using the **Trainer**
action are discovered automatically, so the widget does not need a duplicate
control-switch setting.

The widget supports top-bar, compact, medium, and large color-screen zones. It
uses EdgeTX's built-in trainer glyph and drawing primitives, with no bitmap
assets.

## States

- **Waiting**: a trainer link has not connected.
- **Connected**: the link is ready and the instructor has control.
- **Student control**: the link is connected and a Trainer special function is active.
- **Link lost**: a previously connected trainer link disconnected.
- **No link**: student control is requested without a valid trainer link.

Requires EdgeTX 2.9 or later for `getTrainerStatus()`.
