# DMX Smart Link — documentation

Step-by-step procedures for running a hub, and reference material on how the system is built. Each
guide is written to be followed start to finish by whoever is standing in front of the machine, not
only by whoever set it up.

## Current features

- [**Remote access from anywhere**](remote-access.md) — pair phones (app on Wi-Fi or a QR code), Admin and
  Operator roles, use the Hub away from its network, remove a phone, switch the cloud connection off, reset
  a forgotten admin password.
- [**Philips Hue and live shows**](hue-live-shows.md) — pair a Hue Bridge, then stream real-time shows to an
  entertainment area (beta).
- [**MIDI controllers**](midi-control.md) — MIDI Learn, encoders, Master Dimmer, Blackout, Return to Auto and
  the Control Surface.
- [**Scenes, saved shows and controllers**](FEATURES.md) — whole-rig capture, difference-only recall, NDI, Stream Deck and MIDI over IP.
- [**Latest release**](https://github.com/WhiteCrowSecurity/DMXSmartLink/releases/latest) — downloads, version notes and known limitations.

## Understanding the system

- [**System architecture**](ARCHITECTURE.md) — diagrams: what talks to what, how DMX reaches a
  fixture, typical deployments, ports and protocols.
- [**How it works**](HOW-IT-WORKS.md) — the same ground in prose: the signal path, the merge rule,
  where your data lives, what the hub does *not* do.

## Setting up

- [**Install**](SOP-INSTALL.md) — Raspberry Pi, Ubuntu, Windows and macOS, plus first-run setup.
- [**Activate your licence**](SOP-ACTIVATE-A-LICENCE.md) — turn the code on your receipt into a
  working hub, online or on a machine with no internet.
- [**Update the hub**](SOP-UPDATE-THE-HUB.md) — check the version, update safely, and what to do if
  an update goes wrong.

## Running a service or a show

- [**Steer a light by hand (Follow Spot)**](SOP-FOLLOW-SPOT.md) — follow a person with a moving head
  from a phone or a game controller.
- [**Control the Hub from your phone, anywhere**](remote-access.md#3-use-the-hub-remotely) — scenes,
  Visual Control, Homebridge and Home Assistant away from the venue.

## Looking after it

- [**Back up and restore**](SOP-BACKUP-AND-RESTORE.md) — save the patch, the scenes and the stage
  layout to one file; put it back after a crash or on a new machine.

---

## Quick reference

| I want to… | Go to |
| --- | --- |
| Get a hub running for the first time | [Install](SOP-INSTALL.md) |
| Pair my phone / add a phone | [Remote access](remote-access.md) |
| Reset a forgotten admin password | [Remote access § forgot](remote-access.md#forgot-the-admin-password) |
| Keep the Hub offline | [Remote access § switch off](remote-access.md#5-switch-remote-access-off-or-back-on) |
| Use Philips Hue in a fast show | [Hue live shows](hue-live-shows.md) |
| Map a fader or knob to a light | [MIDI controllers](midi-control.md) |
| Work out if this fits my existing rig | [System architecture](ARCHITECTURE.md) |
| Connect a lighting console | [System architecture § merge](ARCHITECTURE.md#3-how-dmx-actually-reaches-a-fixture) |
| Fire scenes from ProPresenter | [How it works § ways to drive it](HOW-IT-WORKS.md#ways-to-drive-it) |
| Follow someone with a moving head | [Follow Spot](SOP-FOLLOW-SPOT.md) |
| Move to a new machine | [Back up and restore](SOP-BACKUP-AND-RESTORE.md#moving-to-a-new-machine) |
| Know what the hub sends over the internet | [System architecture § dependencies](ARCHITECTURE.md#7-what-the-hub-depends-on) |

---

Something missing or wrong in a guide? Open an issue on this repository, or email
**support@dmxsmartlink.com**.
