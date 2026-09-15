# CLI — universal serial terminal

Turns the radio into a serial terminal for **any** device with a text
command-line interface over UART — flight controllers (Betaflight, INAV, …),
ESCs, GPS modules, and so on. Nothing vendor-specific is hardcoded: whatever
you type is sent to the wire, whatever arrives is printed.

The app appears in the **Apps** (Tools) menu as **CLI**.

## Setup

1. On the radio: **RADIO SETUP → Hardware → Serial ports**, set a free port
   (e.g. `AUX1`) to **LUA**.
2. On the device, the UART must have **MSP enabled and no peripheral assigned
   to it**. In the Betaflight Configurator *Ports* tab that is
   `Configuration/MSP` switched on and `Peripherals` left `Disabled`.
   Both conditions matter: a UART carrying a peripheral MSP function — most
   commonly **MSP DisplayPort** for HD goggles — has MSP switched on yet is
   owned by the OSD driver, so it only pushes a binary canvas and never
   enters the CLI. The app recognises that case and tells you.
3. Wire it **crossover**, 3.3 V logic:

   | Radio AUX | Device |
   |-----------|--------|
   | TX        | RX     |
   | RX        | TX     |
   | GND       | GND    |
   | 5V        | see below |

4. Open **Apps → CLI**.

**The 5 V pin.** The AUX connector can power the device from the radio when
*port power* is enabled (Hardware → Serial ports).

- **Powering the device from the radio:** connect the 5 V wire, enable port
  power, and make sure the device's own battery is **disconnected**. The app
  warns whenever the 5 V output is on, and prints a warning immediately if it
  turns on mid-session.
- **Device runs on its own battery:** leave the 5 V wire unconnected. Never
  feed the port pin from an external BEC.

## Using it

- **Auto baud detection** on every start: the port is probed with `#` and the
  first rate answering with readable text is locked in. A fixed rate can be
  picked from the header menu instead; it is then probed at that rate only,
  so a session still starts by itself when the device appears.
- Until a session exists the output area shows the wiring guide with the live
  5 V power state — or, if the port answers with something that isn't text, a
  diagnosis of what it is actually speaking.
- **Enter** on the keyboard sends the typed command; the **checkmark** just
  closes the keyboard keeping the draft. The **Enter** button next to the
  input is a second send path (and the one used on non-touch radios).
- **Scrollback** (200 lines): swipe the output area, or use **PAGE↑ / PAGE↓**.
  The view sticks to the newest output and releases once you scroll away.
- **Disconnect watchdog**: a transmit with no reply within a second prints
  `! disconnected` and keeps the log on screen. The header button becomes
  `Start new session`.
- **`CMD`** — saved commands: each entry is the command plus a free-text
  description, expandable in place, confirm-to-send.
- **`FILE`** — save the log to a file, or replay a command file into the CLI
  (one line per 100 ms), in the spirit of Betaflight's Save/Load to file.
- **`X`** or RTN exits; long-press RTN force-quits.

### Why `#` as the probe

`#` switches every MSP-family port (Betaflight, INAV, EmuFlight, Cleanflight…)
from MSP into CLI mode, so on the most common target it finds the baud rate
*and* opens the session in one step. For consoles that are already interactive
a line starting with `#` is just a comment — a no-op that still echoes a
prompt, which is exactly the readable reply the detector needs. Binary
protocols ignore stray bytes, so the sweep reports "no reply" rather than
guessing. On an MSP port a successful detection means the FC is now in CLI
mode; `exit` reboots it back to MSP.

## Files

| File | Purpose |
|------|---------|
| `main.lua` | the app |
| `commands.txt` | saved commands, one per line: `command<TAB>description` |
| `files/` | saved logs, and command files to replay (`.txt`) |

## Requirements and limits

- A colour radio running EdgeTX with the Lua LVGL API.
- Some conveniences need a firmware that provides `serialGetLuaPort()`, the
  `textEdit` placeholder and keyboard Enter handling. Without them the app
  still works: generic port wording, the stock `---` placeholder in empty
  fields, and sending with the on-screen Enter button.
- Very large dumps stress the serial RX buffer: a device answering at 115200
  can push ~11 kB/s (a Betaflight `dump` is ~26 kB), and if a script cycle is
  delayed the buffer can overflow. If you see corruption on huge dumps, lower
  the baud rate on both sides.
- The disconnect watchdog assumes the device echoes or answers something
  within a second. A device with echo disabled running a silent command may
  be flagged as disconnected by mistake — any received byte revives the
  session in place.

License: GPLv2, same as EdgeTX.
