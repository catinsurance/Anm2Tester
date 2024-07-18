local anmTester = RegisterMod("Anm2Tester", 1)
_G.anmTester = anmTester
include("scripts.saveData")

local game = Game()
local hudFont = Font()
hudFont:Load("font/pftempestasevencondensed.fnt")

--#endregion

--#region DSS Init
local menuProvider = {}

function menuProvider.SaveSaveData()
    anmTester:Save()
end

function menuProvider.GetPaletteSetting()
    return anmTester:GetDssData().MenuPalette
end

function menuProvider.SavePaletteSetting(var)
    anmTester:GetDssData().MenuPalette = var
end

function menuProvider.GetHudOffsetSetting()
    if not REPENTANCE then
        return anmTester:GetDssData().HudOffset
    else
        return Options.HUDOffset * 10
    end
end

function menuProvider.SaveHudOffsetSetting(var)
    if not REPENTANCE then
        anmTester:GetDssData().HudOffset = var
    end
end

function menuProvider.GetGamepadToggleSetting()
    return anmTester:GetDssData().GamepadToggle
end

function menuProvider.SaveGamepadToggleSetting(var)
    anmTester:GetDssData().GamepadToggle = var
end

function menuProvider.GetMenuKeybindSetting()
    return anmTester:GetDssData().MenuKeybind
end

function menuProvider.SaveMenuKeybindSetting(var)
    anmTester:GetDssData().MenuKeybind = var
end

function menuProvider.GetMenuHintSetting()
    return anmTester:GetDssData().MenuHint
end

function menuProvider.SaveMenuHintSetting(var)
    anmTester:GetDssData().MenuHint = var
end

function menuProvider.GetMenuBuzzerSetting()
    return anmTester:GetDssData().MenuBuzzer
end

function menuProvider.SaveMenuBuzzerSetting(var)
    anmTester:GetDssData().MenuBuzzer = var
end

function menuProvider.GetMenusNotified()
    return anmTester:GetDssData().MenusNotified
end

function menuProvider.SaveMenusNotified(var)
    anmTester:GetDssData().MenusNotified = var
end

function menuProvider.GetMenusPoppedUp()
    return anmTester:GetDssData().MenusPoppedUp
end

function menuProvider.SaveMenusPoppedUp(var)
    anmTester:GetDssData().MenusPoppedUp = var
end
--#endregion

--#region Sprite Handling

---@class SpriteData
---@field Id string @A unique id.
---@field Name string @Config name.
---@field Path string @The path to the anm2 file
---@field Sprite Sprite @The actual sprite being rendered
---@field Offset {x: number, y: number} @The offset of the sprite from the center of the screen
---@field CurrentAnimation string @The current animation being played
---@field PlayingAnimation boolean @Whether or not the sprite is playing an animation
---@field ForceLoop boolean @Force the animation to loop, even if it normally wouldn't.
---@field PlaybackSpeed number @The playback speed of the sprite

---@type SpriteData[]
local loadedSprites = {}

---@type SpriteData?
local selectedConfig

local selectedConfigSprite = Sprite()

-- if the config should have the anm2 be rendering
local renderConfig = false

local function loadAnm2(path)
    local newSprite = Sprite()
    newSprite:Load(path, true)

    if newSprite:IsLoaded() then
        newSprite:Play(newSprite:GetDefaultAnimation(), true)
        return newSprite
    end
end

local function clearCache()
    selectedConfigSprite:Reset()

    Isaac.ExecuteCommand("clearcache")

    if selectedConfig then
        selectedConfigSprite:Load(selectedConfig.Path, true)
        selectedConfigSprite:Play(selectedConfig.CurrentAnimation, true)
    end
end

-- grabs the file name from file path, excluding .anm2 extension
local function grabFilename(filePath)
    return filePath:match("^.*/(.*).anm2$") or filePath
end

--#endregion

--#region Dss Helper Functions

local function lerp(a, b, t)
    return a + (b - a) * t
end

-- auto split tooltips into multiple lines optimally
local function generateTooltip(str)
    local endTable = {}
    local currentString = ""
    for w in str:gmatch("%S+") do
        local newString = currentString .. w .. " "
        if newString:len() >= 15 then
            table.insert(endTable, currentString)
            currentString = ""
        end

        currentString = currentString .. w .. " "
    end

    table.insert(endTable, currentString)
    return {strset = endTable}
end

local function getPanelSprites(panelData)
    local panel = panelData.Panel
    if panel.Sprites then
        if type(panel.Sprites) == "string" then
            return DeadSeaScrollsMenu.GetDefaultPanelSprites(panel.Sprites)
        else
            return panel.Sprites
        end
    end
end

local BREAK_LINE = {str = "", nosel = true}

--#endregion

--#region Dss Main

local DSSInitializerFunction = include("scripts.dependencies.dsscore")
local dssModName = "Dead Sea Scrolls (Anm2 Tester)"
local dssCoreVersion = 7
local dssMod = DSSInitializerFunction(dssModName, dssCoreVersion, menuProvider)

local TextCapture = include("scripts.inputCapture")(anmTester, dssMod)

--#endregion

--#region Custom panels and rendering

local DirectoryStates = {
    NORMAL = 0,
    MINIMAL = 1
}

local directory = {}
local directoryState = DirectoryStates.NORMAL
local bselPosition = Vector.Zero

local tallPanelSprite = Sprite()
tallPanelSprite:Load("gfx/ui/hud/menu_slender.anm2", false)
tallPanelSprite:ReplaceSpritesheet(0, "gfx/ui/blank.png")
tallPanelSprite:LoadGraphics()

local tallPanelSpriteList = {
    Shadow = "gfx/ui/hud/slender_shadow.png",
    Back = "gfx/ui/hud/slender_back.png",
    Border = "gfx/ui/hud/slender_border.png",
    Face = "gfx/ui/hud/slender_face.png",
    Mask = "gfx/ui/hud/slender_mask.png"
}

local tooltipCloneSpriteList = {
    Shadow = "gfx/ui/deadseascrolls/menu_shadow.png",
    Back = "gfx/ui/deadseascrolls/menu_back.png",
    Face = "gfx/ui/deadseascrolls/menu_face.png",
    Border = "gfx/ui/deadseascrolls/menu_border.png",
    Mask = "gfx/ui/deadseascrolls/menu_mask.png",
}

for name, sheet in pairs(tallPanelSpriteList) do
    local sprite = Sprite()
    sprite:Load("gfx/ui/hud/menu_slender.anm2", false)
    sprite:ReplaceSpritesheet(0, sheet)
    sprite:LoadGraphics()

    ---@diagnostic disable-next-line: assign-type-mismatch
    tallPanelSpriteList[name] = sprite
end

for name, sheet in pairs(tooltipCloneSpriteList) do
    local sprite = Sprite()
    sprite:Load("gfx/ui/deadseascrolls/menu_tooltip.anm2", false)
    sprite:ReplaceSpritesheet(0, sheet)
    sprite:LoadGraphics()

    ---@diagnostic disable-next-line: assign-type-mismatch
    tooltipCloneSpriteList[name] = sprite
end

local tallPanel = {
    Sprites = tallPanelSpriteList,
    Bounds = {-62, -100, 58, 100},
    Height = 168,
    NoUnderline = true,
    TopSpacing = 0,
    BottomSpacing = 0,
    DefaultFontSize = 2,
    TitleOffset = Vector(0, -120),
    HandleInputs = function (_, _, item, itemswitched, tbl)
        dssMod.handleInputs(item, itemswitched, tbl)
    end,
    GetItem = function (_, item)
        return item
    end,
    GetDrawButtons = function (_, item)
        local psel = item.psel or 1
        local pages = item.pages
        local page
        if pages and #pages > 0 then
            page = item.pages[psel]
        end

        local buttons = {}
        if item.buttons then
            for _, button in ipairs(item.buttons) do
                buttons[#buttons + 1] = button
            end 
        end

        if page and page.buttons then
            for _, button in ipairs(page.buttons) do
                buttons[#buttons + 1] = button
            end
        end

        return buttons
    end,
    DefaultRendering = true
}

-- clone the tooltip panel to play the animation when switching layouts
local tooltipPanel = {
    Sprites = tooltipCloneSpriteList,
    Bounds = {-59, -60, 58, 58},
    Height = 118,
    TopSpacing = 0,
    BottomSpacing = 0,
    DefaultFontSize = 2,
    DrawPositionOffset = Vector(2, 2),
    GetItem = function(panel, item)
        if item.selectedbutton and item.selectedbutton.tooltip then
            return item.selectedbutton.tooltip
        else
            return item.tooltip
        end
    end,
    GetDrawButtons = function(panel, tooltip)
        if tooltip then
            if tooltip.buttons then
                return tooltip.buttons
            else
                return {tooltip}
            end
        end
    end,
    DefaultRendering = true
}

local formatMinimal = {
    Panels = {
        {
            Panel = tooltipPanel,
            Offset = Vector(68, 0),
            Color = 1,
            Type = "tooltip"
        },
        {
            Panel = tallPanel,
            Offset = Vector(-75, 0),
            Color = 1,
            Type = "main"
        },
    }
}

local formats = {
    [DirectoryStates.NORMAL] = dssMod.defaultFormat,
    [DirectoryStates.MINIMAL] = formatMinimal
}

local function openMenu(...)
    Game():GetHUD():SetVisible(false)
    dssMod.openMenu(...)
end

local function closeMenu(tbl, openedFromNothing)
    Game():GetHUD():SetVisible(true)
    directoryState = DirectoryStates.NORMAL
    dssMod.closeMenu(tbl, openedFromNothing)
end

local function generateMenuDraw(item, buttons, panelPos, panel)
    local dssmenu = DeadSeaScrollsMenu
    local menupal = dssmenu.GetPalette()
    local rainbow = menupal.Rainbow

    local drawings = {}
    local valign = item.valign or 0
    local halign = item.halign or 0
    local fsize = item.fsize or panel.DefaultFontSize or 3
    local nocursor = (item.nocursor or item.scroller)
    local width = 82
    local seloff = 0

    local dynamicset = {
        type = 'dynamicset',
        set = {},
        valign = valign,
        halign = halign,
        width = width,
        height = 0,
        pos = panel.DrawPositionOffset or Vector.Zero,
        centeritems = item.centeritems
    }

    if item.gridx then
        dynamicset.gridx = item.gridx
        dynamicset.widest = 0
        dynamicset.highest = 0
    end

    --buttons
    local bsel = item.bsel
    if buttons then
        for i, btn in ipairs(buttons) do
            if not btn.forcenodisplay then
                local btnset = dssMod.generateDynamicSet(btn, btn.selected, fsize, item.clr, item.shine, nocursor)

                if dynamicset.widest then
                    if btnset.width > dynamicset.widest then
                        dynamicset.widest = btnset.width
                    end
                end

                if dynamicset.highest then
                    if btnset.height > dynamicset.highest then
                        dynamicset.highest = btnset.height
                    end
                end

                table.insert(dynamicset.set, btnset)

                dynamicset.height = dynamicset.height + btnset.height

                if btn.selected then
                    seloff = dynamicset.height - btnset.height / 2
                end
            end
        end
    end

    if dynamicset.gridx then
        dynamicset.height = 0

        local gridx, gridy = 1, 1
        local rowDrawings = {}
        for i, drawing in ipairs(dynamicset.set) do
            if drawing.fullrow then
                if #rowDrawings > 0 then
                    rowDrawings = {}
                    gridy = gridy + 1
                end

                gridx = math.ceil(dynamicset.gridx / 2)
                drawing.halign = -2
            end

            drawing.gridxpos = gridx
            drawing.gridypos = gridy

            rowDrawings[#rowDrawings + 1] = drawing

            local highestInRow, widestInRow, bselInRow
            for _, rowDrawing in ipairs(rowDrawings) do
                if not highestInRow or rowDrawing.height > highestInRow then
                    highestInRow = rowDrawing.height
                end

                if not widestInRow or rowDrawing.width > widestInRow then
                    widestInRow = rowDrawing.width
                end

                bselInRow = bselInRow or rowDrawing.bselinrow or rowDrawing.selected
            end

            for _, rowDrawing in ipairs(rowDrawings) do
                rowDrawing.highestinrow = highestInRow
                rowDrawing.widestinrow = widestInRow
                rowDrawing.bselinrow = bselInRow
            end

            gridx = gridx + 1
            if gridx > dynamicset.gridx or i == #dynamicset.set or drawing.fullrow or (dynamicset.set[i + 1] and dynamicset.set[i + 1].fullrow) then
                dynamicset.height = dynamicset.height + highestInRow
                if bselInRow then
                    seloff = dynamicset.height - highestInRow / 2
                end

                rowDrawings = {}
                gridy = gridy + 1
                gridx = 1
            end
        end
    end

    local yOffset = -(dynamicset.height / 2)

    if panel.Bounds then
        if yOffset < panel.Bounds[2] + panel.TopSpacing then
            yOffset = panel.Bounds[2] + panel.TopSpacing
        end

        if item.valign == -1 then
            yOffset = panel.Bounds[2] + panel.TopSpacing
        elseif item.valign == 1 then
            yOffset = (panel.Bounds[4] - panel.BottomSpacing) - dynamicset.height
        end
    end

    if not item.noscroll then
        if item.scroller then
            item.scroll = item.scroll or 0
            item.scroll = math.max(panel.Height / 2, math.min(item.scroll, dynamicset.height - panel.Height / 2))
            seloff = item.scroll
        end

        if dynamicset.height > panel.Height - (panel.TopSpacing + panel.BottomSpacing) then
            seloff = -seloff + panel.Height / 2
            seloff = math.max(-dynamicset.height + panel.Height - panel.BottomSpacing, math.min(0, seloff))
            if item.vscroll then
                item.vscroll = lerp(item.vscroll, seloff, .2)
            else
                item.vscroll = seloff
            end
            dynamicset.pos = Vector(0, item.vscroll)
        end
    end

    dynamicset.pos = dynamicset.pos + Vector(0, yOffset)
    table.insert(drawings, dynamicset)

    --scroll indicator
    if item.scroller and item.scroll then
        local jumpy = (game:GetFrameCount() % 20) / 10
        if item.scroll > panel.Height / 2 then
            local sym = { type = 'sym', frame = 9, pos = Vector(panel.ScrollerSymX, panel.ScrollerSymYTop - jumpy) }
            table.insert(drawings, sym)
        end

        if item.scroll < dynamicset.height - panel.Height / 2 then
            local sym = { type = 'sym', frame = 10, pos = Vector(panel.ScrollerSymX, panel.ScrollerSymYBottom + jumpy) }
            table.insert(drawings, sym)
        end
    end

    --title
    if item.title then
        local shouldUnderline = true
        if panel.NoUnderline ~= nil then
            shouldUnderline = not panel.NoUnderline
        end
        local title = { type = 'str', str = item.title, size = 3, color = menupal[3], pos = panel.TitleOffset, halign = 0, underline = shouldUnderline, bounds = false }
        title.rainbow = rainbow or nil
        table.insert(drawings, title)
    end

    for _, drawing in ipairs(drawings) do
        if drawing.bounds == nil then drawing.bounds = panel.Bounds end
        if drawing.root == nil then drawing.root = panelPos end
    end

    return drawings
end

local function runMenu(tbl)
    local directory = tbl.Directory
    local directorykey = tbl.DirectoryKey
    local format = formats[directoryState]

    local item = directorykey.Item

    if item.menuname and item.item then
        if type(item.item) == "string" then
            directorykey.Item = directory[item.item]
        else
            directorykey.Item = item.item
        end

        item = directorykey.Item
    end

    if not directorykey.ActivePanels then
        directorykey.ActivePanels = {}
    end

    directorykey.SpriteUpdateFrame = not directorykey.SpriteUpdateFrame

    if not tbl.Exiting then -- don't add or adjust panels while exiting
        for i, panelData in ipairs(format.Panels) do
            local activePanel
            for _, active in ipairs(directorykey.ActivePanels) do
                if active.Panel == panelData.Panel then
                    activePanel = active
                    break
                end
            end
            
            local justAppeared
            if not activePanel then
                activePanel = {
                    Sprites = getPanelSprites(panelData),
                    Offset = panelData.Offset,
                    Panel = panelData.Panel,
                    Type = panelData.Type,
                    centeritems = panelData.centeritems == nil and true or panelData.centeritems,
                }

                if panelData.Panel.DefaultRendering then
                    panelData.Panel.StartAppear = panelData.Panel.StartAppear or dssMod.defaultPanelStartAppear
                    panelData.Panel.UpdateAppear = panelData.Panel.UpdateAppear or dssMod.defaultPanelAppearing
                    panelData.Panel.UpdateDisappear = panelData.Panel.UpdateDisappear or dssMod.defaultPanelDisappearing
                    panelData.Panel.RenderBack = panelData.Panel.RenderBack or dssMod.defaultPanelRenderBack
                    panelData.Panel.RenderFront = panelData.Panel.RenderFront or dssMod.defaultPanelRenderFront
                end

                activePanel.Appearing = true
                justAppeared = true
                table.insert(directorykey.ActivePanels, i, activePanel)
            end

            local origin
            if activePanel.Type == "main" then
                origin = Vector(Isaac.GetScreenWidth(), Isaac.GetScreenHeight() / 2)
            elseif activePanel.Type == "tooltip" then
                origin = Vector(0, Isaac.GetScreenHeight() / 2)
            else
                origin = Vector(Isaac.GetScreenWidth() / 2, Isaac.GetScreenHeight() / 2)
            end

            activePanel.Origin = origin
            activePanel.TargetOffset = panelData.Offset
            activePanel.PanelData = panelData
            activePanel.Color = panelData.Color

            local startAppearFunc = panelData.StartAppear or panelData.Panel.StartAppear
            if startAppearFunc and justAppeared then
                startAppearFunc(activePanel, tbl, directorykey.SkipOpenAnimation)
            end
        end
    end

    if directorykey.SkipOpenAnimation then
        directorykey.SkipOpenAnimation = false
    end

    for _, active in ipairs(directorykey.ActivePanels) do
        active.SpriteUpdateFrame = directorykey.SpriteUpdateFrame
        local shouldDisappear = tbl.Exiting
        if not shouldDisappear then
            local isActive
            for _, panelData in ipairs(format.Panels) do
                if panelData.Panel == active.Panel then
                    isActive = true
                    break
                end
            end

            shouldDisappear = not isActive
        end

        if shouldDisappear then
            if not active.Disappearing then
                active.Disappearing = true

                local startDisappearFunc = active.PanelData.StartDisappear or active.Panel.StartDisappear
                if startDisappearFunc then
                    startDisappearFunc(active, tbl)
                end
            end
        end
    end

    for i = #directorykey.ActivePanels, 1, -1 do
        local active = directorykey.ActivePanels[i]
        if active.Disappearing then
            local disappearFunc = active.PanelData.UpdateDisappear or active.Panel.UpdateDisappear
            local remove = true
            if disappearFunc then
                remove = disappearFunc(active, tbl)
            end

            if remove then
                table.remove(directorykey.ActivePanels, i)
            end
        elseif active.Appearing then
            local appearFunc = active.PanelData.UpdateAppear or active.Panel.UpdateAppear
            local finished = true
            if appearFunc then
                finished = appearFunc(active, tbl)
            end
            
            if finished then
                active.Appearing = nil
            end
        end
    end

    if tbl.Exiting and #directorykey.ActivePanels == 0 then
        directorykey.Item = directory[directorykey.Main]
        directorykey.Path = {}
        directorykey.ActivePanels = nil
        tbl.Exiting = nil
        return
    end

    local itemswitched = false
    if item ~= directorykey.PreviousItem then
        itemswitched = true

        if item.generate then
            item.generate(item, tbl)
        end

        directorykey.PreviousItem = item
    end

    if item.update then
        item.update(item, tbl)
    end

    local input = DeadSeaScrollsMenu.GetCoreInput().menu

    local positions = {}
    for i, active in ipairs(directorykey.ActivePanels) do
        active.Offset = lerp(active.Offset, active.TargetOffset, 0.2)

        local origin
        if active.PanelData.Type == "main" then
            origin = Vector(Isaac.GetScreenWidth(), Isaac.GetScreenHeight() / 2)
        elseif active.PanelData.Type == "tooltip" then
            origin = Vector(0, Isaac.GetScreenHeight() / 2)
        else
            origin = Vector(Isaac.GetScreenWidth() / 2, Isaac.GetScreenHeight() / 2)
        end

        local panelPos = origin + active.Offset
        positions[i] = panelPos
        
        if active.Sprites and active.SpriteUpdateFrame then
            for k, v in pairs(active.Sprites) do
                v:Update()
            end
        end

        local renderBack = active.PanelData.RenderBack or active.Panel.RenderBack
        if renderBack then
            renderBack(active, panelPos, tbl)
        end

        if active.Idle then
            local getItem = active.PanelData.GetItem or active.Panel.GetItem
            local object = item
            if getItem then
                object = getItem(active, item, tbl)
            end

            local handleInputs = active.PanelData.HandleInputs or active.Panel.HandleInputs
            if handleInputs then
                handleInputs(active, input, object, itemswitched, tbl)
            end

            local draw = active.PanelData.Draw or active.Panel.Draw
            if draw then
                draw(active, panelPos, object, tbl)
            elseif object then
                local getDrawButtons = active.PanelData.GetDrawButtons or active.Panel.GetDrawButtons
                if getDrawButtons then
                    local drawings = generateMenuDraw(object, getDrawButtons(active, object, tbl), panelPos, active.Panel)
                    for _, drawing in ipairs(drawings) do
                        dssMod.drawMenu(tbl, drawing)
                    end
                end
            end
        end

        local renderFront = active.PanelData.RenderFront or active.Panel.RenderFront
        if renderFront then
            renderFront(active, panelPos, tbl)
        end
    end

    --menu regressing
    if not tbl.Exiting then
        if (input.back or input.toggle) and not itemswitched then
            dssMod.back(tbl)
        end
    end

    if item.postrender then
        item.postrender(item, tbl)
    end
end

--#endregion

--#region Dss Main Menu

--#endregion

--#region Dss Sprite Viewer

local previewConfig

directory.main = {
    title = "anm2 tester",
    buttons = {},
    generate = function (tbl)
        anmTester:Save()

        directoryState = DirectoryStates.MINIMAL
        renderConfig = true
        tbl.buttons = {}

        table.insert(tbl.buttons, {
            str = "new config...",
            dest = "configManager",
            tooltip = generateTooltip("create a new anm2 viewing config."),
            update = function (_, item)
                if item.bsel == 1 then
                    previewConfig = nil
                end
            end,
            func = function ()
                selectedConfig = nil
            end
        })

        -- Attempt to load sprites.
        if #loadedSprites == 0 then
            for _, config in pairs(anmTester.ModData.Configs) do
                table.insert(loadedSprites, config)
            end
        end

        if #loadedSprites > 0 then
            table.insert(tbl.buttons, BREAK_LINE)

            for index, config in ipairs(loadedSprites) do
                local currentEnd = #tbl.buttons + 1
                local isSelected = false
                local button = {
                    str = config.Name:lower(),
                    fsize = 2,
                    dest = "configManager",
                    update = function (_, item)
                        if item.bsel == currentEnd and not isSelected then
                            local configToCopy = loadedSprites[index]
                            previewConfig = {
                                CurrentAnimation = configToCopy.CurrentAnimation,
                                ForceLoop = configToCopy.ForceLoop
                            }

                            previewConfig.Sprite = Sprite()
                            previewConfig.Sprite:Load(config.Path, true)
                            previewConfig.Sprite:Play(previewConfig.CurrentAnimation, true)

                            isSelected = true
                        elseif item.bsel ~= currentEnd then
                            isSelected = false
                        end
                    end,
                    func = function ()
                        selectedConfig = loadedSprites[index]
                        selectedConfigSprite:Load(selectedConfig.Path, true)
                        selectedConfigSprite:Play(selectedConfig.CurrentAnimation, true)
                    end
                }

                table.insert(tbl.buttons, button)
            end
        else
            -- Make sure the sprite is reset
            selectedConfigSprite:Reset()
        end
    end,
    postrender = function (item, tbl)
        local directoryKey = tbl.DirectoryKey

        if previewConfig then
            for _, panel in ipairs(directoryKey.ActivePanels) do
                if panel.PanelData.Type == "tooltip" then
                    local pos = Vector(0, Isaac.GetScreenHeight() / 2) + panel.PanelData.Offset
                    item.tooltip = nil

                    if not previewConfig.Sprite:IsPlaying(previewConfig.CurrentAnimation) then
                        previewConfig.Sprite:Play(previewConfig.CurrentAnimation, true)
                    end

                    previewConfig.Sprite:Render(pos)

                    if Isaac.GetFrameCount() % 2 == 0 then
                        previewConfig.Sprite:Update()
                    end
                end
            end
        end
    end,
}

--#endregion

--#region Dss Anm2 Config Manager

directory.configManager = {
    title = "edit config",
    generate = function (tbl)
        directoryState = DirectoryStates.MINIMAL
        renderConfig = true

        if not selectedConfig then
            -- make a new config
            local config = {
                Id = tostring(Random()),
                Name = "New Config",
                CurrentAnimation = "Idle",
                Path = "gfx/ui/placeholder.anm2",
                ForceLoop = false,
                PlaybackSpeed = 1,
                PlayingAnimation = true,
                Offset = {0, 0}
            }

            selectedConfigSprite:Load(config.Path, true)
            selectedConfigSprite:Play(config.CurrentAnimation, true)

            table.insert(loadedSprites, config)
            selectedConfig = loadedSprites[#loadedSprites]

            -- Add to save data
            anmTester.ModData.Configs[selectedConfig.Id] = selectedConfig
            anmTester:Save()
        end

        -- setup buttons
        tbl.buttons = {
            -- info
            {
                str = "set name:",
                nosel = true,
                fsize = 2,
            },
            {
                str = selectedConfig.Name:lower(),
                fsize = 1,
                tooltip = generateTooltip("change the name of the config"),
                func = function (button)
                    if not TextCapture.CapturingText then
                        TextCapture:StartInputCapture(dssMod, "Config Name", function ()
                            -- check path
                            selectedConfig.Name = TextCapture.FinalizedCapturedTextLine:lower()
                            button.str = selectedConfig.Name
                        end, function ()
                            button.str = selectedConfig.Name:lower()
                        end)
                    end
                end
            },
            BREAK_LINE,
            -- anm2 loader
            {
                str = "loaded anm2:",
                nosel = true,
                fsize = 2,
            },
            {
                str = selectedConfig.Path:lower(),
                fsize = 1,
                tooltip = generateTooltip("enter the file path of your anm2 file"),
                func = function (button, _, tbl)
                    if not TextCapture.CapturingText then
                        TextCapture:StartInputCapture(dssMod, "Anm2 Name", function ()
                            -- check path
                            local stripped = TextCapture.FinalizedCapturedTextLine:gsub(".anm2", "")
                            local dummySprite = loadAnm2(stripped .. ".anm2")
                            if dummySprite then
                                selectedConfig.CurrentAnimation = dummySprite:GetDefaultAnimation()
                                selectedConfig.Path = stripped .. ".anm2"
                                selectedConfigSprite = dummySprite
                                selectedConfig.ForceLoop = false
                                selectedConfig.Offset = {0, 0}
                                selectedConfig.PlayingAnimation = true

                                -- refresh page
                                DeadSeaScrollsMenu.OpenMenuToPath(tbl.Name, "configManager", tbl.DirectoryKey.Path)
                            end
                        end, function ()
                            button.str = selectedConfig.Path:lower()
                        end)
                    end
                end,
                update = function (button, tab)
                    if TextCapture.CapturingText and TextCapture.TextCaptureTarget == "Anm2 Name" then
                        button.str = ""
                    end
                end
            },
            BREAK_LINE,
            {
                str = "reload",
                fsize = 2,
                tooltip = generateTooltip("select to reload the sprite cache"),
                func = function ()
                    clearCache()
                end
            },
            BREAK_LINE,
            -- animation chooser
            {
                strset = {"currently", "playing:"},
                nosel = true,
                fsize = 2,
            },
            {
                str = selectedConfig.CurrentAnimation:lower(),
                fsize = 1,
                nosel = true,
            },
            BREAK_LINE,
            BREAK_LINE,
            -- animation switcher
            {
                str = "animations",
                nosel = true,
                fsize = 2,
            },
        }

        -- Insert animations
        if selectedConfig then
            for _, animation in ipairs(selectedConfigSprite:GetAllAnimationData()) do
                table.insert(tbl.buttons, {
                    str = animation:GetName():lower(),
                    fsize = 1,
                    func = function ()
                        selectedConfig.CurrentAnimation = animation:GetName()
                        selectedConfigSprite:Play(animation:GetName(), true)
                    end
                })
            end
        end

        local restOfTheTable = {
            BREAK_LINE,
            BREAK_LINE,
            -- sprite properties
            {
                str = "properties",
                nosel = true,
                fsize = 2,
            },
            {
                str = "force loop",
                fsize = 1,
                choices = {"false", "true"},
                setting = selectedConfig.ForceLoop and 2 or 1,
                variable = "Anm2Tester_ForceLoop" .. selectedConfig.Name,

                generate = function (button)
                    button.setting = selectedConfig.ForceLoop and 2 or 1
                end,

                changefunc = function (button)
                    selectedConfig.ForceLoop = button.setting == 2
                end
            },
            BREAK_LINE,
            {
                str = "edit playback speed...",
                fsize = 1,
            },
            BREAK_LINE,
            {
                str = "edit offset",
                fsize = 1,
            },
            BREAK_LINE,
            BREAK_LINE,
            -- showcase stuff
            {
                str = "showcasing",
                nosel = true,
                fsize = 2,
            },
            {
                str = "scale references",
                fsize = 1,
            },
            BREAK_LINE,
            {
                str = "preview rooms",
                fsize = 1,
            },
            BREAK_LINE,
            {
                str = "photo mode",
                fsize = 1,
            },
            BREAK_LINE,
            BREAK_LINE,
            {
                str = "delete",
                fsize = 2,
                color = 2,
                dest = "deleteConfig"
            }
        }

        for _, v in ipairs(restOfTheTable) do
            table.insert(tbl.buttons, v)
        end
    end
}

directory.deleteConfig = {
    title = "delete config",
    tooltip = {strset = {"are you sure", "you want to", "do this?"}},
    buttons = {
        {
            strset = {"are you sure", "you want to", "delete this config?"},
            nosel = true,
            fsize = 3,
            generate = function (_, tbl)
                tbl.buttons[3] = {str = '"' .. selectedConfig.Name:lower() .. '"', fsize = 2, nosel = true}
            end
        },
        BREAK_LINE,
        BREAK_LINE,
        BREAK_LINE,
        {
            str = "go back",
            inline = true,
            func = function (_, _, tbl)
                dssMod.back(tbl)
            end
        },
        {
            str = "i'm sure",
            inline = true,
            func = function (_, _, tbl)
                for i, config in ipairs(loadedSprites) do
                    if config.Id == selectedConfig.Id then
                        table.remove(loadedSprites, i)
                        anmTester.ModData.Configs[config.Id] = nil
                        break
                    end
                end
                selectedConfig = nil

                DeadSeaScrollsMenu.OpenMenuToPath(tbl.Name, "main")
            end
        }
    }
}

--#endregion

--#region Dss Misc Stuff

for _, page in pairs(directory) do
    if not page.generate then
        page.generate = function ()
            directoryState = DirectoryStates.NORMAL
            renderConfig = false
        end
    end
end

--#endregion

--#region Sprite rendering stuff

function anmTester:HandleHudFontRender()
    if TextCapture.CapturingText then
        local cancelStr = "Press ESCAPE to cancel"
        local cancelStrPos = Vector(Isaac.GetScreenWidth() / 2, 15) - Vector(hudFont:GetStringWidth(cancelStr) / 2, 0)
        hudFont:DrawStringScaled(cancelStr, cancelStrPos.X, cancelStrPos.Y, 1, 1, KColor.White, 0, true)

        local pasteStr = "CTRL + V to paste text"
        local pasteStrPos = Vector(Isaac.GetScreenWidth() / 2, 30) - Vector(hudFont:GetStringWidth(pasteStr) / 2, 0)
        hudFont:DrawStringScaled(pasteStr, pasteStrPos.X, pasteStrPos.Y, 1, 1, KColor.White, 0, true)

        local enterStr = "ENTER to confirm"
        local enterStrPos = Vector(Isaac.GetScreenWidth() / 2, 45) - Vector(hudFont:GetStringWidth(enterStr) / 2, 0)
        hudFont:DrawStringScaled(enterStr, enterStrPos.X, enterStrPos.Y, 1, 1, KColor.White, 0, true)

        -- render the text
        local center = Vector(Isaac.GetScreenWidth() / 2, Isaac.GetScreenHeight() / 2) - Vector(hudFont:GetStringWidth(TextCapture.CapturingTextLine) / 2, 0)
        hudFont:DrawStringScaled(TextCapture.CapturingTextLine, center.X, center.Y, 1, 1, KColor.White, 0, true)
    end
end

anmTester:AddCallback(ModCallbacks.MC_POST_RENDER, anmTester.HandleHudFontRender)

function anmTester:HandleSpriteRender()
    local room = game:GetRoom()
    local roomCenter = room:GetCenterPos()

    if not renderConfig then
        return
    end

    if not selectedConfig then
        return
    end

    local offset = Vector(selectedConfig.Offset[1], selectedConfig.Offset[2])
    local pos = roomCenter + offset
    pos = Isaac.WorldToScreen(pos)

    if selectedConfig.ForceLoop
    and selectedConfigSprite:IsFinished() then
        selectedConfigSprite:Play(selectedConfigSprite:GetAnimation(), true)
    end

    selectedConfigSprite:Render(pos)

    if Isaac.GetFrameCount() % 2 == 0 then
        selectedConfigSprite:Update()
    end
end

anmTester:AddPriorityCallback(ModCallbacks.MC_POST_RENDER, CallbackPriority.EARLY, anmTester.HandleSpriteRender)

-- if you quit the run while the menu is open, the sprite will still be loaded
-- so fix that ig
function anmTester:ResetSpriteRender()
    renderConfig = false
end

anmTester:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, anmTester.ResetSpriteRender)

--#endregion

--#region Add Dss Menu

local directoryKey = {
    Item = directory.main,
    Main = "main",

    Idle = false,
    MaskAlpha = 1,
    Settings = {},
    SettingsChanged = false,
    Path = {},
}

if REPENTOGON then
    DeadSeaScrollsMenu.AddMenu("anm2 tester", {
        Run = runMenu,

        Open = openMenu,

        Close = closeMenu,

        UseSubMenu = false,

        Directory = directory,
        DirectoryKey = directoryKey
    })
end

_G.anmTester = nil
clearCache()