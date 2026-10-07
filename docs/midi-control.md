# MIDI controllers: Learn, encoders, Blackout and the Control Surface

**Who this is for:** anyone who wants physical faders, knobs and pads (a Launch Control XL3, FLkey,
X-Touch or another class-compliant USB MIDI controller) driving scenes, shows, fixtures and parameters.

---

## 1. Connect the controller

| Where the Hub runs | How to connect |
|---|---|
| Raspberry Pi or Ubuntu | Plug the controller into the Hub. |
| Windows or Mac | Plug the controller into that computer, then choose it in **Settings → MIDI → MIDI Input Device**. |
| Controller on a *different* computer | Use the MIDI Connector under **Settings → MIDI → Remote / Network MIDI**. |

On Windows and Mac the page shows **Connected** with the controller's name. **Rescan** finds a newly
plugged controller. The Hub remembers your choice even if the controller is unplugged or comes back under
a slightly different name. Nothing is opened until you choose a controller, so an existing MIDI Connector
setup keeps working as before.

The Hub reads one controller at a time. You can set everything up (choose the controller, watch live
activity, Learn and save mappings) without a DMX interface attached; plug the interface in later and the
mappings work as they are.

---

## 2. Learn a control

1. Open **Settings → MIDI → Learned controls**.
2. Select **Learn** and move a fader, knob or pad on the controller.
3. Choose what it drives:
   - **a fixture, a fixture group or all fixtures**, and a **parameter**: Pan, Tilt, Strobe, Dimmer or
     any channel the fixture has (for example "1 dimmer" or "3 green");
   - the **Master Dimmer**, **Blackout** or **Return to Auto**;
   - a **scene or saved show**, **next / previous scene**, or **start / stop the AI Light Show**;
   - a raw DMX address, for unusual fixtures.
4. Choose a mode and range, give it a label, and save.

| Mode | What happens |
|---|---|
| **Fader** | The light follows the control from **Min** at the bottom to **Max** at the top. Set Min above Max to run it backwards. |
| **Toggle** | Each press switches between Min and Max: one press on, the next press off. |
| **Momentary** | Max while you hold the pad, Min when you let go. |

Channels are chosen by their place in the fixture, so if you later give a fixture a new DMX address, its
learned controls follow it. Each mapping can be edited, switched off and on, or re-learned. Mappings from
earlier betas keep working.

**Fixture groups:** name a set of fixtures (for example *Wash pars* or *Movers*) and one control drives
them all.

---

## 3. Encoders that need less turning

Each learned fader or encoder has three more settings:

- **Response:** Normal, 2x, 3x, 4x or **Accelerated**. 4x needs a quarter of the turning to cross the
  range. Accelerated moves in fine steps when you turn slowly and covers ground when you spin. Turning to
  either end always reaches Min or Max, and the value never wraps around.
- **Input:** **Absolute** (most controllers) or one of three **relative** encoder formats. If turning a
  knob one way makes the value flip between two numbers in the activity monitor, the knob is relative.
- **Smoothing:** Off, Low, Medium or High. The knob chooses where the light should go; smoothing decides
  how quickly it travels there, so a fast turn does not make pan or tilt jump.

Pan and tilt use a fixture's fine channels when it has them, so precise aiming is not lost. A fixture's
own pan/tilt speed channel stays under your control as a separate mapping.

---

## 4. Master Dimmer, Blackout and manual override

- **Master Dimmer:** a fader scales the brightness of everything without changing any scene or saved
  level.
- **Blackout:** darkens the rig over every scene, Visual Control, the AI Light Show and MIDI. Moving heads
  stay where they are pointed. Press it again to bring the rig back.
- **Manual override:** a control you move takes just that parameter from the AI Light Show, so the two
  never fight. **Return to Auto** (a button you can map, or on the Settings page) hands it back.
  Recalling a scene does the same.

---

## 5. See what is in control

The **Dashboard** has a **Lighting control** card. It shows whether the AI Light Show is running, the
active scene, Blackout and the Master Dimmer level, whether the MIDI controller and DMX output are
connected, and any parameter a MIDI control has taken over (for example *Movers → pan*). From the card you
can Blackout, **Return All to Auto**, start or stop the AI Light Show and set the Master Dimmer.

Fixtures are shown as *patched*: DMX cannot report whether a fixture is actually on, so the Hub does not
claim it.

### Control Surface (first version)

**Dashboard → Open Control Surface** shows a live picture of a Launch Control XL3. Each control lights up
when you touch it and shows its value, what it is mapped to, and whether it currently holds that parameter
(**MANUAL**) or the show does (**AUTO**). If a control lights up in the wrong place, click it and move the
real control to correct it. This first version is view-only.

---

## Stream Deck

A Stream Deck key for a saved show is a toggle: press once to start the show (a Live Video follow of an NDI
source, a Slide Show or an AI Light Show), press the same key again to stop it. The lights stay where they
are when it stops. Pressing another show's key switches to that show, and pressing any scene stops a
running show.

Stream Deck and MIDI Connector downloads for Windows and Mac are in **Settings**. See the
[feature guide](FEATURES.md#stream-deck-and-midi) for the packages.

---

## Backups

Learned MIDI mappings, fixture groups and Control Surface corrections are included in a Hub backup. The
network MIDI Connector's pairing key is not: pair the Connector again after a restore. See
[Back up and restore](SOP-BACKUP-AND-RESTORE.md).
