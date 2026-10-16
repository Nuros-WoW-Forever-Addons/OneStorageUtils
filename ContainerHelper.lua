--[[
    OneStorageUtils - ContainerHelper.lua
    Unified C_Container abstraction, slot counting, item quality colors,
    search text matching, currency formatting, and scrap item detection.
--]]

local Utils = _G.OneStorageUtils or select(2, ...)
local ContainerHelper = {}

-------------------------------------------------------------------------------
-- Container Constants & ID Definitions
-------------------------------------------------------------------------------

ContainerHelper.BACKPACK_CONTAINER = _G.BACKPACK_CONTAINER or 0
ContainerHelper.BANK_CONTAINER = _G.BANK_CONTAINER or -1
ContainerHelper.REAGENTBANK_CONTAINER = _G.REAGENTBANK_CONTAINER or -3

-- Standard Player Bags (0: Backpack, 1-4: Bags, 5: Reagent Bag in modern WoW)
function ContainerHelper:GetPlayerBagIDs()
    local numBags = NUM_BAG_SLOTS or 4
    local bagIDs = { 0 }
    for i = 1, numBags do
        table.insert(bagIDs, i)
    end
    return bagIDs
end

-- Standard Bank Bags (in classic: 5..10/11; in retail/forever: 6..12)
function ContainerHelper:GetBankBagIDs()
    local numEquipped = NUM_TOTAL_EQUIPPED_BAG_SLOTS or 5
    local numBankBags = NUM_BANKBAGSLOTS or 7
    local bagIDs = {}
    for i = (numEquipped + 1), (numEquipped + numBankBags) do
        table.insert(bagIDs, i)
    end
    return bagIDs
end

ContainerHelper.BAG_IDS = ContainerHelper:GetPlayerBagIDs()
ContainerHelper.BANK_BAG_IDS = ContainerHelper:GetBankBagIDs()

-------------------------------------------------------------------------------
-- Bag Inventory Slot & Equipment Helpers
-------------------------------------------------------------------------------

--- Get the player inventory slot ID for a given container bag ID
-- @param bagID number: Bag ID (0 = backpack, 1..4 = player bags, 5 = reagent bag, 5+ = bank bags)
-- @return number|nil: Inventory slot ID
function ContainerHelper:GetBagInventoryID(bagID)
    if not bagID or bagID == 0 then return nil end
    
    -- 1. Modern C_Container API
    if C_Container and C_Container.ContainerIDToInventoryID then
        local ok, invID = pcall(C_Container.ContainerIDToInventoryID, bagID)
        if ok and invID and invID > 0 then
            return invID
        end
    end
    
    -- 2. Legacy global function
    if _G.ContainerIDToInventoryID then
        local ok, invID = pcall(_G.ContainerIDToInventoryID, bagID)
        if ok and invID and invID > 0 then
            return invID
        end
    end
    
    -- 3. Player Equipped Bags (1 .. 4, or 5 if Reagent Bag)
    local numPlayerBags = NUM_BAG_SLOTS or 4
    if bagID >= 1 and bagID <= numPlayerBags then
        if GetInventorySlotInfo then
            local invID = GetInventorySlotInfo("Bag" .. (bagID - 1) .. "Slot")
                or GetInventorySlotInfo("CharacterBag" .. (bagID - 1) .. "Slot")
            if invID and invID > 0 then
                return invID
            end
        end
        -- Canonical mathematical fallback for player bags: bag 1 = 20, bag 2 = 21, bag 3 = 22, bag 4 = 23
        return 19 + bagID
    end
    
    -- Modern Reagent Bag (bag 5)
    if bagID == 5 then
        if GetInventorySlotInfo then
            local invID = GetInventorySlotInfo("CharacterReagentBag0Slot")
            if invID and invID > 0 then
                return invID
            end
        end
        return 24
    end
    
    -- 4. Bank Bags
    local numEquipped = NUM_TOTAL_EQUIPPED_BAG_SLOTS or 5
    local buttonIndex = bagID - numEquipped
    if BankButtonIDToInvSlotID and buttonIndex > 0 then
        local ok, invID = pcall(BankButtonIDToInvSlotID, buttonIndex, true)
        if ok and invID and invID > 0 then
            return invID
        end
        -- Fallback attempt without boolean if needed by specific client variant
        local ok2, invID2 = pcall(BankButtonIDToInvSlotID, buttonIndex)
        if ok2 and invID2 and invID2 > 0 then
            return invID2
        end
    end
    
    if bagID > numEquipped and GetInventorySlotInfo and buttonIndex > 0 then
        local invID = GetInventorySlotInfo("BankBagSlot" .. buttonIndex)
            or GetInventorySlotInfo("Bag" .. (bagID - 1) .. "Slot")
        if invID and invID > 0 then
            return invID
        end
    end
    
    if buttonIndex > 0 then
        return 67 + buttonIndex
    end
    
    return nil
end

--- Get the icon texture for an equipped bag container
-- @param bagID number: Bag ID (0 = backpack, 1..4 = player bags, 5+ = reagent/bank bags)
-- @return string|number|nil: Texture path or fileID
function ContainerHelper:GetBagTexture(bagID)
    if bagID == nil then return nil end
    if bagID == 0 then
        return "Interface\\Buttons\\Button-Backpack-Up"
    end
    
    local invID = self:GetBagInventoryID(bagID)
    if not invID then return nil end
    
    if GetInventoryItemTexture then
        local tex = GetInventoryItemTexture("player", invID)
        if tex then return tex end
    end
    
    if GetInventoryItemLink then
        local link = GetInventoryItemLink("player", invID)
        if link then
            if GetItemIcon then
                local tex = GetItemIcon(link)
                if tex then return tex end
            end
            local _, _, _, _, _, _, _, _, _, itemTexture = GetItemInfo(link)
            if itemTexture then return itemTexture end
        end
    end
    
    return nil
end

--- Get the quality (rarity) for an equipped bag container
-- @param bagID number: Bag ID
-- @return number|nil: Quality index (0-8)
function ContainerHelper:GetBagQuality(bagID)
    if not bagID or bagID == 0 then return nil end
    
    local invID = self:GetBagInventoryID(bagID)
    if not invID then return nil end
    
    if GetInventoryItemQuality then
        local q = GetInventoryItemQuality("player", invID)
        if q then return q end
    end
    
    if GetInventoryItemLink then
        local link = GetInventoryItemLink("player", invID)
        if link then
            local _, _, quality = GetItemInfo(link)
            if quality then return quality end
        end
    end
    
    return nil
end

--- Get the hyperlink for an equipped bag container
-- @param bagID number: Bag ID
-- @return string|nil: Item link
function ContainerHelper:GetBagItemLink(bagID)
    if not bagID or bagID == 0 then return nil end
    local invID = self:GetBagInventoryID(bagID)
    if not invID then return nil end
    if GetInventoryItemLink then
        return GetInventoryItemLink("player", invID)
    end
    return nil
end

-------------------------------------------------------------------------------
-- C_Container API Abstraction & Fallbacks
-------------------------------------------------------------------------------

--- Get total slot count for a bag container
-- @param bagID number: Bag ID
-- @return number: Number of slots
function ContainerHelper:GetNumSlots(bagID)
    if not bagID then return 0 end
    
    if C_Container and C_Container.GetContainerNumSlots then
        local ok, count = pcall(C_Container.GetContainerNumSlots, bagID)
        if ok and count and count > 0 then return count end
    end
    if GetContainerNumSlots then
        local ok, count = pcall(GetContainerNumSlots, bagID)
        if ok and count and count > 0 then return count end
    end
    
    return 0
end

--- Get item information for a specific bag slot
-- @param bagID number: Bag ID
-- @param slotID number: Slot ID (1-indexed)
-- @return table|nil: Normalized item info table
function ContainerHelper:GetItemInfo(bagID, slotID)
    if not bagID or not slotID then return nil end
    
    if C_Container and C_Container.GetContainerItemInfo then
        local ok, info = pcall(C_Container.GetContainerItemInfo, bagID, slotID)
        if ok and info then
            return {
                icon      = info.iconFileID,
                count     = info.stackCount or 1,
                locked    = info.isLocked or false,
                quality   = info.quality,
                readable  = info.isReadable,
                lootable  = info.hasLoot,
                link      = info.hyperlink,
                filtered  = info.isFiltered,
                noValue   = info.hasNoValue,
                itemID    = info.itemID,
                isBound   = info.isBound,
            }
        end
    end
    
    if GetContainerItemInfo then
        local ok, t1, t2, t3, t4, t5, t6, t7, t8, t9, t10, t11 = pcall(GetContainerItemInfo, bagID, slotID)
        if ok and (t1 or t2 or t7) then
            -- Legacy returns: texture, itemCount, locked, quality, readable, lootable, itemLink, isFiltered, noValue, itemID, isBound
            return {
                icon      = t1,
                count     = t2 or 1,
                locked    = t3 or false,
                quality   = t4,
                readable  = t5,
                lootable  = t6,
                link      = t7,
                filtered  = t8,
                noValue   = t9,
                itemID    = t10,
                isBound   = t11,
            }
        end
    end
    
    -- Main bank inventory slot fallback for Classic engines
    if (bagID == -1 or bagID == self.BANK_CONTAINER) and BankButtonIDToInvSlotID then
        local invID = BankButtonIDToInvSlotID(slotID, false)
        if invID then
            local texture = GetInventoryItemTexture and GetInventoryItemTexture("player", invID)
            if texture then
                local link = GetInventoryItemLink and GetInventoryItemLink("player", invID)
                local count = (GetInventoryItemCount and GetInventoryItemCount("player", invID)) or 1
                local quality = (GetInventoryItemQuality and GetInventoryItemQuality("player", invID))
                local isLocked = (IsInventoryItemLocked and IsInventoryItemLocked(invID)) or false
                local itemID = link and tonumber(link:match("item:(%d+)"))
                return {
                    icon      = texture,
                    count     = count,
                    locked    = isLocked,
                    quality   = quality,
                    readable  = false,
                    lootable  = false,
                    link      = link,
                    filtered  = false,
                    noValue   = false,
                    itemID    = itemID,
                    isBound   = false,
                }
            end
        end
    end
    
    return nil
end

--- Get item hyperlink for a bag slot
-- @param bagID number: Bag ID
-- @param slotID number: Slot ID
-- @return string|nil: Hyperlink
function ContainerHelper:GetItemLink(bagID, slotID)
    if not bagID or not slotID then return nil end
    if C_Container and C_Container.GetContainerItemLink then
        local ok, link = pcall(C_Container.GetContainerItemLink, bagID, slotID)
        if ok and link then return link end
    end
    if GetContainerItemLink then
        local ok, link = pcall(GetContainerItemLink, bagID, slotID)
        if ok and link then return link end
    end
    if (bagID == -1 or bagID == self.BANK_CONTAINER) and BankButtonIDToInvSlotID then
        local invID = BankButtonIDToInvSlotID(slotID, false)
        if invID and GetInventoryItemLink then
            local ok, link = pcall(GetInventoryItemLink, "player", invID)
            if ok and link then return link end
        end
    end
    return nil
end

--- Get item ID for a bag slot
-- @param bagID number: Bag ID
-- @param slotID number: Slot ID
-- @return number|nil: Item ID
function ContainerHelper:GetItemID(bagID, slotID)
    if not bagID or not slotID then return nil end
    if C_Container and C_Container.GetContainerItemID then
        local ok, id = pcall(C_Container.GetContainerItemID, bagID, slotID)
        if ok and id then return id end
    end
    if GetContainerItemID then
        local ok, id = pcall(GetContainerItemID, bagID, slotID)
        if ok and id then return id end
    end
    local link = self:GetItemLink(bagID, slotID)
    if link then
        local id = link:match("item:(%d+)")
        if id then return tonumber(id) end
    end
    return nil
end

--- Get item cooldown for a bag slot
-- @param bagID number: Bag ID
-- @param slotID number: Slot ID
-- @return number startTime, number duration, number enable
function ContainerHelper:GetItemCooldown(bagID, slotID)
    if not bagID or not slotID then return 0, 0, 0 end
    if C_Container and C_Container.GetContainerItemCooldown then
        local ok, start, dur, enable = pcall(C_Container.GetContainerItemCooldown, bagID, slotID)
        if ok and start then return start, dur, enable end
    end
    if GetContainerItemCooldown then
        local ok, start, dur, enable = pcall(GetContainerItemCooldown, bagID, slotID)
        if ok and start then return start, dur, enable end
    end
    if (bagID == -1 or bagID == self.BANK_CONTAINER) and BankButtonIDToInvSlotID then
        local invID = BankButtonIDToInvSlotID(slotID, false)
        if invID and GetInventoryItemCooldown then
            local ok, start, dur, enable = pcall(GetInventoryItemCooldown, "player", invID)
            if ok and start then return start, dur, enable end
        end
    end
    return 0, 0, 0
end

--- Use/Interact with an item in a bag slot
-- @param bagID number: Bag ID
-- @param slotID number: Slot ID
function ContainerHelper:UseItem(bagID, slotID)
    if not bagID or not slotID then return end
    if InCombatLockdown and InCombatLockdown() then return end
    if C_Container and C_Container.UseContainerItem then
        pcall(C_Container.UseContainerItem, bagID, slotID)
    elseif UseContainerItem then
        pcall(UseContainerItem, bagID, slotID)
    elseif (bagID == -1 or bagID == self.BANK_CONTAINER) and BankButtonIDToInvSlotID then
        local invID = BankButtonIDToInvSlotID(slotID, false)
        if invID and UseInventoryItem then
            pcall(UseInventoryItem, invID)
        end
    end
end

--- Pickup an item onto cursor from a bag slot
-- @param bagID number: Bag ID
-- @param slotID number: Slot ID
function ContainerHelper:PickupItem(bagID, slotID)
    if not bagID or not slotID then return end
    if C_Container and C_Container.PickupContainerItem then
        pcall(C_Container.PickupContainerItem, bagID, slotID)
    elseif PickupContainerItem then
        pcall(PickupContainerItem, bagID, slotID)
    elseif (bagID == -1 or bagID == self.BANK_CONTAINER) and BankButtonIDToInvSlotID then
        local invID = BankButtonIDToInvSlotID(slotID, false)
        if invID and PickupInventoryItem then
            pcall(PickupInventoryItem, invID)
        end
    end
end

--- Split a stack of items in a bag slot
-- @param bagID number: Bag ID
-- @param slotID number: Slot ID
-- @param count number: Stack count to split
function ContainerHelper:SplitItem(bagID, slotID, count)
    if not bagID or not slotID or not count then return end
    if C_Container and C_Container.SplitContainerItem then
        pcall(C_Container.SplitContainerItem, bagID, slotID, count)
    elseif SplitContainerItem then
        pcall(SplitContainerItem, bagID, slotID, count)
    elseif (bagID == -1 or bagID == self.BANK_CONTAINER) and BankButtonIDToInvSlotID then
        local invID = BankButtonIDToInvSlotID(slotID, false)
        if invID and SplitInventoryItem then
            pcall(SplitInventoryItem, invID, count)
        end
    end
end

--- Update mouse cursor to vendor sell cursor or inspect cursor for a container slot
-- @param bagID number: Bag ID
-- @param slotID number: Slot ID
-- @param isReadable boolean|nil: True if item is readable
function ContainerHelper:ShowItemCursor(bagID, slotID, isReadable)
    if not bagID or not slotID then
        if ResetCursor then ResetCursor() end
        return
    end
    
    if MerchantFrame and MerchantFrame:IsShown() and (not MerchantFrame.selectedTab or MerchantFrame.selectedTab == 1) then
        if C_Container and C_Container.ShowContainerSellCursor then
            pcall(C_Container.ShowContainerSellCursor, bagID, slotID)
        elseif ShowContainerSellCursor then
            pcall(ShowContainerSellCursor, bagID, slotID)
        end
    elseif IsModifiedClick and IsModifiedClick("DRESSUP") and self:GetItemID(bagID, slotID) then
        if ShowInspectCursor then
            ShowInspectCursor()
        end
    elseif isReadable and ShowInspectCursor then
        ShowInspectCursor()
    else
        if ResetCursor then
            ResetCursor()
        end
    end
end

--- Reset mouse cursor back to default
function ContainerHelper:ResetItemCursor()
    if ResetCursor then
        ResetCursor()
    end
end

--- Trigger bag cleanup/sort routine
function ContainerHelper:SortBags()
    if C_Container and C_Container.SortBags then
        pcall(C_Container.SortBags)
    elseif SortBags then
        pcall(SortBags)
    end
end

--- Trigger bank bag cleanup/sort routine
function ContainerHelper:SortBankBags()
    if C_Container and C_Container.SortBankBags then
        pcall(C_Container.SortBankBags)
    elseif SortBankBags then
        pcall(SortBankBags)
    end
end

--- Trigger reagent bank cleanup/sort routine
function ContainerHelper:SortReagentBankBags()
    if C_Container and C_Container.SortReagentBankBags then
        pcall(C_Container.SortReagentBankBags)
    elseif SortReagentBankBags then
        pcall(SortReagentBankBags)
    end
end

-------------------------------------------------------------------------------
-- Slot Count & Free Capacity Calculators
-------------------------------------------------------------------------------

--- Calculate total and free slots for a list of bag IDs
-- @param bagList table: Array of bag IDs (e.g. {0, 1, 2, 3, 4})
-- @return number freeSlots, number totalSlots
function ContainerHelper:GetFreeSlotCount(bagList)
    if not bagList or type(bagList) ~= "table" then return 0, 0 end
    
    local total = 0
    local free = 0
    
    for _, bagID in ipairs(bagList) do
        local numSlots = self:GetNumSlots(bagID)
        if numSlots and numSlots > 0 then
            total = total + numSlots
            
            if bagID == self.BANK_CONTAINER or bagID == -1 then
                local bankFree = 0
                for slotID = 1, numSlots do
                    if not self:GetItemID(bagID, slotID) then
                        bankFree = bankFree + 1
                    end
                end
                free = free + bankFree
            elseif C_Container and C_Container.GetContainerNumFreeSlots then
                local ok, bagFree = pcall(C_Container.GetContainerNumFreeSlots, bagID)
                if ok and bagFree then
                    free = free + bagFree
                else
                    for slotID = 1, numSlots do
                        if not self:GetItemID(bagID, slotID) then
                            free = free + 1
                        end
                    end
                end
            elseif GetContainerNumFreeSlots then
                local ok, bagFree = pcall(GetContainerNumFreeSlots, bagID)
                if ok and bagFree then
                    free = free + bagFree
                else
                    for slotID = 1, numSlots do
                        if not self:GetItemID(bagID, slotID) then
                            free = free + 1
                        end
                    end
                end
            else
                for slotID = 1, numSlots do
                    if not self:GetItemID(bagID, slotID) then
                        free = free + 1
                    end
                end
            end
        end
    end
    
    return free, total
end

-------------------------------------------------------------------------------
-- Item Quality & Color Formatting
-------------------------------------------------------------------------------

local QUALITY_COLORS = {
    [0] = { 0.62, 0.62, 0.62, "9d9d9d" }, -- Poor (Grey)
    [1] = { 1.00, 1.00, 1.00, "ffffff" }, -- Common (White)
    [2] = { 0.12, 1.00, 0.00, "1eff00" }, -- Uncommon (Green)
    [3] = { 0.00, 0.44, 0.87, "0070dd" }, -- Rare (Blue)
    [4] = { 0.64, 0.21, 0.93, "a335ee" }, -- Epic (Purple)
    [5] = { 1.00, 0.50, 0.00, "ff8000" }, -- Legendary (Orange)
    [6] = { 0.90, 0.80, 0.50, "e6cc80" }, -- Artifact (Golden)
    [7] = { 0.00, 0.80, 1.00, "00ccff" }, -- Heirloom (Light Blue)
    [8] = { 0.00, 0.80, 1.00, "00ccff" }, -- WoW Token
}

--- Get vertex RGB and hex colors for an item quality index
-- @param quality number|nil: Item quality (0-8)
-- @return number r, number g, number b, string hex
function ContainerHelper:GetQualityColor(quality)
    if quality and GetItemQualityColor then
        local r, g, b, hex = GetItemQualityColor(quality)
        if r and g and b then
            return r, g, b, hex or "ffffff"
        end
    end
    
    local entry = quality and QUALITY_COLORS[quality]
    if entry then
        return entry[1], entry[2], entry[3], entry[4]
    end
    
    return 1.0, 1.0, 1.0, "ffffff"
end

-------------------------------------------------------------------------------
-- Search Text Matching Engine
-------------------------------------------------------------------------------

local scanTooltip = nil
local function GetScanTooltip()
    if not scanTooltip then
        scanTooltip = CreateFrame("GameTooltip", "OneStorageScanTooltip", UIParent, "GameTooltipTemplate")
        scanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    end
    return scanTooltip
end

--- Test if an item in a given bag and slot matches a search query
-- @param bagID number: Bag ID
-- @param slotID number: Slot ID
-- @param query string|nil: Search text
-- @return boolean: True if matching or query is empty
function ContainerHelper:MatchesSearch(bagID, slotID, query)
    if not query or query == "" then return true end
    
    local link = self:GetItemLink(bagID, slotID)
    if not link then return false end
    
    query = query:lower():match("^%s*(.-)%s*$")
    if query == "" then return true end
    
    -- 1. Query Item Name & Info
    local itemName, _, itemQuality, itemLevel, _, itemType, itemSubType, _, equipLoc = GetItemInfo(link)
    if itemName and itemName:lower():find(query, 1, true) then
        return true
    end
    
    -- 2. Quality keyword matches (e.g. "epic", "rare", "junk", "poor")
    if itemQuality then
        if query == "junk" or query == "poor" then
            if itemQuality == 0 then return true end
        elseif query == "common" and itemQuality == 1 then
            return true
        elseif query == "uncommon" and itemQuality == 2 then
            return true
        elseif query == "rare" and itemQuality == 3 then
            return true
        elseif query == "epic" and itemQuality == 4 then
            return true
        elseif query == "legendary" and itemQuality == 5 then
            return true
        end
    end
    
    -- 3. Type / Subtype / Equip Location match
    if itemType and itemType:lower():find(query, 1, true) then return true end
    if itemSubType and itemSubType:lower():find(query, 1, true) then return true end
    if equipLoc and _G[equipLoc] and _G[equipLoc]:lower():find(query, 1, true) then return true end
    
    -- 4. Deep Tooltip Text Scan
    local tip = GetScanTooltip()
    tip:ClearLines()
    if (bagID == -1 or bagID == self.BANK_CONTAINER) and BankButtonIDToInvSlotID then
        local invID = BankButtonIDToInvSlotID(slotID, false)
        if invID and tip.SetInventoryItem then
            tip:SetInventoryItem("player", invID)
        elseif tip.SetBagItem then
            tip:SetBagItem(bagID, slotID)
        end
    elseif tip.SetBagItem then
        tip:SetBagItem(bagID, slotID)
    end
    for i = 1, tip:NumLines() do
        local left = _G["OneStorageScanTooltipTextLeft" .. i]
        local text = left and left:GetText()
        if text and text:lower():find(query, 1, true) then
            return true
        end
    end
    
    return false
end

-------------------------------------------------------------------------------
-- Currency & Money Formatting
-------------------------------------------------------------------------------

local GOLD_ICON   = "|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:2:0|t"
local SILVER_ICON = "|TInterface\\MoneyFrame\\UI-SilverIcon:12:12:2:0|t"
local COPPER_ICON = "|TInterface\\MoneyFrame\\UI-CopperIcon:12:12:2:0|t"

--- Format a copper amount into formatted text with Blizzard coin icons
-- @param copper number: Amount in copper
-- @return string: Formatted money string
function ContainerHelper:FormatMoney(copper)
    copper = copper or 0
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local cop = copper % 100
    
    local parts = {}
    if gold > 0 then
        table.insert(parts, string.format("%d%s", gold, GOLD_ICON))
    end
    if silver > 0 or gold > 0 then
        table.insert(parts, string.format("%d%s", silver, SILVER_ICON))
    end
    table.insert(parts, string.format("%d%s", cop, COPPER_ICON))
    
    return table.concat(parts, " ")
end

-------------------------------------------------------------------------------
-- Junk / Scrap Detection Hook
-------------------------------------------------------------------------------

local scrapCheckCallback = nil

--- Register a custom scrap evaluation callback (provided by OneStorageScrap)
-- @param callback function: function(bagID, slotID, itemID, quality) returning boolean
function ContainerHelper:SetScrapCheckCallback(callback)
    scrapCheckCallback = callback
end

--- Determine whether an item in a bag slot is considered Junk / Scrap
-- @param bagID number: Bag ID
-- @param slotID number: Slot ID
-- @return boolean: True if the item is scrap
function ContainerHelper:IsJunk(bagID, slotID)
    local info = self:GetItemInfo(bagID, slotID)
    if not info or not info.itemID then return false end
    
    -- Custom override from OneStorageScrap if present
    if scrapCheckCallback and type(scrapCheckCallback) == "function" then
        local ok, isScrap = pcall(scrapCheckCallback, bagID, slotID, info.itemID, info.quality)
        if ok and isScrap ~= nil then
            return isScrap
        end
    end
    
    -- Default fallback: Quality == 0 (Poor) and sellable to vendor
    if info.quality == 0 and not info.noValue then
        return true
    end
    
    return false
end

-- Register module with Core
Utils:RegisterModule("ContainerHelper", ContainerHelper)
