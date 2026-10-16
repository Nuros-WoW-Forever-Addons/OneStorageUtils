# OneStorageUtils

**OneStorageUtils** is the shared utility engine, container abstraction layer, Blizzard Metal theming system, and diagnostic backbone for the **OneStorage** inventory suite.

Part of the **OneSuite** family of addons.

---

## 🚀 Features

- 🎒 **Universal Container Abstraction (`ContainerHelper.lua`)**:
  - Unified item slot enumeration and bag iteration abstracting differences between Vanilla 1.12, WotLK 3.3.5, and Modern WoW (1.60.1 / 11.0+).
  - Seamless handling of bag IDs (Backpack `0..4`, Bank `5..11`, Reagent Bank `-3`, Account Bank).
  - Custom Scrap check callback hook system (`SetScrapCheckCallback`) powering automatic junk detection.
- 🛡️ **Blizzard Metal Frame Theming (`FrameHelper.lua`)**:
  - Reusable builder for authentic silver metal dialog frames (`UI-DialogBox-Border`), title plates, search boxes, and sub-tabs.
  - Consistent layout dimensions and typography matching the OneSuite visual design standard.
- 📡 **Event Messaging Backbone (`EventBus.lua`)**:
  - Decoupled pub/sub messaging architecture for inter-module communication between Bag, Bank, and Scrap addons.
- 🩺 **Diagnostic Logging & Frame Inspector (`/osdump`, `/osutils`)**:
  - Safe execution wrapper with structured logging.
  - Interactive property dumper (`/osdump`) with persistent copyable dialog for instant coordinate and frame hierarchy analysis.

---

## 🛠️ Installation

Copy the `OneStorageUtils` directory into your World of Warcraft `Interface/AddOns/` directory:

```text
World of Warcraft/Interface/AddOns/OneStorageUtils/
├── OneStorageUtils.toc
├── Core.lua
├── Logger.lua
├── EventBus.lua
├── FrameHelper.lua
├── ContainerHelper.lua
├── CHANGELOG.md
├── CONTEXT.md
└── README.md
```

Then start or reload World of Warcraft (`/reload`).

---

## 💻 Slash Commands

| Command | Description |
|---|---|
| `/osdump [FrameName]` | Inspect properties and anchors of a named or hovered frame |
| `/osutils debug` | Toggle diagnostic debug logging |
| `/osutils loglevel <1-4>` | Set log severity threshold (1: Debug, 2: Info, 3: Warn, 4: Error) |

---

For detailed version history and release notes, see [CHANGELOG.md](CHANGELOG.md).
