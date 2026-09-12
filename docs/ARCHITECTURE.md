# System architecture

Diagrams of how a DMX Smart Link system fits together, what talks to what, and the ways it is
typically deployed. For integrators, AV consultants, and anyone deciding whether it drops into an
existing rig.

---

## 1. The system at a glance

```mermaid
graph TB
    subgraph operators["People"]
        PHONE["Phone / tablet<br/>web UI"]
        DESK["Laptop / kiosk<br/>web UI"]
        DECK["Stream Deck"]
        PAD["Game controller"]
    end

    subgraph external["Other systems on the network"]
        CONSOLE["Lighting console<br/>Art-Net / sACN"]
        PP["ProPresenter<br/>OSC + NDI"]
        SHOW["Show controller<br/>OSC"]
        HA["Home Assistant<br/>/ HomeKit"]
    end

    HUB["<b>DMX Smart Link hub</b><br/>Raspberry Pi, Windows,<br/>macOS or Ubuntu"]

    subgraph lights["Lights"]
        DMX["DMX fixtures<br/>movers, pars, washes"]
        SMART["Smart lights<br/>Wi-Fi / Bluetooth"]
    end

    PHONE --> HUB
    DESK --> HUB
    DECK --> HUB
    PAD --> HUB
    CONSOLE --> HUB
    PP --> HUB
    SHOW --> HUB
    HA <--> HUB

    HUB -->|USB - DMX512| DMX
    HUB -->|Wi-Fi / BLE| SMART
    HUB -.->|NDI out| PP

    classDef hub fill:#5b4bb7,stroke:#2f2a63,color:#fff,stroke-width:2px
    class HUB hub
```

The hub is one machine on your local network. Everything else reaches it over that network, or
plugs into it.

---

## 2. Inside the hub

```mermaid
graph LR
    subgraph proc["The hub machine"]
        WEB["<b>Web + API</b><br/>pages, scenes,<br/>groups, patch"]
        DATA[("Data files<br/>fixtures, scenes,<br/>groups, config")]

        subgraph workers["Worker processes"]
            ARTNET["Art-Net<br/>merge + USB out"]
            SACN["sACN in"]
            OSCW["OSC in"]
            DECKW["Stream Deck"]
            NDIW["NDI in / out"]
        end
    end

    IN1["Console<br/>Art-Net"] --> ARTNET
    IN2["Console<br/>sACN"] --> SACN
    IN3["ProPresenter<br/>OSC"] --> OSCW
    IN4["Stream Deck<br/>USB"] --> DECKW
    IN5["NDI sources"] --> NDIW

    WEB <--> DATA
    WEB -->|"Art-Net to<br/>127.0.0.1:6454"| ARTNET
    SACN --> ARTNET
    OSCW --> WEB
    DECKW --> WEB
    NDIW --> WEB
    ARTNET -->|USB serial| OUT["DMX fixtures"]
    WEB -->|Wi-Fi / BLE| OUT2["Smart lights"]

    classDef w fill:#2e3a4d,stroke:#5b6b85,color:#fff
    classDef store fill:#3d3320,stroke:#7a6531,color:#fff
    class ARTNET,SACN,OSCW,DECKW,NDIW w
    class DATA store
```

Each worker is a **separate process**. A hung Stream Deck or a crash in a native library cannot take
the web interface down with it, and they restart on their own.

There is no database and no cloud account. State is plain JSON files on the hub's disk.

---

## 3. How DMX actually reaches a fixture

```mermaid
sequenceDiagram
    participant U as Operator
    participant W as Web + API
    participant B as Universe buffer<br/>(512 channels)
    participant M as Art-Net merge
    participant F as Fixture

    U->>W: Recall a scene / move a fader
    W->>B: Write the channels this action owns
    W->>M: Send the universe (Art-Net, localhost)
    Note over M: Merge with every other source,<br/>per channel
    M->>F: One DMX512 frame out the USB port
    Note over M,F: ~40 frames a second,<br/>only when something changed
```

### The merge rule

```mermaid
graph TB
    S1["Console<br/>touches ch 1-20"] --> MERGE
    S2["DMX Smart Link<br/>touches ch 200-220"] --> MERGE
    S3["Another app<br/>touches ch 50-60"] --> MERGE
    MERGE{"Per-channel merge<br/><b>most recent source<br/>wins that channel</b>"} --> OUT["Merged 512-channel frame"]

    classDef m fill:#1f4d3d,stroke:#3f8a6d,color:#fff
    class MERGE m
```

Sources do **not** blank each other's fixtures just by existing. This is what lets the hub sit
alongside equipment you already own rather than replacing it.

---

## 4. Typical deployments

### A church

```mermaid
graph TB
    subgraph booth["Sound booth"]
        PI["DMX Smart Link<br/>Raspberry Pi 5"]
        SD["Stream Deck<br/>scene buttons"]
        KIOSK["Touchscreen<br/>kiosk mode"]
    end
    subgraph stage["Stage"]
        PARS["Wash pars"]
        MOVER["Moving head"]
        STRIP["Govee strips<br/>Wi-Fi"]
    end
    PPC["ProPresenter<br/>on the media PC"]
    VOL["Volunteer's phone"]

    SD --> PI
    KIOSK --> PI
    VOL -->|wifi| PI
    PPC -->|OSC cue + NDI| PI
    PI -->|DMX line| PARS
    PI --> MOVER
    PI -->|wifi| STRIP

    classDef hub fill:#5b4bb7,stroke:#2f2a63,color:#fff,stroke-width:2px
    class PI hub
```

Scenes on Stream Deck buttons for the volunteer; ProPresenter fires the scene change on a slide; a
phone steers the moving head as a follow spot during the sermon.

### A small venue or studio

```mermaid
graph LR
    DESK2["Lighting console"] -->|Art-Net| HUB2["DMX Smart Link"]
    HUB2 -->|"merged DMX"| RIG["House rig"]
    HUB2 -->|wifi| AMBIENT["Ambient / house<br/>smart lights"]
    LAPTOP["Operator laptop"] --> HUB2

    classDef hub fill:#5b4bb7,stroke:#2f2a63,color:#fff,stroke-width:2px
    class HUB2 hub
```

The console keeps doing what it does well. The hub adds the smart lights it cannot address, and
merges both onto the one DMX line.

### An install with no operator

```mermaid
graph LR
    SCHED["Scheduled scenes<br/>+ AI Show"] --> HUB3["DMX Smart Link"]
    HA2["Home Assistant"] <-->|entities| HUB3
    HUB3 --> LIGHTS["House lighting"]

    classDef hub fill:#5b4bb7,stroke:#2f2a63,color:#fff,stroke-width:2px
    class HUB3 hub
```

---

## 5. Which control path to choose

```mermaid
graph TD
    Q1{"What is<br/>driving it?"}
    Q1 -->|A person, live| Q2{"Doing what?"}
    Q1 -->|Another system| Q3{"What can it speak?"}

    Q2 -->|"Recalling scenes"| A1["Stream Deck<br/>or the web UI"]
    Q2 -->|"Following a person<br/>with a beam"| A2["Follow Spot page<br/>or a game controller"]
    Q2 -->|"Building a look"| A3["Visual Control<br/>in a browser"]

    Q3 -->|"Art-Net / sACN"| B1["Send it to the hub -<br/>it merges per channel"]
    Q3 -->|"OSC"| B2["UDP 8000<br/>/dmxsl/scene/recall"]
    Q3 -->|"HTTP"| B3["The control API"]
    Q3 -->|"NDI video"| B4["Lights follow the picture"]
    Q3 -->|"Nothing useful"| B5["Home Assistant<br/>as the bridge"]
```

---

## 6. Ports and protocols

| Direction | Protocol | Port | Used by |
| --- | --- | --- | --- |
| In | HTTPS | 5000 | The web UI and the control API |
| In | Art-Net | UDP 6454 | Consoles, other lighting software |
| In | sACN (E1.31) | UDP 5568 | Consoles, other lighting software |
| In | OSC | UDP 8000 | ProPresenter, QLab, TouchOSC, show controllers |
| In / out | NDI | discovery + dynamic | ProPresenter, OBS, confidence monitors |
| Out | DMX512 | USB serial | The lighting rig |
| Out | Wi-Fi / BLE | — | Smart lights |

All of it is local network. The hub does not require outbound internet to run.

---

## 7. What the hub depends on

```mermaid
graph TB
    HUB4["DMX Smart Link hub"]
    HUB4 --> D1["Your local network"]
    HUB4 --> D2["A USB DMX interface<br/>(only for DMX fixtures)"]
    HUB4 -.->|"activation, updates,<br/>and a licence check-in<br/>- none of them required"| D3["The internet"]

    classDef opt stroke-dasharray: 5 5
    class D3 opt
    classDef hub fill:#5b4bb7,stroke:#2f2a63,color:#fff,stroke-width:2px
    class HUB4 hub
```

The dashed line is the point. Your licence is verified **on your own machine**: the key decides, it
is checked locally, and a hub with no internet runs indefinitely. That is a supported way to use it,
not a workaround.

With internet, the hub also checks in with the licence server every couple of days — that is how a
key used somewhere it should not be is noticed. The check-in is not a gate: if it cannot be made, the
hub keeps running on its valid key, and only an explicit rejection stops it.

---

## See also

- [How it works](HOW-IT-WORKS.md) — the same ground in prose
- [Install](SOP-INSTALL.md) — getting a hub running
- [Follow Spot](SOP-FOLLOW-SPOT.md) — steering a light by hand
- [Back up and restore](SOP-BACKUP-AND-RESTORE.md)
