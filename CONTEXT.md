# AI Context & Living Specification — OneStorageUtils

> **Living Document**: This file serves as the primary context, architectural specification, and state-handoff document for AI-assisted development across sessions. Update this file on every development cycle ("spin").

---

## 🎯 Overview & Scope

- **Addon Name**: OneStorageUtils
- **Current Version**: 0.0.18
- **Suite**: Part of the **OneSuite** family (Core Storage Dependency)
- **GitHub Repository**:
  - Exists: TRUE
  - URL: https://github.com/Nuros-WoW-Forever-Addons/OneStorageUtils
  *(For any new addon, initialize with Exists: FALSE until first commit/push)*
- **Branching Policy**: All new features must be developed on a branch != `main` (e.g. `feature/<name>`)
- **Live Sync Path**: `/Applications/World of Warcraft/_forever_/Interface/AddOns/OneStorageUtils/`
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
- `FrameHelper.lua`: Reusable builders for Blizzard Metal dialog frames (`UI-DialogBox-Border`), title bars, search boxes, bag drawers, character selector dropdowns, and sub-tabs.
- `ContainerHelper.lua`: Cross-client container and inventory engine abstracting `C_Container` vs. legacy `GetContainerItemInfo`, slot iteration, item quality queries, and scrap callback hooks.
- `CharacterCache.lua`: Centralized realmless character inventory & bank snapshot engine, query provider, and enhanced alt tooltip sub-frame.

### Global State & Database Schema (`OneStorageUtilsDB`)
```lua
OneStorageUtilsDB = {
    debugMode = false,                 -- Enable debug logs
    logLevel = 2,                      -- 1: Debug, 2: Info, 3: Warn, 4: Error
    characters = {},                   -- [charName] = { name, class, className, level, race, gender, money, lastUpdate, bags, bank }
    showAltTooltip = true,             -- Show enhanced alt inventory sub-frame on GameTooltip
}
```

---

## 🔄 AI Development Cycle & Handoff Protocol

When picking up development on this addon:

1. **Orientation**: Read `CONTEXT.md` (this file) to verify current state, known issues, and active backlog items.
2. **Implementation**: Execute changes. For bounded code generation, refactoring, or review, delegate to NVIDIA Nemotron 3 Super 120B via the `nemotron` MCP server as mandated by user rules.
3. **Verification**: Verify in-game syntax and test using `/osdump`.
4. **Handoff Update**:
   - Move completed tasks from **Upcoming Backlog** to **Recent Completed Work**.
   - If user-facing features or commands changed, update `README.md` and append a new section in `CHANGELOG.md`.
   - Document newly discovered backlog items or edge cases in **Upcoming Backlog**.

---

## ✅ Recent Completed Work (Latest Spins)

### Spin 0.0.15
- **Prevent Overwriting Bank Snapshot with 0 Slots Away from Banker**:
  - `C_Container.GetContainerNumSlots` returns 0 for bank containers when away from a banker. Calling `SaveCurrentCharacterBank()` on `BANKFRAME_CLOSED` or `/reload` was overwriting valid cached bank data with `numSlots = 0`.
  - Added strict safety check in `CharacterCache:SaveCurrentCharacterBank()`: aborts immediately if `mainSlots <= 0` or `totalBankSlots <= 0`, guaranteeing cached bank data is never cleared away from a banker.
  - Added dual throttled scans (at `0.3s` and `0.8s`) during active banker visits to ensure all equipped bank bags stream completely before saving.

### Spin 0.0.14
- **Snapshot Item Field Key Mismatch (Missing Icons & Links)**:
  - Fixed property name mismatch in `SaveCurrentCharacterBank()` and `SaveCurrentCharacterBags()` where normalized `ContainerHelper:GetItemInfo()` fields (`.icon`, `.link`, `.count`) were read as `.iconFileID`, `.hyperlink`, and `.stackCount`.
  - Added robust fallback resolution: `icon = itemInfo.icon or itemInfo.iconFileID` (with `C_Item.GetItemIconByID` fallback) and `link = itemInfo.link or itemInfo.hyperlink`.
- **Throttled Bank Scan Scheduling**:
  - Implemented `ScheduleBankScan()` with `C_Timer.After(0.3, ...)` to ensure bank contents are recorded after streaming completes from the server.
  - Registered modern `PLAYER_INTERACTION_MANAGER_FRAME_SHOW`/`HIDE`, `BANK_TABS_CHANGED`, and `BANKFRAME_CLOSED` events.

### Spin 0.0.18
- **Profession & Crafting Window Tooltip Integration**:
  - Expanded `CharacterCache:UpdateAltTooltip` to automatically activate when hovering over reagents and crafted items in profession and crafting interfaces (`TradeSkillFrame`, `CraftFrame`, `ProfessionsFrame`).
  - Added dedicated hooks on `TradeSkillFrame` (`TradeSkillSkillIcon`, `TradeSkillReagent1..8`) and `CraftFrame` (`CraftIcon`, `CraftReagent1..8`) querying native `GetTradeSkillReagentItemLink`, `GetTradeSkillItemLink`, and `GetCraftReagentItemLink`.
  - Registered `TooltipDataProcessor.AddTooltipPostCall` across all recipe, reagent, and craft data types (`RecipeReagent`, `Profession`, `CraftingCost`, `Spell`), with multi-stage item resolution (`data.id`, `data.hyperlink`, and `tooltip:GetItem()`), plus `GameTooltip` `OnShow` and `hooksecurefunc` profession setter hooks.
  - Updated `OneStorageAltTooltipFrame` ("Character Inventory") to display cached Bags and Bank counts for any character that owns the item—including when only the currently logged-in character has it.

### Spin 0.0.17
- **Cursor-Aware Dynamic Sub-Frame Anchor & Anti-Overlap Engine**:
  - Sampled live mouse cursor coordinates via `GetCursorPosition()` / `UIParent:GetEffectiveScale()`.
  - Built a 2D collision detection and scoring model that evaluates candidate anchor positions (below-away, above-away, side-away) against the mouse pointer bounding box (`36x36px` with buffer).
  - Automatically flips alignment (expanding away from the mouse) or flips vertical placement (above vs below) whenever the cursor or slot button would otherwise be covered by `OneStorageAltTooltipFrame`.
  - Prevents the WoW gauntlet hand cursor from obscuring any part of the alt inventory tooltip text.

### Spin 0.0.16
- **Alt Tooltip Sub-Frame Dynamic Width & Smart Boundary Anchoring**:
  - Dynamically calculates `OneStorageAltTooltipFrame` width based on the longest text string using `GetStringWidth()` across `f.Title` and all active line strings, setting width to `max(tooltipWidth, maxTextW + 24)`.
  - Added smart screen boundary positioning: detects if host tooltip is near the right screen edge or bottom screen edge and dynamically anchors `TOPRIGHT` vs `TOPLEFT` and above vs below to prevent clipping offscreen.
  - Increased bottom padding from `24 + lineIdx*15` to `30 + lineIdx*15` (minimum 40px) so the "Total Across Characters" line is cleanly padded inside the bottom border.

### Spin 0.0.15
- **Prevent Overwriting Bank Snapshot with 0 Slots Away from Banker**:
  - Added strict safety check in `CharacterCache:SaveCurrentCharacterBank()`: aborts immediately if `mainSlots <= 0` or `totalBankSlots <= 0`, guaranteeing cached bank data can never be overwritten with 0 slots.
  - Removed bank scanning on `BANKFRAME_CLOSED` and `PLAYER_INTERACTION_MANAGER_FRAME_HIDE`.
  - Added dual throttled scans (at `0.3s` and `0.8s`) during active banker visits to ensure all equipped bank bags stream completely from the server before saving.

### Spin 0.0.14
- **Snapshot Item Field Key Mismatch (Missing Icons & Links)**:
  - Fixed property name mismatch in `SaveCurrentCharacterBank()` and `SaveCurrentCharacterBags()` where normalized `ContainerHelper:GetItemInfo()` fields (`.icon`, `.link`, `.count`) were incorrectly read as `.iconFileID`, `.hyperlink`, and `.stackCount`.
  - Added robust fallback resolution: `icon = itemInfo.icon or itemInfo.iconFileID` (with `C_Item.GetItemIconByID` fallback) and `link = itemInfo.link or itemInfo.hyperlink`.
- **Throttled Bank Scan Scheduling**:
  - Implemented `ScheduleBankScan()` with `C_Timer.After(0.3, ...)` to ensure bank contents are recorded after streaming completes from the server.
  - Registered modern `PLAYER_INTERACTION_MANAGER_FRAME_SHOW`/`HIDE`, `BANK_TABS_CHANGED`, and `BANKFRAME_CLOSED` events.

### Spin 0.0.13
- **Reagent Bank Container Snapshot Caching**:
  - Extended `CharacterCache:SaveCurrentCharacterBank()` to include `ContainerHelper.REAGENTBANK_CONTAINER` (`-3`) in `bankContainers`, capturing full Reagent Bank contents and slot counts whenever the player visits any banker NPC.

### Spin 0.0.12
- **Dropdown Missing Glyph Box & Dynamic Sizing**:
  - Replaced Unicode down-arrow `▾` (which rendered as a gray square box in WoW default fonts) with clean ASCII `|cffccccccv|r`.
  - Auto-collapses dropdown container width to `155px` when viewing self and expands to `255px` when `Return to Self` is visible.

### Spin 0.0.11
- **Protected GameTooltip Script Hooking**: Fixed `bad argument #2 to '?' (Usage: local success = self:HookScript(scriptTypeName, script [, bindingType]))` when initializing `CharacterCache.lua` on Camelot. Prioritized `TooltipDataProcessor.AddTooltipPostCall` and guarded `GameTooltip:HookScript` calls with `HasScript()` checks.

### Spin 0.0.10
- **Character First & Last Name Resolution & Display**:
  - Implemented `CharacterCache:GetPlayerFullName(unit)` to dynamically resolve characters' First and Last names on WoW Forever using `UnitPVPName`, `UnitFullName`, `UnitName`, and RP addon APIs (TRP3/MRP).
  - Persisted `charData.fullName` in `OneStorageUtilsDB.characters`.
  - Updated `FrameHelper:CreateCharacterDropdown` to render the full First and Last name on both the dropdown trigger button (`155px` width) and the character selection list items (`230px` menu width).
  - Integrated full names into `OneStorageAltTooltipFrame` and `CharacterCache:GetItemCounts()`.

### Spin 0.0.9
- **Centralized Character Snapshot Cache (`CharacterCache.lua`)**:
  - Automatically captures and persists account-wide snapshots of each character's bag inventory (0..5), bank tabs (6..12), money, level, and class without requiring realm prefixes (tailored for WoW Forever's realmless engine).
  - Event-driven throttled updates on `BAG_UPDATE_DELAYED`, `BANKFRAME_OPENED`, and `PLAYER_MONEY`.
  - Added query APIs: `GetCharacterList()`, `GetCharacter(name)`, `GetItemCounts(itemID, itemLink)`, and `DeleteCharacter(name)`.
- **Enhanced Alt Tooltip Sub-Frame (`OneStorageAltTooltipFrame`)**:
  - Standalone frame anchored to the bottom of `GameTooltip` displaying item counts across alts (broken down by bags and bank in class colors, with an account-wide total).
  - Controlled via `OneStorageUtilsDB.showAltTooltip` setting.
- **Reusable Character Dropdown Component**:
  - Added `FrameHelper:CreateCharacterDropdown(parent, namePrefix, onSelectCallback)` featuring a bottom-right character selector with a "Return to Self" button, populating a clean Blizzard Metal character list.

### Spin 0.0.8
- **Dynamic Money Coin Icon Scaling**: Added optional `iconSize` argument to `ContainerHelper:FormatMoney(copper, iconSize)`. When specified (and not 12), generates proportional inline texture strings (`|T...:size:size:2:0|t`) matching custom or enlarged font heights while preserving standard 12px defaults for backward compatibility.

### Spin 0.0.7
- Added automatic `"OneAddon"` chat tab integration:
  - Ensured standalone tab creation, docked to `GENERAL_CHAT_DOCK` with public channel isolation.
  - Routed all `Logger:Log` output, `Utils:Print`, and slash command feedback across `OneStorageBag`, `OneStorageBank`, and `OneStorageScrap` to `"OneAddon"` tab instead of General chat.
  - Deferred initial startup announcement to `PLAYER_ENTERING_WORLD` with a `C_Timer.After(0.4)` settling delay.

### Spin 0.0.6
- **Safe Item Info Resolution (`GetItemInfoSafe`)**: Added `ContainerHelper.GetItemInfoSafe` falling back cleanly between `C_Item.GetItemInfo` and `_G.GetItemInfo`. Replaced direct `GetItemInfo` calls in `GetBagTexture`, `GetBagQuality`, and `MatchesSearch`, eliminating `attempt to call a nil value` crashes during bag updates (such as training recipes or selling items) on WoW Forever Beta (Interface 16001).

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
