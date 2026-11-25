--[[
    OneStorageUtils - CharacterCache.lua
    Account-wide cross-character inventory and bank snapshot cache,
    character selector data provider, and enhanced alt tooltip sub-frame.
--]]

local Utils = _G.OneStorageUtils or select(2, ...)
local CharacterCache = Utils:RegisterModule("CharacterCache")
local ContainerHelper = Utils.ContainerHelper or _G.OneStorageUtils.ContainerHelper
local FrameHelper = Utils.FrameHelper or _G.OneStorageUtils.FrameHelper

-- Event processing frame
local eventFrame = CreateFrame("Frame", "OneStorageCharacterCacheEventFrame")

-------------------------------------------------------------------------------
-- Class Color Helper
-------------------------------------------------------------------------------

local function GetClassColorHex(classFileName)
    if not classFileName then return "ffffffff" end
    if C_ClassColor and C_ClassColor.GetClassColor then
        local color = C_ClassColor.GetClassColor(classFileName)
        if color and color.GenerateHexColor then
            return color:GenerateHexColor()
        end
    end
    local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFileName]
    if c then
        return string.format("ff%02x%02x%02x", math.floor(c.r * 255), math.floor(c.g * 255), math.floor(c.b * 255))
    end
    return "ffffffff"
end

CharacterCache.GetClassColorHex = GetClassColorHex

-------------------------------------------------------------------------------
-- Full Name Helper (First & Last Name on WoW Forever)
-------------------------------------------------------------------------------

--- Returns the full First and Last name for a player or unit
-- @param unit string|nil: UnitId (defaults to "player")
-- @return string: Full name (e.g. "Saulest Nurotic", "Aisling Nuroluna")
function CharacterCache:GetPlayerFullName(unit)
    unit = unit or "player"
    
    -- 1. Total RP 3
    if _G.TRP3_API and _G.TRP3_API.register and _G.TRP3_API.register.getPlayerCompleteName then
        local ok, trpName = pcall(_G.TRP3_API.register.getPlayerCompleteName, true)
        if ok and trpName and trpName ~= "" then return trpName end
    end
    
    -- 2. MyRolePlay
    if _G.mrp and _G.mrp.GetPlayerFullName then
        local ok, mrpName = pcall(function() return _G.mrp:GetPlayerFullName() end)
        if ok and mrpName and mrpName ~= "" then return mrpName end
    end
    
    -- 3. UnitPVPName (returns "FirstName LastName" on WoW Forever)
    if UnitPVPName then
        local ok, pvpName = pcall(UnitPVPName, unit)
        if ok and pvpName and pvpName ~= "" then return pvpName end
    end
    
    -- 4. UnitFullName (returns name, realm/lastName on WoW Forever)
    if UnitFullName then
        local ok, first, last = pcall(UnitFullName, unit)
        if ok and first and first ~= "" then
            if last and last ~= "" then
                return first .. " " .. last
            end
            return first
        end
    end
    
    -- 5. UnitName fallback
    if UnitName then
        local ok, first, last = pcall(UnitName, unit)
        if ok and first and first ~= "" then
            if last and last ~= "" then
                return first .. " " .. last
            end
            return first
        end
    end
    
    return "Player"
end

-------------------------------------------------------------------------------
-- Character Snapshot Persistence
-------------------------------------------------------------------------------

--- Save current character's bag inventory snapshot
function CharacterCache:SaveCurrentCharacterBags()
    local name = UnitName("player")
    if not name or name == "" or name == "Unknown" then return end
    
    local db = _G.OneStorageUtilsDB
    if not db then return end
    db.characters = db.characters or {}
    
    local fullName = self:GetPlayerFullName("player") or name
    local _, classFileName = UnitClass("player")
    local localizedClass = UnitClass("player")
    local level = UnitLevel("player")
    local localizedRace = UnitRace("player")
    local gender = UnitSex("player")
    local money = (GetMoney and GetMoney()) or 0
    
    local charData = db.characters[name] or {}
    charData.name = name
    charData.fullName = fullName
    charData.class = classFileName or charData.class
    charData.className = localizedClass or charData.className
    charData.level = (level and level > 0 and level) or charData.level or 1
    charData.race = localizedRace or charData.race
    charData.gender = gender or charData.gender
    charData.money = money
    charData.lastUpdate = time()
    
    local bags = {}
    local ch = ContainerHelper or (Utils and Utils.ContainerHelper)
    local bagIDs = (ch and ch.GetPlayerBagIDs and ch:GetPlayerBagIDs()) or { 0, 1, 2, 3, 4, 5 }
    
    for _, bagID in ipairs(bagIDs) do
        local numSlots = (ch and ch.GetNumSlots and ch:GetNumSlots(bagID)) or 0
        local bagInfo = {
            numSlots = numSlots,
            icon = (ch and ch.GetBagTexture and ch:GetBagTexture(bagID)) or nil,
            link = (ch and ch.GetBagItemLink and ch:GetBagItemLink(bagID)) or nil,
            quality = (ch and ch.GetBagQuality and ch:GetBagQuality(bagID)) or 0,
            slots = {}
        }
        
        for slotID = 1, numSlots do
            local itemInfo = ch and ch.GetItemInfo and ch:GetItemInfo(bagID, slotID)
            if itemInfo and itemInfo.itemID then
                local icon = itemInfo.icon or itemInfo.iconFileID
                if not icon and C_Item and C_Item.GetItemIconByID then
                    icon = C_Item.GetItemIconByID(itemInfo.itemID)
                end
                local link = itemInfo.link or itemInfo.hyperlink
                local count = itemInfo.count or itemInfo.stackCount or 1
                bagInfo.slots[slotID] = {
                    id = itemInfo.itemID,
                    link = link,
                    count = count,
                    icon = icon,
                    quality = itemInfo.quality or 1,
                }
            end
        end
        bags[bagID] = bagInfo
    end
    
    charData.bags = bags
    db.characters[name] = charData
end

--- Save current character's bank inventory snapshot
function CharacterCache:SaveCurrentCharacterBank()
    local name = UnitName("player")
    if not name or name == "" or name == "Unknown" then return end
    
    local ch = ContainerHelper or (Utils and Utils.ContainerHelper)
    if not ch then return end
    
    local mainBankID = ch.BANK_CONTAINER or 6
    local mainSlots = (ch.GetNumSlots and ch:GetNumSlots(mainBankID)) or 0
    -- Critical safety guard: The client only returns bank slots while actively interacting with a banker.
    -- If mainSlots is 0, the bank is closed or inaccessible. Never overwrite cached bank data with 0 slots!
    if mainSlots <= 0 then
        return
    end
    
    local db = _G.OneStorageUtilsDB
    if not db then return end
    db.characters = db.characters or {}
    
    local charData = db.characters[name]
    if not charData then
        self:SaveCurrentCharacterBags()
        charData = db.characters[name]
    end
    if not charData then return end
    
    local bankContainers = { mainBankID }
    local tabIDs = (ch.GetBankBagIDs and ch:GetBankBagIDs()) or { 7, 8, 9, 10, 11, 12 }
    for _, tabID in ipairs(tabIDs) do
        table.insert(bankContainers, tabID)
    end
    local reagentBankID = ch.REAGENTBANK_CONTAINER or -3
    table.insert(bankContainers, reagentBankID)
    
    local totalBankSlots = 0
    local bank = {
        lastVisit = time(),
        tabs = {}
    }
    
    for _, containerID in ipairs(bankContainers) do
        local numSlots = (ch.GetNumSlots and ch:GetNumSlots(containerID)) or 0
        totalBankSlots = totalBankSlots + numSlots
        local containerInfo = {
            numSlots = numSlots,
            icon = (ch.GetBagTexture and ch:GetBagTexture(containerID)) or nil,
            link = (ch.GetBagItemLink and ch:GetBagItemLink(containerID)) or nil,
            quality = (ch.GetBagQuality and ch:GetBagQuality(containerID)) or 0,
            slots = {}
        }
        
        for slotID = 1, numSlots do
            local itemInfo = ch.GetItemInfo and ch:GetItemInfo(containerID, slotID)
            if itemInfo and itemInfo.itemID then
                local icon = itemInfo.icon or itemInfo.iconFileID
                if not icon and C_Item and C_Item.GetItemIconByID then
                    icon = C_Item.GetItemIconByID(itemInfo.itemID)
                end
                local link = itemInfo.link or itemInfo.hyperlink
                local count = itemInfo.count or itemInfo.stackCount or 1
                containerInfo.slots[slotID] = {
                    id = itemInfo.itemID,
                    link = link,
                    count = count,
                    icon = icon,
                    quality = itemInfo.quality or 1,
                }
            end
        end
        bank.tabs[containerID] = containerInfo
    end
    
    -- Only commit if we actually retrieved active bank slots from the live client!
    if totalBankSlots > 0 then
        charData.bank = bank
        db.characters[name] = charData
    end
end

-------------------------------------------------------------------------------
-- Query & Data Provider APIs
-------------------------------------------------------------------------------

--- Get sorted list of cached characters (current player first, then alphabetical)
-- @return table: Array of { name, fullName, class, className, level, money, isCurrent, lastUpdate }
function CharacterCache:GetCharacterList()
    local db = _G.OneStorageUtilsDB
    local list = {}
    local currentName = UnitName("player")
    
    if db and db.characters then
        for charName, data in pairs(db.characters) do
            local fullName = data.fullName
            if not fullName or fullName == "" then
                if charName == currentName then
                    fullName = self:GetPlayerFullName("player")
                    data.fullName = fullName
                else
                    fullName = charName
                end
            end
            table.insert(list, {
                name = charName,
                fullName = fullName,
                class = data.class or "WARRIOR",
                className = data.className or data.class or "Warrior",
                level = data.level or 1,
                money = data.money or 0,
                isCurrent = (charName == currentName),
                lastUpdate = data.lastUpdate or 0,
            })
        end
    end
    
    -- Ensure current player is present even before first save
    if currentName and currentName ~= "" and currentName ~= "Unknown" then
        local found = false
        for _, c in ipairs(list) do
            if c.name == currentName then found = true break end
        end
        if not found then
            local _, classFileName = UnitClass("player")
            local fullName = self:GetPlayerFullName("player") or currentName
            table.insert(list, {
                name = currentName,
                fullName = fullName,
                class = classFileName or "WARRIOR",
                className = UnitClass("player") or "Warrior",
                level = UnitLevel("player") or 1,
                money = (GetMoney and GetMoney()) or 0,
                isCurrent = true,
                lastUpdate = time(),
            })
        end
    end
    
    table.sort(list, function(a, b)
        if a.isCurrent and not b.isCurrent then return true end
        if b.isCurrent and not a.isCurrent then return false end
        local nameA = a.fullName or a.name
        local nameB = b.fullName or b.name
        return nameA < nameB
    end)
    
    return list
end

--- Get cached snapshot data for a specific character
-- @param charName string|nil: Name of the character (defaults to current player)
-- @return table|nil: Character snapshot data table
function CharacterCache:GetCharacter(charName)
    local target = charName or UnitName("player")
    if not target then return nil end
    local db = _G.OneStorageUtilsDB
    return db and db.characters and db.characters[target]
end

--- Delete a character from the cached database
-- @param charName string: Character name to remove
function CharacterCache:DeleteCharacter(charName)
    if not charName then return end
    local db = _G.OneStorageUtilsDB
    if db and db.characters then
        db.characters[charName] = nil
    end
end

--- Scan all characters for an item by itemID or itemLink
-- @param itemID number|nil: Item ID
-- @param itemLink string|nil: Item Hyperlink
-- @return table: { total = number, characters = array of { name, class, bags, bank, total, isCurrent } }
function CharacterCache:GetItemCounts(itemID, itemLink)
    local db = _G.OneStorageUtilsDB
    if not db or not db.characters then return { total = 0, characters = {} } end
    
    local targetID = tonumber(itemID)
    if not targetID and itemLink and type(itemLink) == "string" then
        targetID = tonumber(itemLink:match("item:(%d+)"))
    end
    if not targetID then return { total = 0, characters = {} } end
    
    local totalCount = 0
    local charList = {}
    local currentName = UnitName("player")
    
    for charName, charData in pairs(db.characters) do
        local bagCount = 0
        local bankCount = 0
        
        -- Scan bags
        if charData.bags then
            for _, bagInfo in pairs(charData.bags) do
                if bagInfo.slots then
                    for _, slotItem in pairs(bagInfo.slots) do
                        if slotItem.id == targetID then
                            bagCount = bagCount + (slotItem.count or 1)
                        end
                    end
                end
            end
        end
        
        -- Scan bank
        if charData.bank and charData.bank.tabs then
            for _, tabInfo in pairs(charData.bank.tabs) do
                if tabInfo.slots then
                    for _, slotItem in pairs(tabInfo.slots) do
                        if slotItem.id == targetID then
                            bankCount = bankCount + (slotItem.count or 1)
                        end
                    end
                end
            end
        end
        
        local charTotal = bagCount + bankCount
        if charTotal > 0 then
            totalCount = totalCount + charTotal
            table.insert(charList, {
                name = charName,
                fullName = charData.fullName or charName,
                class = charData.class,
                bags = bagCount,
                bank = bankCount,
                total = charTotal,
                isCurrent = (charName == currentName),
            })
        end
    end
    
    table.sort(charList, function(a, b)
        if a.isCurrent and not b.isCurrent then return true end
        if b.isCurrent and not a.isCurrent then return false end
        local nameA = a.fullName or a.name
        local nameB = b.fullName or b.name
        return nameA < nameB
    end)
    
    return {
        total = totalCount,
        characters = charList
    }
end

-------------------------------------------------------------------------------
-- Enhanced Alt Tooltip Sub-Frame
-------------------------------------------------------------------------------

local function CreateAltTooltipFrame()
    if _G.OneStorageAltTooltipFrame then return _G.OneStorageAltTooltipFrame end
    
    local f = CreateFrame("Frame", "OneStorageAltTooltipFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    f:SetFrameStrata("TOOLTIP")
    f:SetClampedToScreen(true)
    f:Hide()
    
    local fh = FrameHelper or (Utils and Utils.FrameHelper)
    if fh and fh.ApplyBackdrop then
        fh:ApplyBackdrop(
            f,
            "Interface\\Tooltips\\UI-Tooltip-Background",
            "Interface\\Tooltips\\UI-Tooltip-Border",
            16,
            16,
            { left = 4, right = 4, top = 4, bottom = 4 }
        )
    elseif f.SetBackdrop then
        f:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
    end
    if f.SetBackdropColor then f:SetBackdropColor(0.08, 0.08, 0.1, 0.95) end
    if f.SetBackdropBorderColor then f:SetBackdropBorderColor(0.6, 0.6, 0.6, 1.0) end
    
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -8)
    title:SetText("|cffffcc00Character Inventory|r")
    f.Title = title
    
    f.lines = {}
    f.GetLine = function(self, index)
        if not self.lines[index] then
            local fs = self:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            fs:SetJustifyH("LEFT")
            if index == 1 then
                fs:SetPoint("TOPLEFT", self.Title, "BOTTOMLEFT", 0, -4)
            else
                fs:SetPoint("TOPLEFT", self.lines[index - 1], "BOTTOMLEFT", 0, -2)
            end
            self.lines[index] = fs
        end
        return self.lines[index]
    end
    
    return f
end

--- Update the enhanced alt tooltip sub-frame for a given item
function CharacterCache:UpdateAltTooltip(itemRef)
    local db = _G.OneStorageUtilsDB
    if db and db.showAltTooltip == false then
        if _G.OneStorageAltTooltipFrame then _G.OneStorageAltTooltipFrame:Hide() end
        return
    end
    
    if not itemRef or not GameTooltip or not GameTooltip:IsShown() then
        if _G.OneStorageAltTooltipFrame then _G.OneStorageAltTooltipFrame:Hide() end
        return
    end
    
    local counts = self:GetItemCounts(itemRef, itemRef)
    if not counts or counts.total <= 0 or #counts.characters == 0 then
        if _G.OneStorageAltTooltipFrame then _G.OneStorageAltTooltipFrame:Hide() end
        return
    end
    
    local f = CreateAltTooltipFrame()
    
    local lineIdx = 0
    for _, c in ipairs(counts.characters) do
        lineIdx = lineIdx + 1
        local line = f:GetLine(lineIdx)
        local hex = GetClassColorHex(c.class)
        local locationParts = {}
        if c.bags > 0 then
            table.insert(locationParts, string.format("%d in Bags", c.bags))
        end
        if c.bank > 0 then
            table.insert(locationParts, string.format("%d in Bank", c.bank))
        end
        local locStr = table.concat(locationParts, ", ")
        local selfTag = c.isCurrent and " |cff888888(You)|r" or ""
        line:SetText(string.format("|c%s%s|r%s: %s", hex, c.fullName or c.name, selfTag, locStr))
        line:Show()
    end
    
    -- Total Line
    lineIdx = lineIdx + 1
    local totalLine = f:GetLine(lineIdx)
    totalLine:SetText(string.format("|cffffcc00Total Across Characters:|r |cffffffff%d|r", counts.total))
    totalLine:Show()
    
    -- Hide excess lines
    for i = lineIdx + 1, #f.lines do
        f.lines[i]:Hide()
    end
    
    -- Calculate required dynamic width based on the longest text line
    local maxTextW = (f.Title and f.Title:GetStringWidth()) or 140
    for i = 1, lineIdx do
        local lineW = f.lines[i] and f.lines[i]:GetStringWidth() or 0
        if lineW > maxTextW then
            maxTextW = lineW
        end
    end
    
    local tooltipWidth = (GameTooltip and GameTooltip:GetWidth()) or 160
    local targetWidth = math.max(tooltipWidth, maxTextW + 24)
    local height = 30 + (lineIdx * 15)
    
    f:ClearAllPoints()
    f:SetWidth(targetWidth)
    f:SetHeight(math.max(40, height))
    
    -- Dynamic anchor positioning based on mouse cursor and screen bounds
    local point = "TOPLEFT"
    local relativePoint = "BOTTOMLEFT"
    local xOfs = 0
    local yOfs = -2
    
    local gtLeft = GameTooltip and GameTooltip:GetLeft()
    local gtRight = GameTooltip and GameTooltip:GetRight()
    local gtTop = GameTooltip and GameTooltip:GetTop()
    local gtBottom = GameTooltip and GameTooltip:GetBottom()
    
    if gtLeft and gtRight and gtTop and gtBottom then
        local uipWidth = UIParent and UIParent:GetWidth() or 1920
        local uipHeight = UIParent and UIParent:GetHeight() or 1080
        local sMargin = 10
        
        -- Get cursor position in UI parent space
        local scale = (UIParent and UIParent:GetEffectiveScale()) or 1
        local curX, curY = GetCursorPosition()
        local mouseX = (curX and scale > 0) and (curX / scale) or (gtLeft + gtRight) / 2
        local mouseY = (curY and scale > 0) and (curY / scale) or (gtBottom - 20)
        
        -- Cursor bounding box with safety padding (WoW hand cursor ~32x32)
        local cMargin = 8
        local cLeft = mouseX - cMargin
        local cRight = mouseX + 32 + cMargin
        local cBottom = mouseY - 32 - cMargin
        local cTop = mouseY + cMargin
        
        local gtMidX = (gtLeft + gtRight) / 2
        local mouseOnRight = mouseX >= gtMidX
        
        -- Generate candidate anchor positions ordered by preference (expanding away from mouse)
        local candidates = {}
        if mouseOnRight then
            -- Mouse is on right: prefer expanding to the LEFT
            table.insert(candidates, {
                point = "TOPRIGHT", relPoint = "BOTTOMRIGHT", xOfs = 0, yOfs = -2,
                fLeft = gtRight - targetWidth, fRight = gtRight,
                fTop = gtBottom - 2, fBottom = gtBottom - 2 - height,
                isBelow = true, isAway = true
            })
            table.insert(candidates, {
                point = "BOTTOMRIGHT", relPoint = "TOPRIGHT", xOfs = 0, yOfs = 2,
                fLeft = gtRight - targetWidth, fRight = gtRight,
                fBottom = gtTop + 2, fTop = gtTop + 2 + height,
                isBelow = false, isAway = true
            })
            table.insert(candidates, {
                point = "TOPRIGHT", relPoint = "TOPLEFT", xOfs = -2, yOfs = 0,
                fRight = gtLeft - 2, fLeft = gtLeft - 2 - targetWidth,
                fTop = gtTop, fBottom = gtTop - height,
                isBelow = false, isAway = true
            })
            table.insert(candidates, {
                point = "TOPLEFT", relPoint = "BOTTOMLEFT", xOfs = 0, yOfs = -2,
                fLeft = gtLeft, fRight = gtLeft + targetWidth,
                fTop = gtBottom - 2, fBottom = gtBottom - 2 - height,
                isBelow = true, isAway = false
            })
            table.insert(candidates, {
                point = "BOTTOMLEFT", relPoint = "TOPLEFT", xOfs = 0, yOfs = 2,
                fLeft = gtLeft, fRight = gtLeft + targetWidth,
                fBottom = gtTop + 2, fTop = gtTop + 2 + height,
                isBelow = false, isAway = false
            })
        else
            -- Mouse is on left: prefer expanding to the RIGHT
            table.insert(candidates, {
                point = "TOPLEFT", relPoint = "BOTTOMLEFT", xOfs = 0, yOfs = -2,
                fLeft = gtLeft, fRight = gtLeft + targetWidth,
                fTop = gtBottom - 2, fBottom = gtBottom - 2 - height,
                isBelow = true, isAway = true
            })
            table.insert(candidates, {
                point = "BOTTOMLEFT", relPoint = "TOPLEFT", xOfs = 0, yOfs = 2,
                fLeft = gtLeft, fRight = gtLeft + targetWidth,
                fBottom = gtTop + 2, fTop = gtTop + 2 + height,
                isBelow = false, isAway = true
            })
            table.insert(candidates, {
                point = "TOPLEFT", relPoint = "TOPRIGHT", xOfs = 2, yOfs = 0,
                fLeft = gtRight + 2, fRight = gtRight + 2 + targetWidth,
                fTop = gtTop, fBottom = gtTop - height,
                isBelow = false, isAway = true
            })
            table.insert(candidates, {
                point = "TOPRIGHT", relPoint = "BOTTOMRIGHT", xOfs = 0, yOfs = -2,
                fLeft = gtRight - targetWidth, fRight = gtRight,
                fTop = gtBottom - 2, fBottom = gtBottom - 2 - height,
                isBelow = true, isAway = false
            })
            table.insert(candidates, {
                point = "BOTTOMRIGHT", relPoint = "TOPRIGHT", xOfs = 0, yOfs = 2,
                fLeft = gtRight - targetWidth, fRight = gtRight,
                fBottom = gtTop + 2, fTop = gtTop + 2 + height,
                isBelow = false, isAway = false
            })
        end
        
        -- Score candidates
        local bestCand = candidates[1]
        local bestScore = -999999
        
        for _, cand in ipairs(candidates) do
            local hitsCursor = (cand.fLeft < cRight and cand.fRight > cLeft and cand.fBottom < cTop and cand.fTop > cBottom)
            local clipsLeft = cand.fLeft < sMargin
            local clipsRight = cand.fRight > uipWidth - sMargin
            local clipsBottom = cand.fBottom < sMargin
            local clipsTop = cand.fTop > uipHeight - sMargin
            
            local score = 100
            if hitsCursor then
                score = score - 1000 -- Heavy penalty: never cover the mouse
            end
            if clipsBottom then score = score - 200 end
            if clipsTop then score = score - 200 end
            if clipsLeft then score = score - 200 end
            if clipsRight then score = score - 200 end
            
            if cand.isBelow then score = score + 5 end
            if cand.isAway then score = score + 10 end
            
            if score > bestScore then
                bestScore = score
                bestCand = cand
            end
        end
        
        point = bestCand.point
        relativePoint = bestCand.relPoint
        xOfs = bestCand.xOfs
        yOfs = bestCand.yOfs
    end
    
    f:SetPoint(point, GameTooltip, relativePoint, xOfs, yOfs)
    f:Show()
end

-------------------------------------------------------------------------------
-- Event Listeners & Throttled Scanning
-------------------------------------------------------------------------------

local bagScanPending = false
local function ScheduleBagScan()
    if bagScanPending then return end
    bagScanPending = true
    C_Timer.After(0.2, function()
        bagScanPending = false
        CharacterCache:SaveCurrentCharacterBags()
    end)
end

local bankScanPending = false
local function ScheduleBankScan()
    if bankScanPending then return end
    bankScanPending = true
    C_Timer.After(0.3, function()
        bankScanPending = false
        CharacterCache:SaveCurrentCharacterBank()
    end)
    C_Timer.After(0.8, function()
        CharacterCache:SaveCurrentCharacterBank()
    end)
end
CharacterCache.ScheduleBankScan = ScheduleBankScan

local function IsBankInteraction(interactionType)
    if not interactionType then return false end
    local pit = Enum and Enum.PlayerInteractionType
    if not pit then return false end
    return interactionType == pit.Banker
        or interactionType == pit.CharacterBanker
        or interactionType == pit.AccountBanker
end

-------------------------------------------------------------------------------
-- Profession & TradeSkill Frame Tooltip Hooks
-------------------------------------------------------------------------------

local function HookTradeSkillFrame()
    if not _G.TradeSkillFrame or _G.TradeSkillFrame._osHooked then return end
    _G.TradeSkillFrame._osHooked = true
    
    -- Hook output icon
    if _G.TradeSkillSkillIcon then
        _G.TradeSkillSkillIcon:HookScript("OnEnter", function(self)
            local selected = (GetTradeSkillSelectionIndex and GetTradeSkillSelectionIndex()) or (_G.TradeSkillFrame and _G.TradeSkillFrame.selectedSkill)
            if selected and GetTradeSkillItemLink then
                local link = GetTradeSkillItemLink(selected)
                if link then
                    CharacterCache:UpdateAltTooltip(link)
                end
            end
        end)
    end
    
    -- Hook reagent buttons (TradeSkillReagent1 .. MAX_TRADE_SKILL_REAGENTS)
    local maxReagents = _G.MAX_TRADE_SKILL_REAGENTS or 8
    for i = 1, maxReagents do
        local btn = _G["TradeSkillReagent" .. i]
        if btn then
            btn:HookScript("OnEnter", function(self)
                local selected = (GetTradeSkillSelectionIndex and GetTradeSkillSelectionIndex()) or (_G.TradeSkillFrame and _G.TradeSkillFrame.selectedSkill)
                local reagentID = self:GetID()
                if selected and reagentID and GetTradeSkillReagentItemLink then
                    local link = GetTradeSkillReagentItemLink(selected, reagentID)
                    if link then
                        CharacterCache:UpdateAltTooltip(link)
                    end
                end
            end)
        end
    end
end

local function HookCraftFrame()
    if not _G.CraftFrame or _G.CraftFrame._osHooked then return end
    _G.CraftFrame._osHooked = true
    
    if _G.CraftIcon then
        _G.CraftIcon:HookScript("OnEnter", function(self)
            local selected = GetCraftSelectionIndex and GetCraftSelectionIndex()
            if selected and GetCraftItemLink then
                local link = GetCraftItemLink(selected)
                if link then
                    CharacterCache:UpdateAltTooltip(link)
                end
            end
        end)
    end
    
    local maxReagents = _G.MAX_CRAFT_REAGENTS or 8
    for i = 1, maxReagents do
        local btn = _G["CraftReagent" .. i]
        if btn then
            btn:HookScript("OnEnter", function(self)
                local selected = GetCraftSelectionIndex and GetCraftSelectionIndex()
                local reagentID = self:GetID()
                if selected and reagentID and GetCraftReagentItemLink then
                    local link = GetCraftReagentItemLink(selected, reagentID)
                    if link then
                        CharacterCache:UpdateAltTooltip(link)
                    end
                end
            end)
        end
    end
end

eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
eventFrame:RegisterEvent("BANKFRAME_OPENED")
eventFrame:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
eventFrame:RegisterEvent("BANK_TABS_CHANGED")
eventFrame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
eventFrame:RegisterEvent("PLAYER_MONEY")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        CharacterCache:SaveCurrentCharacterBags()
        HookTradeSkillFrame()
        HookCraftFrame()
    elseif event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon == "Blizzard_TradeSkillUI" then
            HookTradeSkillFrame()
        elseif loadedAddon == "Blizzard_CraftUI" then
            HookCraftFrame()
        end
    elseif event == "BAG_UPDATE_DELAYED" then
        ScheduleBagScan()
    elseif event == "BANKFRAME_OPENED" then
        ScheduleBankScan()
    elseif event == "PLAYERBANKSLOTS_CHANGED" or event == "BANK_TABS_CHANGED" then
        ScheduleBankScan()
    elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
        local interactionType = ...
        if IsBankInteraction(interactionType) then
            ScheduleBankScan()
        end
    elseif event == "PLAYER_MONEY" then
        local name = UnitName("player")
        if name and _G.OneStorageUtilsDB and _G.OneStorageUtilsDB.characters and _G.OneStorageUtilsDB.characters[name] then
            _G.OneStorageUtilsDB.characters[name].money = (GetMoney and GetMoney()) or 0
        end
    end
end)

-- Tooltip Integration (Items, Reagents, Recipes, and Trade Skills)
local function IsSafeValue(v)
    return v ~= nil and not (issecretvalue and issecretvalue(v))
end

local function ExtractItemRefFromTooltip(tooltip, data)
    if not tooltip or tooltip ~= GameTooltip then return nil end

    -- 1. Try tooltip:GetItem() first (works across bags, bank, professions, and links)
    if tooltip.GetItem then
        local _, link, id = tooltip:GetItem()
        if IsSafeValue(id) and type(id) == "number" and id > 0 then
            return id
        end
        if IsSafeValue(link) and type(link) == "string" then
            local itemID = tonumber(link:match("item:(%d+)"))
            if itemID then return itemID end
        end
    end

    -- 2. Try TooltipData (guarding all fields against secret values from auras/units/spells)
    if not data and tooltip.GetTooltipData then
        data = tooltip:GetTooltipData()
    end
    if data then
        local dataType = IsSafeValue(data.type) and data.type or nil
        local dataID = IsSafeValue(data.id) and data.id or nil
        local dataLink = IsSafeValue(data.hyperlink) and data.hyperlink or nil

        if dataType and Enum and Enum.TooltipDataType then
            if (dataType == Enum.TooltipDataType.Item
                or dataType == Enum.TooltipDataType.RecipeReagent
                or dataType == Enum.TooltipDataType.Profession
                or dataType == Enum.TooltipDataType.CraftingCost)
                and type(dataID) == "number" and dataID > 0 then
                return dataID
            end
        end

        if type(dataLink) == "string" then
            local itemID = tonumber(dataLink:match("item:(%d+)"))
            if itemID then return itemID end
        end
    end

    return nil
end

local function OnTooltipItemProcessed(tooltip, data)
    if tooltip ~= GameTooltip then return end
    local itemRef = ExtractItemRefFromTooltip(tooltip, data)
    if itemRef then
        CharacterCache:UpdateAltTooltip(itemRef)
    end
end

local function CheckGameTooltipForAltInventory(tooltip)
    if not tooltip or tooltip ~= GameTooltip or not tooltip:IsShown() then return end
    local itemRef = ExtractItemRefFromTooltip(tooltip, nil)
    if itemRef then
        CharacterCache:UpdateAltTooltip(itemRef)
    else
        if _G.OneStorageAltTooltipFrame then
            _G.OneStorageAltTooltipFrame:Hide()
        end
    end
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnTooltipItemProcessed)
    
    if Enum and Enum.TooltipDataType then
        for typeKey, typeValue in pairs(Enum.TooltipDataType) do
            if typeKey ~= "Item" and (
                typeKey == "RecipeReagent" or
                typeKey == "Profession" or
                typeKey == "CraftingCost" or
                typeKey:find("Reagent") or
                typeKey:find("Trade") or
                typeKey:find("Craft") or
                typeKey == "Spell"
            ) then
                pcall(TooltipDataProcessor.AddTooltipPostCall, typeValue, OnTooltipItemProcessed)
            end
        end
    end
elseif GameTooltip and GameTooltip.HasScript and GameTooltip:HasScript("OnTooltipSetItem") then
    GameTooltip:HookScript("OnTooltipSetItem", function(tooltip)
        local _, link = tooltip:GetItem()
        if link then
            CharacterCache:UpdateAltTooltip(link)
        end
    end)
end

if GameTooltip and GameTooltip.HasScript and GameTooltip:HasScript("OnShow") then
    GameTooltip:HookScript("OnShow", function(tooltip)
        CheckGameTooltipForAltInventory(tooltip)
    end)
end

-- Post-hook GameTooltip profession/recipe setters in case TooltipDataProcessor fires before Show()
if hooksecurefunc and GameTooltip then
    local recipeMethods = {
        "SetTradeSkillItem",
        "SetCraftItem",
        "SetRecipeReagentItem",
        "SetRecipeResultItem",
    }
    for _, methodName in ipairs(recipeMethods) do
        if type(GameTooltip[methodName]) == "function" then
            hooksecurefunc(GameTooltip, methodName, function(tooltip)
                CheckGameTooltipForAltInventory(tooltip)
            end)
        end
    end
end

if GameTooltip and GameTooltip.HasScript and GameTooltip:HasScript("OnHide") then
    GameTooltip:HookScript("OnHide", function()
        if _G.OneStorageAltTooltipFrame then
            _G.OneStorageAltTooltipFrame:Hide()
        end
    end)
end
