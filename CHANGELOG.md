# Changelog — OneStorageUtils

All notable changes to **OneStorageUtils** are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.0.18] - 2026-11-18
### Added
- **Profession & Crafting Window Tooltip Integration**:
  - Expanded `CharacterCache:UpdateAltTooltip` to automatically activate when hovering over reagents and crafted items in profession and crafting interfaces (`TradeSkillFrame`, `CraftFrame`, `ProfessionsFrame`).
  - Added dedicated hooks on `TradeSkillFrame` (`TradeSkillSkillIcon`, `TradeSkillReagent1..8`) and `CraftFrame` (`CraftIcon`, `CraftReagent1..8`) querying native `GetTradeSkillReagentItemLink`, `GetTradeSkillItemLink`, and `GetCraftReagentItemLink`.
  - Registered `TooltipDataProcessor.AddTooltipPostCall` across all recipe, reagent, and craft data types (`RecipeReagent`, `Profession`, `CraftingCost`, `Spell`), with multi-stage item resolution (`data.id`, `data.hyperlink`, and `tooltip:GetItem()`), plus `GameTooltip` `OnShow` and `hooksecurefunc` profession setter hooks.
  - Updated `OneStorageAltTooltipFrame` ("Character Inventory") to display cached Bags and Bank counts for any character that owns the item—including when only the currently logged-in character has it.

---

## [0.0.17] - 2026-11-18
### Fixed
- **Cursor-Aware Dynamic Sub-Frame Anchor & Anti-Overlap Engine**:
  - Sampled live mouse cursor coordinates via `GetCursorPosition()` / `UIParent:GetEffectiveScale()`.
  - Built a 2D collision detection and scoring model that evaluates candidate anchor positions (below-away, above-away, side-away) against the mouse pointer bounding box (`36x36px` with buffer).
  - Automatically flips alignment (expanding away from the mouse) or flips vertical placement (above vs below) whenever the cursor or slot button would otherwise be covered by `OneStorageAltTooltipFrame`.
  - Prevents the WoW gauntlet hand cursor from obscuring any part of the alt inventory tooltip text.

---

## [0.0.16] - 2026-11-18
### Fixed
- **Alt Tooltip Sub-Frame Dynamic Width & Smart Boundary Anchoring**:
  - Resolved text overrunning `OneStorageAltTooltipFrame` when character names or item counts exceeded the host tooltip width.
  - Dynamically measures `GetStringWidth()` across `f.Title` and all active character/total lines, adjusting width to `max(tooltipWidth, maxTextW + 24)`.
  - Added smart screen boundary positioning: detects if the host tooltip is near the right screen edge or bottom screen edge and dynamically anchors `TOPRIGHT` vs `TOPLEFT` and above vs below to prevent clipping offscreen.
  - Increased bottom padding from `24 + lineIdx*15` to `30 + lineIdx*15` (minimum 40px) so the "Total Across Characters" line is cleanly padded inside the bottom border.

---

## [0.0.15] - 2026-11-15
### Fixed
- **Prevent Overwriting Bank Snapshot with 0 Slots Away from Banker**:
  - Identified critical issue where `C_Container.GetContainerNumSlots` returns 0 for bank containers when the bank session is closed. Calling `SaveCurrentCharacterBank()` on `BANKFRAME_CLOSED` or `/reload` was overwriting valid cached bank data with `numSlots = 0`.
  - Added strict safety check in `CharacterCache:SaveCurrentCharacterBank()`: aborts immediately if `mainSlots <= 0` or `totalBankSlots <= 0`, guaranteeing cached bank data can never be overwritten with 0 slots.
  - Removed bank scanning on `BANKFRAME_CLOSED` and `PLAYER_INTERACTION_MANAGER_FRAME_HIDE`.
  - Added dual throttled scans (at `0.3s` and `0.8s`) during active banker visits to ensure all equipped bank bags stream completely from the server before saving.

---

## [0.0.14] - 2026-11-15
### Fixed
- **Snapshot Item Field Key Mismatch (Missing Icons & Links)**:
  - Fixed property name mismatch in `SaveCurrentCharacterBank()` and `SaveCurrentCharacterBags()` where normalized `ContainerHelper:GetItemInfo()` fields (`.icon`, `.link`, `.count`) were incorrectly read as `.iconFileID`, `.hyperlink`, and `.stackCount`, resulting in `nil` icons and `nil` hyperlinks stored in `OneStorageUtilsDB`.
  - Added robust fallback resolution: `icon = itemInfo.icon or itemInfo.iconFileID` (with `C_Item.GetItemIconByID` fallback) and `link = itemInfo.link or itemInfo.hyperlink`.
- **Throttled Bank Scan Scheduling**:
  - Implemented `ScheduleBankScan()` with `C_Timer.After(0.3, ...)` to ensure bank contents are recorded after streaming completes from the server.
  - Registered modern `PLAYER_INTERACTION_MANAGER_FRAME_SHOW`/`HIDE`, `BANK_TABS_CHANGED`, and `BANKFRAME_CLOSED` events.

---

## [0.0.13] - 2026-11-15
### Added
- **Reagent Bank Container Snapshot Caching**: Extended `CharacterCache:SaveCurrentCharacterBank()` to include `ContainerHelper.REAGENTBANK_CONTAINER` (`-3`) in `bankContainers`, capturing full Reagent Bank contents and slot counts whenever the player visits any banker NPC.

---

## [0.0.12] - 2026-11-15
### Fixed
- **Dropdown Missing Glyph Box**: Replaced Unicode down-arrow `▾` (which rendered as an empty square/box in WoW default fonts) with clean ASCII `|cffccccccv|r`.
- **Dynamic Dropdown Container Sizing**: Auto-collapses dropdown container width to `155px` when viewing the logged-in player, expanding to `255px` when `Return to Self` is visible for an alt.

---

## [0.0.11] - 2026-11-15
### Fixed
- **GameTooltip HookScript OnTooltipSetItem Error**: Fixed `bad argument #2 to '?' (Usage: local success = self:HookScript(scriptTypeName, script [, bindingType]))` on Camelot/Interface 16001. In modern WoW, `TooltipDataProcessor.AddTooltipPostCall` handles item tooltips; `GameTooltip:HookScript("OnTooltipSetItem")` is guarded by `GameTooltip:HasScript("OnTooltipSetItem")` to prevent errors when the script does not exist on `GameTooltip`.

---

## [0.0.10] - 2026-11-15
### Added
- **First & Last Name Character Display**:
  - Implemented `CharacterCache:GetPlayerFullName(unit)` to dynamically resolve full character First and Last names on WoW Forever via `UnitPVPName`, `UnitFullName`, `UnitName`, and RP addon APIs (TRP3/MRP).
  - Persisted `charData.fullName` in `OneStorageUtilsDB.characters`.
  - Updated `FrameHelper:CreateCharacterDropdown` to render characters' First and Last names on the dropdown button and inside the character selection popup menu, expanding button and menu widths to cleanly accommodate full names.
  - Updated `CharacterCache:GetItemCounts()` and `UpdateAltTooltip()` to show First and Last names in the multi-character inventory tooltip.

---

## [0.0.9] - 2026-11-15
### Added
- **Centralized Character Snapshot Cache (`CharacterCache.lua`)**:
  - Automatically captures and persists account-wide snapshots of each character's bag inventory (0..5), bank tabs (6..12), money, level, and class without requiring realm prefixes (tailored for WoW Forever's realmless engine).
  - Event-driven throttled updates on `BAG_UPDATE_DELAYED`, `BANKFRAME_OPENED`, and `PLAYER_MONEY`.
  - Added query APIs: `GetCharacterList()`, `GetCharacter(name)`, `GetItemCounts(itemID, itemLink)`, and `DeleteCharacter(name)`.
- **Enhanced Alt Tooltip Sub-Frame (`OneStorageAltTooltipFrame`)**:
  - Standalone frame anchored to the bottom of `GameTooltip` displaying item counts across alts (broken down by bags and bank in class colors, with an account-wide total).
  - Controlled via `OneStorageUtilsDB.showAltTooltip` setting.
- **Reusable Character Dropdown Component**:
  - Added `FrameHelper:CreateCharacterDropdown(parent, namePrefix, onSelectCallback)` featuring a bottom-right character selector with a "Return to Self" button, populating a clean Blizzard Metal character list.

---

## [0.0.8] - 2026-11-06
### Enhanced
- **Dynamic Money Coin Icon Scaling**: Added optional `iconSize` argument to `ContainerHelper:FormatMoney(copper, iconSize)`. When specified (and not 12), generates proportional inline texture strings (`|T...:size:size:2:0|t`) matching custom or enlarged font heights while preserving standard 12px defaults for backward compatibility.

---

## [0.0.7] - 2026-11-06
### Added
- **OneAddon Chat Tab Integration**:
  - Automatically routes all `Logger:Log` output, `Utils:Print`, safe-call stack traces, and diagnostics across `OneStorageBag`, `OneStorageBank`, and `OneStorageScrap` to the dedicated `"OneAddon"` chat tab instead of General chat.
  - Automatically creates and docks the `"OneAddon"` chat tab if missing, keeping public chat channels isolated.
- **Settled Startup Announcement**:
  - Deferred initial startup announcement to `PLAYER_ENTERING_WORLD` with a `C_Timer.After(0.4)` delay, ensuring Blizzard chat frame docking and tabs are fully settled before printing.

---

## [0.0.6] - 2026-10-17
### Fixed
- **Safe Item Info Resolution (`GetItemInfoSafe`)**: Added `ContainerHelper.GetItemInfoSafe` falling back cleanly between `C_Item.GetItemInfo` and `_G.GetItemInfo`. Replaced direct `GetItemInfo` calls in `GetBagTexture`, `GetBagQuality`, and `MatchesSearch`, eliminating `attempt to call a nil value` crashes during bag updates (such as training recipes or selling items) on WoW Forever Beta (Interface 16001).

---

## [0.0.5] - 2026-10-17
### Enhanced
- **Reagent Bag Inclusion (`NUM_TOTAL_EQUIPPED_BAG_SLOTS`)**: Updated `ContainerHelper:GetPlayerBagIDs()` to dynamically prioritize `NUM_TOTAL_EQUIPPED_BAG_SLOTS` over `NUM_BAG_SLOTS`, ensuring container 5 (Reagent Bag) is included in inventory slot scans and scrap evaluations.

---

## [0.0.4] - 2026-10-17
### Enhanced
- **ContainerHelper Scrap Callback Enhancement**: Updated `ContainerHelper:IsJunk` to pass the normalized `info` container item table as the 5th argument to `scrapCheckCallback`, enabling downstream scrap analyzers (like `OneStorageScrap`) to perform instant, zero-overhead item analysis without redundant container scans.

---

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
