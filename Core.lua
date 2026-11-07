--[[
    OneStorageUtils - Core.lua
    Core initialization, module registry, global namespace management,
    and persistent copy dialog frame inspector dump (/osdump) for OneStorage Suite.
--]]

local addonName, addonTable = ...

-- Global Namespace Export
_G.OneStorageUtils = _G.OneStorageUtils or addonTable

local Utils = _G.OneStorageUtils

Utils.name = addonName
Utils.version = "0.0.7"
Utils.Modules = Utils.Modules or {}
Utils.isInitialized = false

-- Database defaults
local defaultDB = {
    debugMode = false,
    logLevel = 2, -- 1: Debug, 2: Info, 3: Warn, 4: Error
}

-- Print helper routing to 'OneAddon' chat tab
local function GetOneAddonChatFrame()
    local targetName = "OneAddon"
    for i = 1, (NUM_CHAT_WINDOWS or 10) do
        local name = GetChatWindowInfo(i)
        if name == targetName then
            local cf = _G["ChatFrame" .. i]
            if cf then
                local tab = _G["ChatFrame" .. i .. "Tab"]
                if tab then
                    tab:Show()
                    if PanelTemplates_TabResize then
                        pcall(PanelTemplates_TabResize, tab, 0)
                    end
                end
                return cf
            end
        end
    end
    if FCF_OpenNewWindow then
        local frame = FCF_OpenNewWindow(targetName)
        if frame then
            if FCF_DockFrame and GENERAL_CHAT_DOCK then
                local docked = (FCFDock_GetChatFrames and FCFDock_GetChatFrames(GENERAL_CHAT_DOCK)) or (GENERAL_CHAT_DOCK and GENERAL_CHAT_DOCK.DOCKED_CHAT_FRAMES) or {}
                pcall(FCF_DockFrame, frame, #docked + 1, false)
            end
            if ChatFrame_RemoveAllMessageGroups then pcall(ChatFrame_RemoveAllMessageGroups, frame) end
            if ChatFrame_RemoveAllChannels then pcall(ChatFrame_RemoveAllChannels, frame) end
            if FCF_DockUpdate then pcall(FCF_DockUpdate) end
            local id = frame.GetID and frame:GetID()
            if id then
                local tab = _G["ChatFrame" .. id .. "Tab"]
                if tab then
                    tab:Show()
                    if PanelTemplates_TabResize then pcall(PanelTemplates_TabResize, tab, 0) end
                end
            end
            if FCF_SelectDockFrame and DEFAULT_CHAT_FRAME then pcall(FCF_SelectDockFrame, DEFAULT_CHAT_FRAME) end
            return frame
        end
    end
    return DEFAULT_CHAT_FRAME or ChatFrame1
end
Utils.GetChatFrame = GetOneAddonChatFrame

function Utils:Print(msg)
    local frame = GetOneAddonChatFrame()
    local prefix = "|cff00ccff[OneStorageUtils]|r "
    local text = prefix .. tostring(msg)
    if frame and frame.AddMessage then
        frame:AddMessage(text)
    elseif DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(text)
    else
        print(text)
    end
end

-------------------------------------------------------------------------------
-- Module Registry API
-------------------------------------------------------------------------------

--- Register a module within the OneStorageUtils framework
-- @param moduleName string: Unique name of the module (e.g. "Logger", "FrameHelper", "ContainerHelper")
-- @param moduleTable table: Module implementation table
-- @return table: The registered module table
function Utils:RegisterModule(moduleName, moduleTable)
    if not moduleName or type(moduleName) ~= "string" then
        error("OneStorageUtils:RegisterModule requires a valid string for moduleName", 2)
    end
    
    moduleTable = moduleTable or {}
    self.Modules[moduleName] = moduleTable
    self[moduleName] = moduleTable
    
    if self.Logger and self.Logger.Log then
        self.Logger:Log("Core", "DEBUG", "Module registered: " .. moduleName)
    end
    
    return moduleTable
end

--- Retrieve a registered module
-- @param moduleName string: Name of the module
-- @return table|nil: The requested module or nil if not found
function Utils:GetModule(moduleName)
    return self.Modules[moduleName]
end

-------------------------------------------------------------------------------
-- Persistent Frame Inspection & Copy Tool (/osdump)
-------------------------------------------------------------------------------

local function CreateCopyDialog()
    if _G.OneStorageCopyDialog then return _G.OneStorageCopyDialog end
    
    local copyBox = CreateFrame("Frame", "OneStorageCopyDialog", UIParent, "DialogBoxFrame")
    copyBox:SetSize(640, 520)
    copyBox:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    copyBox:SetFrameStrata("FULLSCREEN_DIALOG")
    copyBox:SetToplevel(true)
    copyBox:SetMovable(true)
    copyBox:EnableMouse(true)
    copyBox:RegisterForDrag("LeftButton")
    copyBox:SetScript("OnDragStart", copyBox.StartMoving)
    copyBox:SetScript("OnDragStop", copyBox.StopMovingOrSizing)
    copyBox:Hide()
    
    local title = copyBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", copyBox, "TOPLEFT", 16, -14)
    title:SetText("|cffffd100OneStorage Frame Inspector Dump (/osdump)|r")
    
    local sf = CreateFrame("ScrollFrame", "OneStorageCopyDialogScrollFrame", copyBox, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 16, -36)
    sf:SetPoint("BOTTOMRIGHT", -36, 42)
    
    local eb = CreateFrame("EditBox", "OneStorageCopyDialogEditBox", sf)
    eb:SetMultiLine(true)
    eb:SetFontObject(ChatFontSmall)
    eb:SetWidth(560)
    eb:SetAutoFocus(false)
    eb:SetScript("OnEscapePressed", function() copyBox:Hide() end)
    sf:SetScrollChild(eb)
    copyBox.editBox = eb
    
    local closeBtn = CreateFrame("Button", nil, copyBox, "UIPanelButtonTemplate")
    closeBtn:SetSize(90, 22)
    closeBtn:SetPoint("BOTTOMRIGHT", copyBox, "BOTTOMRIGHT", -16, 12)
    closeBtn:SetText("Close")
    closeBtn:SetScript("OnClick", function() copyBox:Hide() end)
    
    local selectBtn = CreateFrame("Button", nil, copyBox, "UIPanelButtonTemplate")
    selectBtn:SetSize(140, 22)
    selectBtn:SetPoint("BOTTOMRIGHT", closeBtn, "BOTTOMLEFT", -8, 0)
    selectBtn:SetText("Select All (Cmd+C)")
    selectBtn:SetScript("OnClick", function()
        eb:SetFocus()
        eb:HighlightText()
    end)
    
    if table and table.insert and UISpecialFrames then
        table.insert(UISpecialFrames, "OneStorageCopyDialog")
    end
    
    return copyBox
end

local function DumpFrameDetails(target)
    if not target then return "Target is nil." end
    
    local name = target:GetName() or "Anonymous"
    local objType = target.GetObjectType and target:GetObjectType() or type(target)
    
    local out = string.format("=== ONESTORAGE DUMP: %s ===\n", name)
    out = out .. string.format("Type: %s\n", objType)
    out = out .. string.format("Dimensions: %.1f x %.1f\n", target:GetWidth() or 0, target:GetHeight() or 0)
    
    if target.GetParent then
        local p = target:GetParent()
        out = out .. string.format("Parent: %s\n", p and (p:GetName() or "<Anon>") or "None")
    end
    if target.GetFrameStrata then
        out = out .. string.format("Strata: %s | Level: %d\n", target:GetFrameStrata() or "nil", target:GetFrameLevel() or 0)
    end
    if target.IsShown then
        out = out .. string.format("IsShown: %s | IsVisible: %s\n", tostring(target:IsShown()), tostring(target:IsVisible()))
    end
    
    -- Anchors / Points
    out = out .. "\n--- ANCHORS / POINTS ---\n"
    local numPoints = target.GetNumPoints and target:GetNumPoints() or 0
    for i = 1, numPoints do
        local point, relTo, relPoint, x, y = target:GetPoint(i)
        local relName = relTo and (relTo:GetName() or "<Anon>") or "nil"
        out = out .. string.format("[%d] %s -> %s:%s (%.1f, %.1f)\n", i, tostring(point), relName, tostring(relPoint), x or 0, y or 0)
    end
    
    -- Sub-regions (Textures & FontStrings)
    if target.GetRegions then
        out = out .. "\n--- REGIONS (Textures & FontStrings) ---\n"
        local regions = { target:GetRegions() }
        for idx, reg in ipairs(regions) do
            local regType = reg:GetObjectType()
            local regName = reg:GetName() or ("Region" .. idx)
            local layer = reg.GetDrawLayer and reg:GetDrawLayer() or ""
            
            if regType == "Texture" then
                local texPath = reg.GetTexture and reg:GetTexture() or ""
                out = out .. string.format("[%d] Texture (%s) Layer:%s | Tex:%s | Size:%.1fx%.1f\n",
                    idx, regName, layer, tostring(texPath), reg:GetWidth() or 0, reg:GetHeight() or 0)
            elseif regType == "FontString" then
                local txt = reg.GetText and reg:GetText() or ""
                out = out .. string.format("[%d] FontString (%s) Layer:%s | Text:\"%s\" | Size:%.1fx%.1f\n",
                    idx, regName, layer, tostring(txt), reg:GetWidth() or 0, reg:GetHeight() or 0)
            else
                out = out .. string.format("[%d] %s (%s)\n", idx, regType, regName)
            end
        end
    end
    
    -- Child Frames
    if target.GetChildren then
        out = out .. "\n--- CHILD FRAMES ---\n"
        local children = { target:GetChildren() }
        for idx, child in ipairs(children) do
            local cName = child:GetName() or "AnonChild"
            local cType = child:GetObjectType()
            out = out .. string.format("[%d] %s (%s) Size:%.1fx%.1f\n", idx, cType, cName, child:GetWidth() or 0, child:GetHeight() or 0)
        end
    end
    
    return out
end

-- Slash command: /osdump [FrameName] (or hover frame)
SLASH_ONESTORAGEDUMP1 = "/osdump"
SlashCmdList["ONESTORAGEDUMP"] = function(msg)
    local frameName = (msg and msg ~= "") and msg:match("^%s*(.-)%s*$") or nil
    local target = nil
    
    if frameName and frameName ~= "" then
        target = _G[frameName]
    end
    
    if not target then
        if GetMouseFoci then
            local foci = GetMouseFoci()
            target = foci and foci[1]
        elseif GetMouseFocus then
            target = GetMouseFocus()
        end
    end
    
    if not target then
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[OneStorageUtils]|r Target frame not found! Usage: /osdump [FrameName] or hover over a frame.")
        end
        return
    end
    
    local dumpText = DumpFrameDetails(target)
    local dlg = CreateCopyDialog()
    dlg.editBox:SetText(dumpText)
    dlg:Show()
    dlg.editBox:SetFocus()
    dlg.editBox:HighlightText()
end

-------------------------------------------------------------------------------
-- Initialization Lifecycle & DB Bootstrap
-------------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame", "OneStorageUtils_EventFrame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        -- Initialize SavedVariables
        _G.OneStorageUtilsDB = _G.OneStorageUtilsDB or {}
        for k, v in pairs(defaultDB) do
            if _G.OneStorageUtilsDB[k] == nil then
                _G.OneStorageUtilsDB[k] = v
            end
        end
        Utils.db = _G.OneStorageUtilsDB
        
    elseif event == "PLAYER_LOGIN" then
        Utils.isInitialized = true

    elseif event == "PLAYER_ENTERING_WORLD" then
        if not Utils.welcomePrinted then
            Utils.welcomePrinted = true
            if C_Timer and C_Timer.After then
                C_Timer.After(0.4, function()
                    if Utils.Logger then
                        Utils.Logger:Log("Core", "INFO", "OneStorageUtils v" .. Utils.version .. " initialized successfully.")
                    end
                end)
            else
                if Utils.Logger then
                    Utils.Logger:Log("Core", "INFO", "OneStorageUtils v" .. Utils.version .. " initialized successfully.")
                end
            end
        end
    end
end)

-- Slash Command Registry
SLASH_ONESTORAGEUTILS1 = "/onestorageutils"
SLASH_ONESTORAGEUTILS2 = "/osutils"
SlashCmdList["ONESTORAGEUTILS"] = function(msg)
    local cmd, arg = strsplit(" ", (msg or ""):lower(), 2)
    if cmd == "debug" then
        if Utils.db then
            Utils.db.debugMode = not Utils.db.debugMode
            local state = Utils.db.debugMode and "|cff00ff00ENABLED|r" or "|cffff0000DISABLED|r"
            Utils:Print("Debug mode is now " .. state)
        end
    elseif cmd == "loglevel" and arg then
        local lvl = tonumber(arg)
        if lvl and Utils.Logger then
            Utils.Logger:SetLogLevel(lvl)
            Utils:Print("Log level set to " .. lvl)
        end
    else
        Utils:Print("Commands (v" .. Utils.version .. "):")
        Utils:Print("  /osdump [frame]  - Inspect frame properties & anchors")
        Utils:Print("  /osutils debug   - Toggle diagnostic debug logging")
        Utils:Print("  /osutils loglevel <1-4> - Set log threshold (1:Debug, 2:Info, 3:Warn, 4:Error)")
    end
end
