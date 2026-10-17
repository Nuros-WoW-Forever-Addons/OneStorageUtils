# AI Context & Living Specification — OneStorageUtils

> **Living Document**: This file serves as the primary context, architectural specification, and state-handoff document for AI-assisted development across sessions. Update this file on every development cycle ("spin").

---

## 🎯 Overview & Scope

- **Addon Name**: OneStorageUtils
- **Current Version**: 0.0.5
- **Suite**: Part of the **OneSuite** family (Core Storage Dependency)
- **GitHub Repository**:
  - Exists: TRUE
  - URL: https://github.com/Nuros-WoW-Forever-Addons/OneStorageUtils
  *(For any new addon, initialize with Exists: FALSE until first commit/push)*
- **Branching Policy**: All new features must be developed on a branch != `main` (e.g. `feature/<name>`)
- **Live Sync Path**: `/Applications/World of Warcraft/_classic_beta_/Interface/AddOns/OneStorageUtils/`
- **Rollback Target**: Last working `main` branch commit
- **Release Package**: `.github/workflows/package.yml` generates `OneStorageUtils-latest.zip` on push to `main`
- **Target WoW Runtimes**: WoW Forever Beta (v1.60.1 / Interface 16001)
- **Primary Goal**: Provide a shared utility layer, universal container abstraction, Blizzard Metal styling generator, and event messaging backbone powering `OneStorageBag`, `OneStorageBank`, and `OneStorageScrap`.

---

## 🏗️ Architecture & Component Map

### File Structure
- `OneStorageUtils.toc`: Manifest, load order, SavedVariables declaration (`OneStorageUtilsDB`), optional dependency on `OneSwatter`.
- `Core.lua`: Global namespace export (`_G.OneStorageUtils`), module registry (`RegisterModule`), frame property dumper, persistent copy dialog UI, and `/osdump` / `/osutils` slash commands.
- `Logger.lua`: Safe execution dispatcher, structured severity logging, and automatic listener bridge to `OneSwatter`.
- `EventBus.lua`: Pub/Sub event dispatcher (`Register`, `Unregister`, `Fire`) for cross-addon inventory event messaging.
- `FrameHelper.lua`: Reusable builders for Blizzard Metal dialog frames (`UI-DialogBox-Border`), title bars, search boxes, bag drawers, and sub-tabs.
- `ContainerHelper.lua`: Cross-client container and inventory engine abstracting `C_Container` vs. legacy `GetContainerItemInfo`, slot iteration, item quality queries, and scrap callback hooks.

### Global State & Database Schema (`OneStorageUtilsDB`)
```lua
OneStorageUtilsDB = {
    debugMode = false,                 -- Enable debug logs
    logLevel = 2,                      -- 1: Debug, 2: Info, 3: Warn, 4: Error
}
```

---

## 🔄 AI Development Cycle & Handoff Protocol

When picking up development on this addon:

1. **Orientation**: Read `CONTEXT.md` (this file) to verify current state, known issues, and active backlog items.
2. **Implementation**: Execute changes. For code refactoring or boilerplate, delegate to `qwen2.5-coder:32b` via the local `gx10_ollama` MCP server as mandated by user rules.
3. **Verification**: Verify in-game syntax and test using `/osdump`.
4. **Handoff Update**:
   - Move completed tasks from **Upcoming Backlog** to **Recent Completed Work**.
   - If user-facing features or commands changed, update `README.md` and append a new section in `CHANGELOG.md`.
   - Document newly discovered backlog items or edge cases in **Upcoming Backlog**.

---

## ✅ Recent Completed Work (Latest Spins)

### Spin 0.0.5
- **Reagent Bag Inclusion (`NUM_TOTAL_EQUIPPED_BAG_SLOTS`)**: Updated `ContainerHelper:GetPlayerBagIDs()` to dynamically prioritize `NUM_TOTAL_EQUIPPED_BAG_SLOTS` over `NUM_BAG_SLOTS`, ensuring container 5 (Reagent Bag) is included in inventory slot scans and scrap evaluations.

### Spin 0.0.4
- **ContainerHelper Scrap Callback Enhancement**: Updated `ContainerHelper:IsJunk` to pass the normalized `info` container item table as the 5th argument to `scrapCheckCallback`, enabling downstream scrap analyzers (like `OneStorageScrap`) to perform instant, zero-overhead item analysis without redundant container scans.

### Spin 0.0.3
- **Camelot Bank Tab & Container Alignment**: Aligned container indices with WoW Forever Beta (Interface 16001, Camelot engine):
  - Set `ContainerHelper.BANK_CONTAINER = CharacterBankTab_1` (6).
  - Aligned `GetBankBagIDs()` to strictly return `{ 7, 8, 9, 10, 11, 12 }` (CharacterBankTab_2..7).
  - Wired `GetBagTexture`, `GetBagQuality`, and `GetBagItemLink` to directly query container `Enum.BagIndex.Characterbanktab` (-2) at slot `bagID - 5` for bank bags.
  - Aligned `GetBagInventoryID()` to use `C_Bank.BankBagTypeAndIDToInvSlot` for bank tabs.

### Spin 0.0.2
- **Bank Bag Inventory Slot Prioritization**: Re-architected `ContainerHelper:GetBagInventoryID()` so bank bags (5..11) resolve to `BankButtonIDToInvSlotID(socketIndex, true)` (slots 68..74) before generic `C_Container` APIs, eliminating collision with Reagent or Bank Tab container indices.
- **GetBankBagIDs Alignment**: Corrected `GetBankBagIDs()` to strictly return `{ 5, 6, 7, 8, 9, 10, 11 }`.
- **TOC Runtime Target**: Aligned interface metadata to exclusive WoW Forever Beta target (`16001`).

### Spin 0.0.1
- Universal container helper bridging modern `C_Container` APIs with classic container functions.
- Blizzard Metal UI builder creating authentic dialog borders and textures.
- Pub/Sub EventBus implementation for OneStorage module events.
- Structured Logger and `/osdump` copyable diagnostic inspector.

---

## 📋 Living Roadmap & Upcoming Backlog (Next Spins)

### Priority 1: High Priority (Immediate Next Spin)
- [ ] **Cross-Client Container Sort / Cleanup**: Implement native bag sorting and defragmentation algorithm for client versions lacking `C_Container.SortBags`.
- [ ] **Item Search Query Parser**: Add support for advanced search syntax (e.g. `q:epic`, `t:armor`, `lvl:>70`) in `ContainerHelper`.

### Priority 2: Medium Priority (Enhancements)
- [ ] **Category Classification Engine**: Modular item categorization table (Consumables, Trade Goods, Quest, Equipment) for optional category-grouped bag views.
- [ ] **Bag Cache Offline Viewer**: Serialization helper allowing players to inspect bank contents on alt characters.

### Priority 3: Low Priority / Exploration
- [ ] **Currencies Watcher**: Helper for tracking badge and token balances across bags and bank.

---

## 🧪 Testing & Verification Guide

- **Container Query**: Call `ContainerHelper:GetContainerNumSlots(0)` in console — confirm returns 16 (Backpack size).
- **Dump Tool**: Hover over any container button and run `/osdump` — verify modal dialog displays slot, item ID, and texture details.
- **Scrap Hook**: Register a scrap callback via `ContainerHelper:SetScrapCheckCallback(...)` and confirm it correctly intercepts junk queries.

---

## ⚠️ Technical Constraints & Engine Gotchas

- **Modern C_Container Transition**: Modern WoW and WoW Forever 1.60.1 move container functions into `C_Container`. Always check `if C_Container and C_Container.GetContainerItemID` before falling back to `_G.GetContainerItemID`.
- **Item Info Async Latency**: Item names and qualities may return `nil` if not yet cached in local memory. Always listen for `GET_ITEM_INFO_RECEIVED` to refresh pending slots.
