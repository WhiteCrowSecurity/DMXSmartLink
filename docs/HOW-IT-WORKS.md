# How DMX Smart Link works

A short tour of what the hub actually is, for anyone integrating it with other gear or deciding
whether it fits their rig.

---

## What it is

One machine on your network — usually a Raspberry Pi — running a web server you reach from any
browser in the building. It patches and drives DMX fixtures over a USB interface, and it drives
Wi-Fi and Bluetooth smart lights at the same time, as if they were the same kind of thing.

That last part is the unusual bit. A Govee strip and a DMX par appear side by side on the stage view,
go into the same group, and take part in the same scene.

---

## The signal path

```
   your browser / phone / Stream Deck / a lighting console / ProPresenter
                                 |
                            the hub
                                 |
                 +---------------+---------------+
                 |                               |
          USB DMX interface              Wi-Fi / Bluetooth
                 |                               |
          DMX fixtures                    smart lights
```

Inside, everything that wants to change a light writes into a 512-channel frame per universe, and one
component merges those frames and drives the USB interface.

### The merge is per channel, not per source

If a lighting console is driving channels 1–20 and the hub is driving 200–220, both work at once.
Whichever source most recently *touched* a channel owns that channel. Sources do not blank each
other's fixtures simply by existing.

This is what lets you put DMX Smart Link alongside gear you already own rather than instead of it.

---

## Ways to drive it

| From | How |
| --- | --- |
| A browser or phone | The web UI |
| A Stream Deck | Plug it into the hub — scene buttons, no configuration |
| A lighting console or another app | **Art-Net** (UDP 6454) or **sACN** (UDP 5568) into the hub |
| ProPresenter, QLab, TouchOSC, a show controller | **OSC** on UDP 8000 — `/dmxsl/scene/recall`, `/next`, `/prev` |
| Your own script or panel | The HTTP control API |
| A game controller | Plug it in — steers a light live, see [Follow Spot](SOP-FOLLOW-SPOT.md) |

Everything arrives at the same place inside, so a scene recalled from a Stream Deck, an OSC cue and a
phone are the same action.

---

## NDI

The hub speaks NDI both ways, with the runtime built in — nothing to install.

- **Lights follow a slide.** Point it at a ProPresenter output and your chosen groups follow the
  colour of what is on screen.
- **Audio from an NDI source** feeds the audio-reactive engine like a line input.
- **The stage view publishes as an NDI source**, for a confidence monitor or as a ProPresenter layer.
- **The media player and slideshow publish over NDI** with audio.

---

## Fixtures

Over 12,000 fixtures ship built in, from the Open Fixture Library, FreeStyler and Lightkey. Patch by
picking the model and setting its address; the hub knows its channels.

Anything it does not know, you can define by hand, or import from a CSV or a GDTF file. A fixture is
just a list of `{channel, type}` pairs — `pan`, `dimmer`, `red`, `gobo`, and so on — so an unusual
light is a few minutes of work, not a dead end.

Fixtures with 16-bit pan and tilt are driven at full resolution, which matters for a tight beam at a
long throw.

---

## Your data

Everything lives in plain JSON files in the hub's data folder: the patch, the scenes, the groups, the
stage layout. You can read them, back them up, and move them to another machine.

| Platform | Where |
| --- | --- |
| Raspberry Pi / Ubuntu | the service's working directory, usually `/home/<user>/dmxsmartlink` |
| Windows | `C:\ProgramData\DMXSmartLink` |
| macOS | `~/Library/Application Support/DMXSmartLink` |

There is no cloud account and no hosted database. See
[Back up and restore](SOP-BACKUP-AND-RESTORE.md).

---

## Licensing, and what it does *not* do

Your licence is checked **entirely on your own machine**. The hub does not call home — not at
startup, not periodically, not ever. A hub on a network with no internet at all is a normal way to
run this.

Activation needs internet once, and even that has a manual path for a machine that has none. See
[Activate your licence](SOP-ACTIVATE-A-LICENCE.md).

---

## What it is not

- **Not a cloud service.** It runs on your hardware, on your network.
- **Not a replacement for a console** on a large touring rig. It is built for churches, small venues,
  studios and installs — places where the person running lights is also doing three other jobs.
- **Not dependent on our servers to keep working.** If this company vanished tomorrow, your hub would
  run exactly as it does today until its licence expires.
