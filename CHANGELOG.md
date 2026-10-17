# Changelog — OneStorageUtils

All notable changes to **OneStorageUtils** are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.0.3] - 2026-10-16
### Fixed
- **Camelot Bank Tab & Container Alignment**: Aligned container indices with WoW Forever Beta (Interface 16001, Camelot engine):
  - Set `ContainerHelper.BANK_CONTAINER = CharacterBankTab_1` (6).
  - Aligned `GetBankBagIDs()` to strictly return `{ 7, 8, 9, 10, 11, 12 }` (CharacterBankTab_2..7).
  - Wired `GetBagTexture`, `GetBagQuality`, and `GetBagItemLink` to directly query container `Enum.BagIndex.Characterbanktab` (-2) at slot `bagID - 5` for bank bags.
  - Aligned `GetBagInventoryID()` to use `C_Bank.BankBagTypeAndIDToInvSlot` for bank tabs.

---

## [0.0.2] - 2026-10-16
### Fixed
- **Bank Bag Container & Inventory Mapping**: Realigned `GetBankBagIDs()` to strictly return `{ 5, 6, 7, 8, 9, 10, 11 }` for WoW Forever Beta (Interface 16001).
- **Inventory ID Prioritization**: Reordered `GetBagInventoryID()` to prioritize canonical player equipped bags (1..4 -> 20..23) and bank bags (5..11 -> 68..74 via `BankButtonIDToInvSlotID`) before generic `C_Container` lookups, preventing bank bags from misidentifying as reagent or tab containers.
- **Strict Target Alignment**: Cleaned multi-client Interface tags in TOC to strictly target Interface 16001.

---

## [0.0.1] - 2026-10-10
### Added
- **Global Module Framework**: Global namespace export `_G.OneStorageUtils` and modular sub-library registry.
- **Universal Container Abstraction (`ContainerHelper`)**: Cross-client inventory queries, safe slot extraction, and scrap callback hooks.
- **Blizzard Metal Styling Engine (`FrameHelper`)**: Standardized silver dialog frames, search headers, and tab builders.
- **Event Messaging Backbone (`EventBus`)**: Decoupled pub/sub messaging system.
- **Diagnostics & Frame Dumper**: Integrated `/osdump` and `/osutils` commands with copyable popup dialog.
