# DMX Smart Link — documentation

Step-by-step procedures for running a hub, and reference material on how the system is built. Each
guide is written to be followed start to finish by whoever is standing in front of the machine, not
only by whoever set it up.

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

## Looking after it

- [**Back up and restore**](SOP-BACKUP-AND-RESTORE.md) — save the patch, the scenes and the stage
  layout to one file; put it back after a crash or on a new machine.

---

## Quick reference

| I want to… | Go to |
| --- | --- |
| Get a hub running for the first time | [Install](SOP-INSTALL.md) |
| Work out if this fits my existing rig | [System architecture](ARCHITECTURE.md) |
| Connect a lighting console | [System architecture § merge](ARCHITECTURE.md#3-how-dmx-actually-reaches-a-fixture) |
| Fire scenes from ProPresenter | [How it works § ways to drive it](HOW-IT-WORKS.md#ways-to-drive-it) |
| Follow someone with a moving head | [Follow Spot](SOP-FOLLOW-SPOT.md) |
| Move to a new machine | [Back up and restore](SOP-BACKUP-AND-RESTORE.md#moving-to-a-new-machine) |
| Know what the hub sends over the internet | [System architecture § dependencies](ARCHITECTURE.md#7-what-the-hub-depends-on) |

---

Something missing or wrong in a guide? Open an issue on this repository, or email
**support@dmxsmartlink.com**.
