--[[
    OneStorageUtils - FrameHelper.lua
    Frame lifecycle, Metal/HiRes frame art theming, silver tab/button styling,
    search box generator, and Esc handling for OneStorage Suite.
--]]

local Utils = _G.OneStorageUtils or select(2, ...)
local FrameHelper = {}

-------------------------------------------------------------------------------
-- Frame Reparenting & Anchoring Helpers
-------------------------------------------------------------------------------

--- Reparent a frame safely while managing constraints and points
-- @param childFrame Frame: The child frame to reparent
-- @param parentFrame Frame: Target parent container frame
-- @param keepPoints boolean|nil: If true, preserves existing anchors; if false/nil, clears points and sets SetAllPoints
-- @return boolean: Success status
function FrameHelper:ReparentFrame(childFrame, parentFrame, keepPoints)
    if not childFrame or not parentFrame then
        if Utils.Logger then
            Utils.Logger:Log("FrameHelper", "WARN", "ReparentFrame failed: Invalid frame references")
        end
        return false
    end
    
    if InCombatLockdown and InCombatLockdown() and childFrame:IsProtected() then
        if Utils.Logger then
            Utils.Logger:Log("FrameHelper", "ERROR", "Cannot reparent protected frame during combat lockdown")
        end
        return false
    end
    
    childFrame:SetParent(parentFrame)
    if not keepPoints then
        childFrame:ClearAllPoints()
        childFrame:SetAllPoints(parentFrame)
    end
    
    self:HarmonizeStrataAndLevel(childFrame, parentFrame)
    return true
end

--- Harmonize strata and frame level relative to a parent frame
-- @param childFrame Frame: Target frame to adjust
-- @param parentFrame Frame: Reference parent frame
-- @param levelOffset number|nil: Optional frame level offset above parent (default: 1)
function FrameHelper:HarmonizeStrataAndLevel(childFrame, parentFrame, levelOffset)
    if not childFrame or not parentFrame then return end
    
    levelOffset = levelOffset or 1
    
    local parentStrata = parentFrame:GetFrameStrata()
    if parentStrata and childFrame.SetFrameStrata then
        childFrame:SetFrameStrata(parentStrata)
    end
    
    local parentLevel = parentFrame:GetFrameLevel()
    if parentLevel and childFrame.SetFrameLevel then
        childFrame:SetFrameLevel(math.max(1, parentLevel + levelOffset))
    end
end

-------------------------------------------------------------------------------
-- Escape Key (UISpecialFrames) Management
-------------------------------------------------------------------------------

--- Register a frame to close on Escape key press via Blizzard's UISpecialFrames
-- @param frameOrName Frame|string: Frame instance or frame global name string
-- @return boolean: True if successfully registered
function FrameHelper:RegisterEscClose(frameOrName)
    local frameName = type(frameOrName) == "table" and frameOrName:GetName() or frameOrName
    if type(frameName) ~= "string" or frameName == "" then
        if Utils.Logger then
            Utils.Logger:Log("FrameHelper", "WARN", "RegisterEscClose requires a named frame")
        end
        return false
    end
    
    for i, name in ipairs(UISpecialFrames) do
        if name == frameName then
            return true -- Already registered
        end
    end
    
    table.insert(UISpecialFrames, frameName)
    return true
end

--- Remove a frame from UISpecialFrames
-- @param frameOrName Frame|string: Frame instance or frame global name string
function FrameHelper:UnregisterEscClose(frameOrName)
    local frameName = type(frameOrName) == "table" and frameOrName:GetName() or frameOrName
    if type(frameName) ~= "string" then return end
    
    for i, name in ipairs(UISpecialFrames) do
        if name == frameName then
            table.remove(UISpecialFrames, i)
            break
        end
    end
end

-------------------------------------------------------------------------------
-- Backdrop Helpers
-------------------------------------------------------------------------------

--- Apply standardized Blizzard Backdrop to a frame (supports modern BackdropTemplate)
-- @param frame Frame: Target frame
-- @param bgFile string|nil: Background texture path
-- @param edgeFile string|nil: Border edge texture path
-- @param tileSize number|nil: Tile size
-- @param edgeSize number|nil: Border edge size
-- @param insets table|nil: Border inset table {left=x, right=x, top=x, bottom=x}
function FrameHelper:ApplyBackdrop(frame, bgFile, edgeFile, tileSize, edgeSize, insets)
    if not frame then return end
    
    if not frame.SetBackdrop and BackdropTemplateMixin then
        Mixin(frame, BackdropTemplateMixin)
        frame:OnBackdropLoaded()
    end
    
    if not frame.SetBackdrop then return end
    
    local backdropTable = {
        bgFile   = bgFile or "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = edgeFile or "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile     = true,
        tileSize = tileSize or 32,
        edgeSize = edgeSize or 32,
        insets   = insets or { left = 11, right = 12, top = 12, bottom = 11 }
    }
    
    frame:SetBackdrop(backdropTable)
end

-------------------------------------------------------------------------------
-- Metal & HiRes Frame Art Theme (UIFrameMetal / UIFrameHiRes)
-------------------------------------------------------------------------------

FrameHelper.CurrentTheme = "Metal"

FrameHelper.ThemeConfigs = {
    ["Metal"] = {
        name        = "Metal (1x Standard)",
        cornersFile = "Interface\\FrameGeneral\\UIFrameMetal",
        horizFile   = "Interface\\FrameGeneral\\UIFrameMetalHorizontal",
        vertFile    = "Interface\\FrameGeneral\\UIFrameMetalVertical",
        
        -- TopLeft (Portrait Ring)
        tlCoords = { 136/512, 267/512, 136/512, 267/512 },
        tlW = 132.0, tlH = 132.0,
        tlX = -13, tlY = 14,
        
        -- TopRight (Close Box)
        trCoords = { 0/512, 131/512, 148/512, 267/512 },
        trW = 132.0, trH = 120.0,
        trX = 0, trY = 2,
        
        -- BottomLeft
        blCoords = { 10/512, 50/512, 80/512, 132/512 },
        blW = 40, blH = 52,
        blX = -5, blY = -4,
        
        -- BottomRight
        brCoords = { 220/512, 266/512, 80/512, 132/512 },
        brW = 46, brH = 52,
        brX = 1, brY = -4,
        
        -- TopEdge
        teCoords = { 0, 1, 124/512, 133/512 },
        teH = 10,
        teY = -13,
        teLeftX = 0,
        teRightX = 0,
        
        -- Header Divider (Bottom bar of double top header)
        hdCoords = { 0, 1, 149/512, 157/512 },
        hdH = 8,
        hdY = -32,
        hdLeftX = 0,
        hdRightX = 0,
        
        -- BottomEdge
        beCoords = { 0, 1, 167/512, 178/512 },
        beH = 10,
        beY = -1,
        beLeftX = 0,
        beRightX = 0,
        
        -- LeftEdge
        leCoords = { 11/512, 18/512, 0, 1 },
        leW = 7,
        leX = 9,
        leTopY = 0,
        leBotY = 0,
        
        -- RightEdge
        reCoords = { 258/512, 265/512, 0, 1 },
        reW = 7,
        reX = 0,
        reTopY = 0,
        reBotY = 0,
        
        -- Portrait Center & Size
        portraitX = -7,
        portraitY = 7,
        portraitSize = 60,
        
        -- Close Button Center
        closeX = -13.5,
        closeY = -14.5,
        
        -- Title Centering
        titleX = 0,
        titleY = -13,
        
        -- Background Insets
        bgLeft = 0,
        bgRight = -3,
        bgTop = -3,
        bgBottom = 0,
    },
    ["HiRes"] = {
        name        = "HiRes (2x Scaled)",
        cornersFile = "Interface\\FrameGeneral\\UIFrameHiRes",
        horizFile   = "Interface\\FrameGeneral\\UIFrameHiResHorizontal",
        vertFile    = "Interface\\FrameGeneral\\UIFrameHiResVertical",
        
        tlCoords = { 0, 237/512, 0, 243/256 },
        tlW = 118.5, tlH = 121.5,
        tlX = -14, tlY = 18,
        
        trCoords = { 237/512, 390/512, 4/256, 139/256 },
        trW = 76.5, trH = 67.5,
        trX = 4, trY = 18,
        
        blCoords = { 446/512, 492/512, 0, 50/256 },
        blW = 23, blH = 25,
        blX = -11, blY = -8,
        
        brCoords = { 394/512, 442/512, 0, 50/256 },
        brW = 24, brH = 25,
        brX = 4, brY = -8,
        
        teCoords = { 0, 1, 0, 18/128 },
        teH = 9,
        teY = 3,
        teLeftX = -8,
        teRightX = 8,
        
        hdCoords = { 0, 1, 58/128, 70/128 },
        hdH = 12,
        hdY = -23,
        hdLeftX = -8,
        hdRightX = 8,
        
        beCoords = { 0, 1, 71/128, 89/128 },
        beH = 9,
        beY = 0,
        beLeftX = 0,
        beRightX = 0,
        
        leCoords = { 0, 18/64, 0, 1 },
        leW = 9,
        leX = 12,
        leTopY = 0,
        leBotY = 0,
        
        reCoords = { 19/64, 37/64, 0, 1 },
        reW = 9,
        reX = 0,
        reTopY = 0,
        reBotY = 0,
        
        portraitX = 1,
        portraitY = -7,
        portraitSize = 60,
        
        closeX = -15,
        closeY = -15,
        
        titleX = 0,
        titleY = -14,
        
        bgLeft = 0,
        bgRight = -3,
        bgTop = -3,
        bgBottom = 0,
    }
}

--- Apply authentic Blizzard metal frame art using selected theme config
-- @param frame Frame: The parent or host frame (e.g. OneStorageBagFrame, OneStorageBankFrame)
-- @param options table|nil: Optional customization table { theme = "Metal"|"HiRes", bgTexture = ... }
function FrameHelper:ApplyHiResFrame(frame, options)
    if not frame then return end
    options = options or {}
    
    local themeKey = options.theme or self.CurrentTheme or "Metal"
    local cfg = self.ThemeConfigs[themeKey] or self.ThemeConfigs["Metal"]
    self.CurrentTheme = themeKey
    
    local bgTexPath = options.bgTexture or "Interface\\FrameGeneral\\UI-Background-Marble"
    
    -- Hide Blizzard native NineSlice and TopTileStreaks if present
    if frame.NineSlice then frame.NineSlice:Hide() end
    if frame.TopTileStreaks then frame.TopTileStreaks:Hide() end
    
    -- 1. Master Background Texture
    if not frame.Bg then
        local bg = frame:CreateTexture(nil, "BACKGROUND", nil, -5)
        frame.Bg = bg
    end
    frame.Bg:ClearAllPoints()
    frame.Bg:SetPoint("TOPLEFT", frame, "TOPLEFT", cfg.bgLeft or 0, cfg.bgTop or -3)
    frame.Bg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", cfg.bgRight or -3, cfg.bgBottom or 0)
    frame.Bg:SetHorizTile(false)
    frame.Bg:SetVertTile(false)
    frame.Bg:SetTexCoord(0, 1, 0, 1)
    frame.Bg:SetTexture(bgTexPath)
    frame.Bg:SetVertexColor(0.2, 0.2, 0.2, 1.0)
    frame.Bg:Show()
    
    local border = frame.HiResBorder
    if not border then
        border = CreateFrame("Frame", nil, frame)
        border:SetAllPoints(frame)
        border:SetFrameLevel(frame:GetFrameLevel() + 10)
        frame.HiResBorder = border
        border.Bg = frame.Bg
        
        -- Corners
        border.TopLeft = border:CreateTexture(nil, "OVERLAY", nil, 2)
        border.TopRight = border:CreateTexture(nil, "OVERLAY", nil, 2)
        border.BottomLeft = border:CreateTexture(nil, "OVERLAY", nil, 2)
        border.BottomRight = border:CreateTexture(nil, "OVERLAY", nil, 2)
        
        -- Edges
        border.TopEdge = border:CreateTexture(nil, "OVERLAY", nil, 1)
        border.TopEdge:SetHorizTile(true)
        
        border.BottomEdge = border:CreateTexture(nil, "OVERLAY", nil, 1)
        border.BottomEdge:SetHorizTile(true)
        
        border.LeftEdge = border:CreateTexture(nil, "OVERLAY", nil, 1)
        border.LeftEdge:SetVertTile(true)
        
        border.RightEdge = border:CreateTexture(nil, "OVERLAY", nil, 1)
        border.RightEdge:SetVertTile(true)
        
        -- Header Divider
        border.HeaderDivider = border:CreateTexture(nil, "OVERLAY", nil, 1)
        border.HeaderDivider:SetHorizTile(true)
    end
    
    border:SetFrameLevel(frame:GetFrameLevel() + 10)
    
    -- Textures & Coordinates
    border.TopLeft:SetTexture(cfg.cornersFile)
    border.TopLeft:SetTexCoord(unpack(cfg.tlCoords))
    border.TopLeft:ClearAllPoints()
    border.TopLeft:SetPoint("TOPLEFT", frame, "TOPLEFT", cfg.tlX, cfg.tlY)
    border.TopLeft:SetSize(cfg.tlW, cfg.tlH)
    
    border.TopRight:SetTexture(cfg.cornersFile)
    border.TopRight:SetTexCoord(unpack(cfg.trCoords))
    border.TopRight:ClearAllPoints()
    border.TopRight:SetPoint("TOPRIGHT", frame, "TOPRIGHT", cfg.trX, cfg.trY)
    border.TopRight:SetSize(cfg.trW, cfg.trH)
    
    border.BottomLeft:SetTexture(cfg.cornersFile)
    border.BottomLeft:SetTexCoord(unpack(cfg.blCoords))
    border.BottomLeft:ClearAllPoints()
    border.BottomLeft:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", cfg.blX, cfg.blY)
    border.BottomLeft:SetSize(cfg.blW, cfg.blH)
    
    border.BottomRight:SetTexture(cfg.cornersFile)
    border.BottomRight:SetTexCoord(unpack(cfg.brCoords))
    border.BottomRight:ClearAllPoints()
    border.BottomRight:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", cfg.brX, cfg.brY)
    border.BottomRight:SetSize(cfg.brW, cfg.brH)
    
    border.TopEdge:SetTexture(cfg.horizFile)
    border.TopEdge:SetTexCoord(unpack(cfg.teCoords))
    border.TopEdge:ClearAllPoints()
    border.TopEdge:SetPoint("TOPLEFT", border.TopLeft, "TOPRIGHT", cfg.teLeftX or 0, cfg.teY)
    border.TopEdge:SetPoint("TOPRIGHT", border.TopRight, "TOPLEFT", cfg.teRightX or 0, cfg.teY)
    border.TopEdge:SetHeight(cfg.teH)
    
    border.HeaderDivider:SetTexture(cfg.horizFile)
    border.HeaderDivider:SetTexCoord(unpack(cfg.hdCoords or { 0, 1, 149/512, 157/512 }))
    border.HeaderDivider:ClearAllPoints()
    border.HeaderDivider:SetPoint("TOPLEFT", border.TopLeft, "TOPRIGHT", cfg.hdLeftX or 0, cfg.hdY or -32)
    border.HeaderDivider:SetPoint("TOPRIGHT", border.TopRight, "TOPLEFT", cfg.hdRightX or 0, cfg.hdY or -32)
    border.HeaderDivider:SetHeight(cfg.hdH or 9)
    
    border.BottomEdge:SetTexture(cfg.horizFile)
    border.BottomEdge:SetTexCoord(unpack(cfg.beCoords))
    border.BottomEdge:ClearAllPoints()
    border.BottomEdge:SetPoint("BOTTOMLEFT", border.BottomLeft, "BOTTOMRIGHT", cfg.beLeftX or 0, cfg.beY)
    border.BottomEdge:SetPoint("BOTTOMRIGHT", border.BottomRight, "BOTTOMLEFT", cfg.beRightX or 0, cfg.beY)
    border.BottomEdge:SetHeight(cfg.beH)
    
    border.LeftEdge:SetTexture(cfg.vertFile)
    border.LeftEdge:SetTexCoord(unpack(cfg.leCoords))
    border.LeftEdge:ClearAllPoints()
    border.LeftEdge:SetPoint("TOPLEFT", border.TopLeft, "BOTTOMLEFT", cfg.leX, cfg.leTopY or 0)
    border.LeftEdge:SetPoint("BOTTOMLEFT", border.BottomLeft, "TOPLEFT", 0, cfg.leBotY or 0)
    border.LeftEdge:SetWidth(cfg.leW)
    
    border.RightEdge:SetTexture(cfg.vertFile)
    border.RightEdge:SetTexCoord(unpack(cfg.reCoords))
    border.RightEdge:ClearAllPoints()
    border.RightEdge:SetPoint("TOPRIGHT", border.TopRight, "BOTTOMRIGHT", cfg.reX, cfg.reTopY or 0)
    border.RightEdge:SetPoint("BOTTOMRIGHT", border.BottomRight, "TOPRIGHT", 0, cfg.reBotY or 0)
    border.RightEdge:SetWidth(cfg.reW)
    
    border:Show()
    
    -- Position Portrait inside the top-left ring
    if frame.PortraitContainer then
        frame.PortraitContainer:ClearAllPoints()
        frame.PortraitContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", cfg.portraitX, cfg.portraitY)
        frame.PortraitContainer:SetSize(cfg.portraitSize, cfg.portraitSize)
        frame.PortraitContainer:SetFrameLevel(border:GetFrameLevel() + 1)
        if frame.PortraitContainer.EnableMouse then
            frame.PortraitContainer:EnableMouse(false)
        end
        if frame.PortraitContainer.portrait then
            frame.PortraitContainer.portrait:ClearAllPoints()
            frame.PortraitContainer.portrait:SetAllPoints(frame.PortraitContainer)
            frame.PortraitContainer.portrait:Show()
        end
    elseif frame.portrait then
        frame.portrait:ClearAllPoints()
        frame.portrait:SetPoint("TOPLEFT", frame, "TOPLEFT", cfg.portraitX, cfg.portraitY)
        frame.portrait:SetSize(cfg.portraitSize, cfg.portraitSize)
        frame.portrait:Show()
    end
    
    -- Position Close Button into the top-right recess
    if frame.CloseButton then
        frame.CloseButton:ClearAllPoints()
        frame.CloseButton:SetPoint("CENTER", border.TopRight, "TOPRIGHT", cfg.closeX, cfg.closeY)
        frame.CloseButton:SetFrameLevel(border:GetFrameLevel() + 5)
    end
    
    -- Position Title Text & Container inside the header slot
    local titleTarget = (frame.TitleContainer and frame.TitleContainer.TitleText) or frame.TitleText or frame.Title
    local titleX = cfg.titleX or 0
    local titleY = cfg.titleY or -13
    if frame.TitleContainer then
        frame.TitleContainer:ClearAllPoints()
        -- Anchor symmetrically to the frame with equal margins so the container is mathematically centered
        frame.TitleContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", 50 + titleX, titleY + 12)
        frame.TitleContainer:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", -50 + titleX, titleY - 12)
        frame.TitleContainer:SetFrameLevel(border:GetFrameLevel() + 2)
        frame.TitleContainer:Show()
    end
    if titleTarget then
        titleTarget:ClearAllPoints()
        if frame.TitleContainer and titleTarget:GetParent() == frame.TitleContainer then
            titleTarget:SetPoint("CENTER", frame.TitleContainer, "CENTER", 0, 0)
        else
            titleTarget:SetPoint("CENTER", frame, "TOP", titleX, titleY)
        end
        titleTarget:SetDrawLayer("OVERLAY", 3)
        if titleTarget.SetJustifyH then titleTarget:SetJustifyH("CENTER") end
        if titleTarget.SetJustifyV then titleTarget:SetJustifyV("MIDDLE") end
        titleTarget:Show()
    end
end

-------------------------------------------------------------------------------
-- Simple Panel Styling (Options Panels without Portrait Rings)
-------------------------------------------------------------------------------

--- Apply a clean, modern Blizzard dialog/options frame style without a portrait ring
-- @param frame Frame: Target frame
-- @param titleText string|nil: Header title text
-- @return Button: Created close button
function FrameHelper:ApplySimplePanel(frame, titleText)
    if not frame then return end
    
    self:ApplyBackdrop(
        frame,
        "Interface\\FrameGeneral\\UI-Background-Marble",
        "Interface\\DialogFrame\\UI-DialogBox-Border",
        32,
        16,
        { left = 4, right = 4, top = 4, bottom = 4 }
    )
    if frame.SetBackdropColor then
        frame:SetBackdropColor(0.2, 0.2, 0.2, 0.98)
    end
    if frame.SetBackdropBorderColor then
        frame:SetBackdropBorderColor(0.75, 0.75, 0.75, 1.0)
    end
    
    -- Title FontString
    local title = frame.Title or frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:ClearAllPoints()
    title:SetPoint("TOP", frame, "TOP", 0, -12)
    if title.SetJustifyH then title:SetJustifyH("CENTER") end
    if title.SetJustifyV then title:SetJustifyV("MIDDLE") end
    if titleText then
        title:SetText(titleText)
    end
    frame.Title = title
    
    -- Header Divider Bar
    local divider = frame.Divider or frame:CreateTexture(nil, "ARTWORK")
    divider:ClearAllPoints()
    divider:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -28)
    divider:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -28)
    divider:SetHeight(2)
    divider:SetColorTexture(0.5, 0.5, 0.5, 0.4)
    frame.Divider = divider
    
    -- Close Button
    local closeBtn = frame.CloseButton or CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetSize(22, 22)
    closeBtn:ClearAllPoints()
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)
    frame.CloseButton = closeBtn
    
    return closeBtn
end

-------------------------------------------------------------------------------
-- Search Box Helper
-------------------------------------------------------------------------------

--- Create a standardized search editbox matching Blizzard UI searchbars
-- @param parent Frame: Parent frame container
-- @param name string: Global frame name
-- @param onTextChanged function: Callback invoked when search query text changes (passes self, text)
-- @return EditBox: Styled search box
function FrameHelper:CreateSearchBox(parent, name, onTextChanged)
    local ok, editBox = pcall(CreateFrame, "EditBox", name, parent, "BagSearchBoxTemplate")
    if not ok or not editBox then
        -- Fallback if BagSearchBoxTemplate is not present in client
        editBox = CreateFrame("EditBox", name, parent)
        editBox:SetFontObject("GameFontHighlightSmall")
        editBox:SetAutoFocus(false)
        editBox:SetTextInsets(16, 16, 0, 0)
        
        local bg = editBox:CreateTexture(nil, "BACKGROUND")
        bg:SetTexture("Interface\\Common\\Common-Input-Border")
        bg:SetAllPoints(editBox)
        editBox.Bg = bg
        
        local icon = editBox:CreateTexture(nil, "OVERLAY")
        icon:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
        icon:SetSize(14, 14)
        icon:SetPoint("LEFT", editBox, "LEFT", 2, -1)
        editBox.Icon = icon
    end
    
    editBox:SetHeight(20)
    editBox:SetAutoFocus(false)
    
    if onTextChanged and type(onTextChanged) == "function" then
        editBox:HookScript("OnTextChanged", function(self)
            local text = self:GetText() or ""
            onTextChanged(self, text)
        end)
    end
    
    editBox:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
    end)
    
    return editBox
end

-------------------------------------------------------------------------------
-- Silver Tab Styling Helpers
-------------------------------------------------------------------------------

local SILVER_TAB_ACTIVE   = "Interface\\OptionsFrame\\UI-OptionsFrame-ActiveTab"
local SILVER_TAB_INACTIVE = "Interface\\OptionsFrame\\UI-OptionsFrame-InactiveTab"

--- Style an existing standard tab button with silver textures
-- @param button Button: The tab button to style
function FrameHelper:StyleTabAsSilver(button)
    if not button then return end
    
    local btnName = button.GetName and button:GetName()
    local left = button.Left or (btnName and _G[btnName .. "Left"])
    local middle = button.Middle or (btnName and _G[btnName .. "Middle"])
    local right = button.Right or (btnName and _G[btnName .. "Right"])
    
    if left then
        left:SetTexture(SILVER_TAB_INACTIVE)
        left:SetTexCoord(0, 0.15625, 0, 1.0)
    end
    if middle then
        middle:SetTexture(SILVER_TAB_INACTIVE)
        middle:SetTexCoord(0.15625, 0.84375, 0, 1.0)
    end
    if right then
        right:SetTexture(SILVER_TAB_INACTIVE)
        right:SetTexCoord(0.84375, 1.0, 0, 1.0)
    end
    
    local leftDisabled = button.LeftDisabled or (btnName and _G[btnName .. "LeftDisabled"])
    local middleDisabled = button.MiddleDisabled or (btnName and _G[btnName .. "MiddleDisabled"])
    local rightDisabled = button.RightDisabled or (btnName and _G[btnName .. "RightDisabled"])
    
    if leftDisabled then
        leftDisabled:SetTexture(SILVER_TAB_ACTIVE)
        leftDisabled:SetTexCoord(0, 0.15625, 0, 1.0)
    end
    if middleDisabled then
        middleDisabled:SetTexture(SILVER_TAB_ACTIVE)
        middleDisabled:SetTexCoord(0.15625, 0.84375, 0, 1.0)
    end
    if rightDisabled then
        rightDisabled:SetTexture(SILVER_TAB_ACTIVE)
        rightDisabled:SetTexCoord(0.84375, 1.0, 0, 1.0)
    end
end

--- Create a standalone horizontal tab button styled with silver metal textures
-- @param parent Frame: Parent frame container
-- @param name string|nil: Unique global button name
-- @param id number: Tab ID index
-- @param text string: Display text for tab label
-- @return Button: Created and styled silver tab button
function FrameHelper:CreateSilverTab(parent, name, id, text)
    local btn = CreateFrame("Button", name, parent)
    btn:SetHeight(32)
    btn:SetID(id or 1)
    
    local left = btn:CreateTexture(name and (name .. "Left"), "BACKGROUND")
    left:SetTexture(SILVER_TAB_INACTIVE)
    left:SetSize(20, 32)
    left:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, -1)
    left:SetTexCoord(0, 0.15625, 0, 1.0)
    btn.Left = left
    
    local right = btn:CreateTexture(name and (name .. "Right"), "BACKGROUND")
    right:SetTexture(SILVER_TAB_INACTIVE)
    right:SetSize(20, 32)
    right:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 0, -1)
    right:SetTexCoord(0.84375, 1.0, 0, 1.0)
    btn.Right = right
    
    local middle = btn:CreateTexture(name and (name .. "Middle"), "BACKGROUND")
    middle:SetTexture(SILVER_TAB_INACTIVE)
    middle:SetHeight(32)
    middle:SetPoint("LEFT", left, "RIGHT", 0, 0)
    middle:SetPoint("RIGHT", right, "LEFT", 0, 0)
    middle:SetTexCoord(0.15625, 0.84375, 0, 1.0)
    btn.Middle = middle
    
    local leftDisabled = btn:CreateTexture(name and (name .. "LeftDisabled"), "BACKGROUND")
    leftDisabled:SetTexture(SILVER_TAB_ACTIVE)
    leftDisabled:SetSize(20, 35)
    leftDisabled:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 2)
    leftDisabled:SetTexCoord(0, 0.15625, 0, 1.0)
    leftDisabled:Hide()
    btn.LeftDisabled = leftDisabled
    
    local rightDisabled = btn:CreateTexture(name and (name .. "RightDisabled"), "BACKGROUND")
    rightDisabled:SetTexture(SILVER_TAB_ACTIVE)
    rightDisabled:SetSize(20, 35)
    rightDisabled:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 0, 2)
    rightDisabled:SetTexCoord(0.84375, 1.0, 0, 1.0)
    rightDisabled:Hide()
    btn.RightDisabled = rightDisabled
    
    local middleDisabled = btn:CreateTexture(name and (name .. "MiddleDisabled"), "BACKGROUND")
    middleDisabled:SetTexture(SILVER_TAB_ACTIVE)
    middleDisabled:SetHeight(35)
    middleDisabled:SetPoint("LEFT", leftDisabled, "RIGHT", 0, 0)
    middleDisabled:SetPoint("RIGHT", rightDisabled, "LEFT", 0, 0)
    middleDisabled:SetTexCoord(0.15625, 0.84375, 0, 1.0)
    middleDisabled:Hide()
    btn.MiddleDisabled = middleDisabled
    
    local highlight = btn:CreateTexture(name and (name .. "Highlight"), "HIGHLIGHT")
    highlight:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-Tab-RealHighlight")
    highlight:SetBlendMode("ADD")
    highlight:SetPoint("TOPLEFT", btn, "TOPLEFT", 3, 5)
    highlight:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -3, 0)
    btn.Highlight = highlight
    
    local fs = btn:CreateFontString(name and (name .. "Text"), "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("CENTER", btn, "CENTER", 0, 2)
    fs:SetText(text or "")
    btn.Text = fs
    btn:SetFontString(fs)
    
    btn.SetSelected = function(self, selected)
        if selected then
            self.Left:Hide(); self.Middle:Hide(); self.Right:Hide()
            self.LeftDisabled:Show(); self.MiddleDisabled:Show(); self.RightDisabled:Show()
            self.Text:SetTextColor(1, 1, 1)
        else
            self.Left:Show(); self.Middle:Show(); self.Right:Show()
            self.LeftDisabled:Hide(); self.MiddleDisabled:Hide(); self.RightDisabled:Hide()
            self.Text:SetTextColor(0.7, 0.7, 0.7)
        end
    end
    
    return btn
end

-------------------------------------------------------------------------------
-- Metal Action Button Helpers
-------------------------------------------------------------------------------

local BTN_DISABLED_UP   = "Interface\\Buttons\\UI-Panel-Button-Disabled"
local BTN_DISABLED_DOWN = "Interface\\Buttons\\UI-Panel-Button-Disabled-Down"
local BTN_HIGHLIGHT     = "Interface\\Buttons\\UI-Panel-Button-Highlight"

--- Style a button with UI-Panel-Button-Disabled metal textures
-- @param btn Button: The button to style
function FrameHelper:StyleButtonAsMetal(btn)
    if not btn or btn.isStyledAsMetal then return end
    btn.isStyledAsMetal = true
    
    local btnName = btn.GetName and btn:GetName()
    local oldLeft = btn.Left or (btnName and _G[btnName .. "Left"])
    local oldMiddle = btn.Middle or (btnName and _G[btnName .. "Middle"])
    local oldRight = btn.Right or (btnName and _G[btnName .. "Right"])
    if oldLeft then oldLeft:Hide() end
    if oldMiddle then oldMiddle:Hide() end
    if oldRight then oldRight:Hide() end
    
    local left = btn:CreateTexture(nil, "BACKGROUND")
    left:SetSize(12, btn:GetHeight() or 22)
    left:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
    left:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 0)
    btn.MetalLeft = left
    
    local right = btn:CreateTexture(nil, "BACKGROUND")
    right:SetSize(12, btn:GetHeight() or 22)
    right:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 0, 0)
    right:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
    btn.MetalRight = right
    
    local middle = btn:CreateTexture(nil, "BACKGROUND")
    middle:SetPoint("TOPLEFT", left, "TOPRIGHT", 0, 0)
    middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT", 0, 0)
    btn.MetalMiddle = middle
    
    local hlLeft = btn:CreateTexture(nil, "HIGHLIGHT")
    hlLeft:SetSize(12, btn:GetHeight() or 22)
    hlLeft:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
    hlLeft:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 0)
    hlLeft:SetTexture(BTN_HIGHLIGHT)
    hlLeft:SetTexCoord(0, 0.09375, 0, 0.6875)
    hlLeft:SetBlendMode("ADD")
    
    local hlRight = btn:CreateTexture(nil, "HIGHLIGHT")
    hlRight:SetSize(12, btn:GetHeight() or 22)
    hlRight:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 0, 0)
    hlRight:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
    hlRight:SetTexture(BTN_HIGHLIGHT)
    hlRight:SetTexCoord(0.53125, 0.625, 0, 0.6875)
    hlRight:SetBlendMode("ADD")
    
    local hlMid = btn:CreateTexture(nil, "HIGHLIGHT")
    hlMid:SetPoint("TOPLEFT", hlLeft, "TOPRIGHT", 0, 0)
    hlMid:SetPoint("BOTTOMRIGHT", hlRight, "BOTTOMLEFT", 0, 0)
    hlMid:SetTexture(BTN_HIGHLIGHT)
    hlMid:SetTexCoord(0.09375, 0.53125, 0, 0.6875)
    hlMid:SetBlendMode("ADD")
    
    local function ApplyTextureState(texFile, r, g, b, a)
        left:SetTexture(texFile)
        left:SetTexCoord(0, 0.09375, 0, 0.6875)
        middle:SetTexture(texFile)
        middle:SetTexCoord(0.09375, 0.53125, 0, 0.6875)
        right:SetTexture(texFile)
        right:SetTexCoord(0.53125, 0.625, 0, 0.6875)
        r = r or 1; g = g or 1; b = b or 1; a = a or 1
        left:SetVertexColor(r, g, b, a)
        middle:SetVertexColor(r, g, b, a)
        right:SetVertexColor(r, g, b, a)
    end
    
    local function UpdateVisualState()
        if not btn:IsEnabled() then
            ApplyTextureState(BTN_DISABLED_UP, 0.55, 0.55, 0.55, 0.7)
            if btn.SetDisabledFontObject then
                btn:SetDisabledFontObject("GameFontDisableSmall")
            end
        else
            ApplyTextureState(BTN_DISABLED_UP, 1, 1, 1, 1)
            if btn.SetNormalFontObject then
                btn:SetNormalFontObject("GameFontHighlightSmall")
            end
        end
    end
    
    btn:HookScript("OnMouseDown", function()
        if btn:IsEnabled() then ApplyTextureState(BTN_DISABLED_DOWN, 1, 1, 1, 1) end
    end)
    btn:HookScript("OnMouseUp", function()
        UpdateVisualState()
    end)
    
    if btn.Enable and btn.Disable then
        hooksecurefunc(btn, "Enable", UpdateVisualState)
        hooksecurefunc(btn, "Disable", UpdateVisualState)
    end
    
    if btn.SetPushedTextOffset then
        btn:SetPushedTextOffset(1, -1)
    end
    
    UpdateVisualState()
end

--- Style an existing standard button with metal textures (alias)
-- @param button Button: The button to style
function FrameHelper:StyleButtonAsSilver(button)
    self:StyleButtonAsMetal(button)
end

--- Create a standalone metal action button
-- @param parent Frame: Parent frame
-- @param name string|nil: Button name
-- @param text string|nil: Button label
-- @param template string|nil: Optional template override
-- @return Button: Created metal button
function FrameHelper:CreateSilverButton(parent, name, text, template)
    local btn = CreateFrame("Button", name, parent, template)
    
    if btn.SetNormalFontObject then
        btn:SetNormalFontObject("GameFontHighlightSmall")
    end
    if btn.SetDisabledFontObject then
        btn:SetDisabledFontObject("GameFontDisableSmall")
    end
    if btn.SetHighlightFontObject then
        btn:SetHighlightFontObject("GameFontHighlightSmall")
    end
    
    if text then
        btn:SetText(text)
    end
    
    self:StyleButtonAsMetal(btn)
    
    return btn
end
--- Create a styled options checkbox with label and tooltip
-- @param parent Frame: Parent frame
-- @param name string|nil: Checkbox frame name
-- @param label string: Text label beside the checkbox
-- @param tooltipText string|nil: Optional tooltip explanation
-- @param getter function|nil: Function returning boolean state
-- @param setter function|nil: Function(val) to save boolean state
-- @return CheckButton: Created checkbox frame
function FrameHelper:CreateCheckbox(parent, name, label, tooltipText, getter, setter)
    local cb = CreateFrame("CheckButton", name, parent, "UICheckButtonTemplate")
    cb:SetSize(22, 22)
    
    local text = (name and _G[name .. "Text"]) or cb.Text or cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:ClearAllPoints()
    text:SetPoint("LEFT", cb, "RIGHT", 4, 1)
    if text.SetFontObject then
        text:SetFontObject("GameFontHighlightSmall")
    end
    text:SetText(label)
    cb.Text = text
    
    if tooltipText then
        cb:SetScript("OnEnter", function(s)
            GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
            GameTooltip:SetText(label, 1, 1, 1)
            GameTooltip:AddLine(tooltipText, 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end)
        cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    
    cb:SetScript("OnClick", function(s)
        local val = s:GetChecked() and true or false
        if setter then setter(val) end
    end)
    
    cb.Refresh = function(s)
        if getter then
            s:SetChecked(getter() and true or false)
        end
    end
    
    return cb
end

--- Create a stepper widget ([-] Value [+]) for numerical settings like columns
-- @param parent Frame: Parent frame
-- @param name string|nil: Stepper frame name
-- @param label string: Text label
-- @param minVal number: Minimum allowed value
-- @param maxVal number: Maximum allowed value
-- @param getter function|nil: Function returning current number
-- @param setter function|nil: Function(val) to save number
-- @return Frame: Created stepper container frame
function FrameHelper:CreateStepper(parent, name, label, minVal, maxVal, getter, setter)
    local container = CreateFrame("Frame", name, parent)
    container:SetSize(200, 24)
    
    local title = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    title:SetPoint("LEFT", container, "LEFT", 0, 0)
    title:SetText(label)
    container.Title = title
    
    local minusBtn = self:CreateSilverButton(container, nil, "-")
    minusBtn:SetSize(20, 20)
    minusBtn:SetPoint("RIGHT", container, "RIGHT", -44, 0)
    
    local valText = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    valText:SetPoint("LEFT", minusBtn, "RIGHT", 2, 0)
    valText:SetPoint("RIGHT", container, "RIGHT", -22, 0)
    valText:SetJustifyH("CENTER")
    container.ValText = valText
    
    local plusBtn = self:CreateSilverButton(container, nil, "+")
    plusBtn:SetSize(20, 20)
    plusBtn:SetPoint("RIGHT", container, "RIGHT", 0, 0)
    
    local function UpdateVal()
        local cur = getter and getter() or minVal
        valText:SetText(tostring(cur))
        if minusBtn.SetEnabled then minusBtn:SetEnabled(cur > minVal) end
        if plusBtn.SetEnabled then plusBtn:SetEnabled(cur < maxVal) end
    end
    
    minusBtn:SetScript("OnClick", function()
        local cur = getter and getter() or minVal
        if cur > minVal then
            cur = cur - 1
            if setter then setter(cur) end
            UpdateVal()
        end
    end)
    
    plusBtn:SetScript("OnClick", function()
        local cur = getter and getter() or minVal
        if cur < maxVal then
            cur = cur + 1
            if setter then setter(cur) end
            UpdateVal()
        end
    end)
    
    container.Refresh = UpdateVal
    UpdateVal()
    return container
end

-- Register module with Core
Utils:RegisterModule("FrameHelper", FrameHelper)
