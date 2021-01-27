include("callable")
include("azimuthlib-uiproportionalsplitter")
local Azimuth = include("azimuthlib-basic")
local CustomTabbedWindow = include("azimuthlib-customtabbedwindow")

local SectorOverviewConfig -- client/server
local sectorOverview_notifyAboutEnemies -- server
local sectorOverview_configOptions, sectorOverview_isVisible, sectorOverview_refreshCounter, sectorOverview_settingsModified, sectorOverview_playerAddedList, sectorOverview_playerCoords, sectorOverview_GT135 -- client
local sectorOverview_tabbedWindow, sectorOverview_stationTab, sectorOverview_stationList, sectorOverview_shipTab, sectorOverview_shipList, sectorOverview_gateTab, sectorOverview_gateList, sectorOverview_playerTab, sectorOverview_playerList, sectorOverview_playerCombo, sectorOverview_windowWidthBox, sectorOverview_windowHeightBox, sectorOverview_notifyAboutEnemiesCheckBox, sectorOverview_showNPCNamesCheckBox, sectorOverview_toggleBtnComboBox, sectorOverview_prevTabBtnComboBox, sectorOverview_nextTabBtnComboBox -- client UI


if onClient() then


sectorOverview_GT135 = GameVersion() >= Version(1, 3, 5)

-- PREDEFINED --

function SectorShipOverview.initialize() -- overridden
    local allowedKeys = {
      {"", "-"},
      {"KP_Divide", "Divide"%_t},
      {"KP_Multiply", "Multiply"%_t},
      {"KP_Minus", "Minus"%_t},
      {"KP_Plus", "Plus"%_t},
      {"KP_1", "1"},
      {"KP_2", "2"},
      {"KP_3", "3"},
      {"KP_4", "4"},
      {"KP_5", "5"},
      {"KP_6", "6"},
      {"KP_7", "7"},
      {"KP_8", "8"},
      {"KP_9", "9"},
      {"KP_0", "0"}
    }
    local keysEnum = {}
    for k, v in ipairs(allowedKeys) do
        keysEnum[k] = v[1]
    end

    sectorOverview_configOptions = {
      ["_version"] = {"1.1", comment = "Config version. Don't touch."},
      ["WindowWidth"] = {320, round = -1, min = 320, max = 800, comment = "UI window width"},
      ["WindowHeight"] = {400, round = -1, min = 360, max = 1000, comment = "UI window height"},
      ["NotifyAboutEnemies"] = {true, comment = "If true, will notify when enemy player (at war) enters a sector."},
      ["ShowNPCNames"] = {true, comment = "If true, sector overview will show unique NPC names in addition to their titles."},
      ["ToggleButton"] = {"KP_Minus", enum = keysEnum, comment = "Pressing this button will open/close the overview window."},
      ["PrevTabButton"] = {"KP_Divide", enum = keysEnum, comment = "Pressing this button will cycle to the previous tab."},
      ["NextTabButton"] = {"KP_Multiply", enum = keysEnum, comment = "Pressing this button will cycle to the next tab."}
    }
    local isModified
    SectorOverviewConfig, isModified = Azimuth.loadConfig("SectorOverview", sectorOverview_configOptions)
    if isModified then
        Azimuth.saveConfig("SectorOverview", SectorOverviewConfig, sectorOverview_configOptions)
    end

    -- init UI
    local res = getResolution()
    local size = vec2(SectorOverviewConfig.WindowWidth, SectorOverviewConfig.WindowHeight)
    local position = vec2(res.x - size.x - 5, 180)

    self.window = Hud():createWindow(Rect(position, position + size))
    self.window.caption = "Sector Overview"%_t
    self.window.moveable = true
    self.window.showCloseButton = true
    self.window.visible = false

    local helpLabel = self.window:createLabel(Rect(size.x - 55, -29, size.x - 30, -10), "?", 15)
    helpLabel.tooltip = [[Colors of the object icons indicate ownership type:
* Green - yours.
* Purple - your alliance.
* Yellow - other player.
* Blue - other alliance.
* White - NPC.

Object name color represents relation status (war, ceasefire, neutral, allies)]]%_t

    sectorOverview_tabbedWindow = CustomTabbedWindow(self, self.window, Rect(vec2(10, 10), size - 10))
    sectorOverview_tabbedWindow.onSelectedFunction = "refreshList"

    -- stations
    sectorOverview_stationTab = sectorOverview_tabbedWindow:createTab("Station List"%_t, "data/textures/icons/solar-system.png", "Station List"%_t)
    sectorOverview_stationList = sectorOverview_stationTab:createListBoxEx(Rect(sectorOverview_stationTab.size))
    sectorOverview_stationList.columns = 4
    sectorOverview_stationList:setColumnWidth(0, 25)
    sectorOverview_stationList:setColumnWidth(1, 25)
    sectorOverview_stationList:setColumnWidth(2, sectorOverview_stationList.width - 85)
    sectorOverview_stationList:setColumnWidth(3, 25)
    sectorOverview_stationList.onSelectFunction = "onEntrySelected"

    -- ships
    sectorOverview_shipTab = sectorOverview_tabbedWindow:createTab("Ship List"%_t, "data/textures/icons/ship.png", "Ship List"%_t)
    sectorOverview_shipList = sectorOverview_shipTab:createListBoxEx(Rect(sectorOverview_shipTab.size))
    sectorOverview_shipList.columns = 4
    sectorOverview_shipList:setColumnWidth(0, 25)
    sectorOverview_shipList:setColumnWidth(1, 25)
    sectorOverview_shipList:setColumnWidth(2, sectorOverview_shipList.width - 85)
    sectorOverview_shipList:setColumnWidth(3, 25)
    sectorOverview_shipList.onSelectFunction = "onEntrySelected"

    -- gates
    sectorOverview_gateTab = sectorOverview_tabbedWindow:createTab("Gate & Wormhole List"%_t, "data/textures/icons/vortex.png", "Gate & Wormhole List"%_t)
    sectorOverview_gateList = sectorOverview_gateTab:createListBoxEx(Rect(sectorOverview_gateTab.size))
    sectorOverview_gateList.columns = 2
    sectorOverview_gateList:setColumnWidth(0, 25)
    sectorOverview_gateList:setColumnWidth(1, sectorOverview_gateList.width - 35)
    sectorOverview_gateList.onSelectFunction = "onEntrySelected"

    -- players
    sectorOverview_playerTab = sectorOverview_tabbedWindow:createTab("Player List"%_t, "data/textures/icons/crew.png", "Player List"%_t)
    sectorOverview_playerTab.onSelectedFunction = "sectorOverview_onPlayerTabSelected"

    local hsplit = UIHorizontalProportionalSplitter(Rect(sectorOverview_playerTab.size), 10, 0, {30, 0.5, 25, 35})
    local showButton = sectorOverview_playerTab:createButton(hsplit[1], "Show on Galaxy Map"%_t, "sectorOverview_onShowPlayerPressed")
    showButton.maxTextSize = 14
    showButton.tooltip = [[Show the selected player on the galaxy map.]]%_t

    sectorOverview_playerList = sectorOverview_playerTab:createListBoxEx(hsplit[2])
    sectorOverview_playerCombo = sectorOverview_playerTab:createValueComboBox(hsplit[3], "")

    local vsplit = UIVerticalSplitter(hsplit[4], 10, 0, 0.5)
    local button = sectorOverview_playerTab:createButton(vsplit.left, "Add"%_t, "sectorOverview_onAddPlayerTracking")
    button.maxTextSize = 14
    button.tooltip = "Add the selected player from the combo box to the list of tracked players."%_t
    button = sectorOverview_playerTab:createButton(vsplit.right, "Remove"%_t, "sectorOverview_onRemovePlayerTracking")
    button.maxTextSize = 14
    button.tooltip = "Remove the selected player from the list of tracked players."%_t

    -- settings
    local tab = sectorOverview_tabbedWindow:createTab("Settings"%_t, "data/textures/icons/gears.png", "Settings"%_t)
    local hsplit = UIHorizontalProportionalSplitter(Rect(tab.size), 10, 0, {0.5, 35})
    local lister = UIVerticalLister(hsplit[1], 5, 0)

    local rect = lister:placeCenter(vec2(lister.inner.width, 25))
    local splitter = UIVerticalSplitter(rect, 10, 0, 0.65)
    local label = tab:createLabel(splitter.left, "Open window (numpad)"%_t, 14)
    label:setLeftAligned()
    sectorOverview_toggleBtnComboBox = tab:createValueComboBox(splitter.right, "sectorOverview_onSettingsModified")

    local rect = lister:placeCenter(vec2(lister.inner.width, 25))
    local splitter = UIVerticalSplitter(rect, 10, 0, 0.65)
    local label = tab:createLabel(splitter.left, "Prev. tab (numpad)"%_t, 14)
    label:setLeftAligned()
    sectorOverview_prevTabBtnComboBox = tab:createValueComboBox(splitter.right, "sectorOverview_onSettingsModified")
    
    local rect = lister:placeCenter(vec2(lister.inner.width, 25))
    local splitter = UIVerticalSplitter(rect, 10, 0, 0.65)
    local label = tab:createLabel(splitter.left, "Next tab (numpad)"%_t, 14)
    label:setLeftAligned()
    sectorOverview_nextTabBtnComboBox = tab:createValueComboBox(splitter.right, "sectorOverview_onSettingsModified")

    for _, v in ipairs(allowedKeys) do
        sectorOverview_toggleBtnComboBox:addEntry(v[1], v[2])
        sectorOverview_prevTabBtnComboBox:addEntry(v[1], v[2])
        sectorOverview_nextTabBtnComboBox:addEntry(v[1], v[2])
    end
    sectorOverview_toggleBtnComboBox:setSelectedValueNoCallback(SectorOverviewConfig.ToggleButton)
    sectorOverview_prevTabBtnComboBox:setSelectedValueNoCallback(SectorOverviewConfig.PrevTabButton)
    sectorOverview_nextTabBtnComboBox:setSelectedValueNoCallback(SectorOverviewConfig.NextTabButton)

    local rect = lister:placeCenter(vec2(lister.inner.width, 25))
    local splitter = UIVerticalSplitter(rect, 10, 0, 0.65)
    local label = tab:createLabel(splitter.left.lower, "Window width"%_t, 14)
    label:setLeftAligned()
    sectorOverview_windowWidthBox = tab:createTextBox(splitter.right, "")
    sectorOverview_windowWidthBox.allowedCharacters = "0123456789"
    sectorOverview_windowWidthBox.text = SectorOverviewConfig.WindowWidth
    sectorOverview_windowWidthBox.onTextChangedFunction = "sectorOverview_onSettingsModified"

    rect = lister:placeCenter(vec2(lister.inner.width, 25))
    splitter = UIVerticalSplitter(rect, 10, 0, 0.65)
    label = tab:createLabel(splitter.left.lower, "Window height"%_t, 14)
    label:setLeftAligned()
    sectorOverview_windowHeightBox = tab:createTextBox(splitter.right, "")
    sectorOverview_windowHeightBox.allowedCharacters = "0123456789"
    sectorOverview_windowHeightBox.text = SectorOverviewConfig.WindowHeight
    sectorOverview_windowHeightBox.onTextChangedFunction = "sectorOverview_onSettingsModified"

    rect = lister:placeCenter(vec2(lister.inner.width, 45))
    sectorOverview_notifyAboutEnemiesCheckBox = tab:createCheckBox(rect, "Notify - enemy players"%_t, "sectorOverview_onSettingsModified")
    sectorOverview_notifyAboutEnemiesCheckBox:setCheckedNoCallback(SectorOverviewConfig.NotifyAboutEnemies)

    rect = lister:placeCenter(vec2(lister.inner.width, 45))
    sectorOverview_showNPCNamesCheckBox = tab:createCheckBox(rect, "Show NPC names"%_t, "sectorOverview_onSettingsModified")
    sectorOverview_showNPCNamesCheckBox:setCheckedNoCallback(SectorOverviewConfig.ShowNPCNames)

    local button = tab:createButton(hsplit[2], "Reset"%_t, "sectorOverview_onResetBtnPressed")
    button.maxTextSize = 14

    -- callbacks
    Player():registerCallback("onStateChanged", "onPlayerStateChanged")

    self.show()
    self.hide()

    sectorOverview_refreshCounter = 0
    sectorOverview_settingsModified = 0
    sectorOverview_playerAddedList = {}
    sectorOverview_playerCoords = {}

    invokeServerFunction("sectorOverview_sendServerConfig")
    invokeServerFunction("sectorOverview_setNotifyAboutEnemies", SectorOverviewConfig.NotifyAboutEnemies)
end

function SectorShipOverview.getUpdateInterval() -- overridden
    return 0
end

function SectorShipOverview.updateClient(timeStep) -- overridden
    if not self.window then return end

    local keyboard = Keyboard()
    if SectorOverviewConfig.ToggleButton ~= "" and keyboard:keyDown(KeyboardKey[SectorOverviewConfig.ToggleButton]) then
        if self.window.visible then
            self.hide()
        else
            self.show()
        end
    end
    if self.window.visible then
        -- cycle tabs
        if SectorOverviewConfig.PrevTabButton ~= "" and keyboard:keyDown(KeyboardKey[SectorOverviewConfig.PrevTabButton]) then
            local pos = sectorOverview_tabbedWindow.activeTab._pos
            if pos == 1 then
                pos = #sectorOverview_tabbedWindow._tabs -- cycle to the end
            else
                pos = pos - 1
            end
            sectorOverview_tabbedWindow:selectTab(sectorOverview_tabbedWindow._tabs[pos])
        elseif SectorOverviewConfig.NextTabButton ~= "" and keyboard:keyDown(KeyboardKey[SectorOverviewConfig.NextTabButton]) then
            local pos = sectorOverview_tabbedWindow.activeTab._pos
            if pos == #sectorOverview_tabbedWindow._tabs then
                pos = 1 -- cycle to the start
            else
                pos = pos + 1
            end
            sectorOverview_tabbedWindow:selectTab(sectorOverview_tabbedWindow._tabs[pos])
        end
        -- update lists
        sectorOverview_refreshCounter = sectorOverview_refreshCounter + timeStep
        if sectorOverview_refreshCounter >= 1 then
            sectorOverview_refreshCounter = 0
            self.refreshList()
        end
    end
    if sectorOverview_settingsModified > 0 then
        sectorOverview_settingsModified = sectorOverview_settingsModified - timeStep
        if sectorOverview_settingsModified <= 0 then -- save config
            SectorOverviewConfig.WindowWidth = tonumber(sectorOverview_windowWidthBox.text) or 0
            if SectorOverviewConfig.WindowWidth < 320 or SectorOverviewConfig.WindowWidth > 800 then
                SectorOverviewConfig.WindowWidth = math.max(320, math.min(800, SectorOverviewConfig.WindowWidth))
                if not sectorOverview_windowWidthBox.isTypingActive then
                    sectorOverview_windowWidthBox.text = SectorOverviewConfig.WindowWidth
                end
            end
            SectorOverviewConfig.WindowHeight = tonumber(sectorOverview_windowHeightBox.text) or 0
            if SectorOverviewConfig.WindowHeight < 360 or SectorOverviewConfig.WindowHeight > 800 then
                SectorOverviewConfig.WindowHeight = math.max(360, math.min(800, SectorOverviewConfig.WindowHeight))
                if not sectorOverview_windowHeightBox.isTypingActive then
                    sectorOverview_windowHeightBox.text = SectorOverviewConfig.WindowHeight
                end
            end
            SectorOverviewConfig.NotifyAboutEnemies = sectorOverview_notifyAboutEnemiesCheckBox.checked
            SectorOverviewConfig.ShowNPCNames = sectorOverview_showNPCNamesCheckBox.checked
            SectorOverviewConfig.ToggleButton = sectorOverview_toggleBtnComboBox.selectedValue
            SectorOverviewConfig.PrevTabButton = sectorOverview_prevTabBtnComboBox.selectedValue
            SectorOverviewConfig.NextTabButton = sectorOverview_nextTabBtnComboBox.selectedValue

            Azimuth.saveConfig("SectorOverview", SectorOverviewConfig, sectorOverview_configOptions)

            invokeServerFunction("sectorOverview_setNotifyAboutEnemies", SectorOverviewConfig.NotifyAboutEnemies)
        end
    end
end

-- CALLABLE --

function SectorShipOverview.sectorOverview_receiveServerConfig(serverConfig)
    if not serverConfig.AllowPlayerTracking then
        sectorOverview_tabbedWindow:deactivateTab(sectorOverview_playerTab)
    end
end

function SectorShipOverview.sectorOverview_enemySpotted(entityIndex, secondAttempt)
    local entity = Sector():getEntity(entityIndex)
    if not entity or not valid(entity) then
        if not secondAttempt then -- try even later
            deferredCallback(1, "sectorOverview_enemySpotted", entityIndex, true)
        end
        return
    end
    local factionName = "?"
    if Galaxy():factionExists(entity.factionIndex) then
        factionName = Faction(entity.factionIndex).translatedName
    end
    displayChatMessage(string.format("Detected enemy ship '%s' (%s) in the sector!"%_t, entity.name, factionName), "Sector Overview"%_t, 2)
end

function SectorShipOverview.sectorOverview_receivePlayerCoord(data)
    for index, coord in pairs(data) do
        sectorOverview_playerCoords[index] = coord
    end
    self.sectorOverview_refreshPlayerList()
end

-- FUNCTIONS --

function SectorShipOverview.refreshList() -- overridden
    local craft = getPlayerCraft()
    if not craft then return end

    local white = ColorRGB(1, 1, 1)
    local player = Player()
    local ownerFaction = craft.allianceOwned and Alliance() or player
    local selectionGroups = sectorOverview_GT135 and self.getSelectionGroupTable(player) or nil
    local renderer = UIRenderer()
    local entities = {}

    local sort = function(entities)
        table.sort(entities, function(a, b)
            if a.entity.factionIndex == b.entity.factionIndex then
                if a.name == b.name then
                    return a.entity.id.string < b.entity.id.string
                end
                return a.name < b.name
            end
            return (a.entity.factionIndex or 0) < (b.entity.factionIndex or 0)
        end)
    end

    if sectorOverview_stationTab.isActiveTab then -- stations

        for _, entity in ipairs({Sector():getEntitiesByType(EntityType.Station)}) do
            entities[#entities+1] = {entity = entity, name = self.sectorOverview_getEntityName(entity)}
        end
        for _, entity in ipairs({Sector():getEntitiesByScript("data/scripts/entity/sellobject.lua")}) do
            entities[#entities+1] = {entity = entity, name = self.sectorOverview_getEntityName(entity, "Claimed Asteroid"%_t), isClaimed = true}
        end
        sort(entities)
        local selectedValue = sectorOverview_stationList.selectedValue
        sectorOverview_stationList:clear()
        for _, pair in ipairs(entities) do
            local entryColor
            if sectorOverview_GT135 then
                entryColor = renderer:getEntityTargeterColor(pair.entity)
            else
                entryColor = ownerFaction:getRelation(pair.entity.factionIndex).color -- Relation object
            end
            local icon = ""
            local secondaryIcon = ""
            local iconComponent = EntityIcon(pair.entity)
            if iconComponent then
                icon = iconComponent.icon
                secondaryIcon = iconComponent.secondaryIcon
            end
            if pair.isClaimed then
                icon = "data/textures/icons/pixel/credits.png"
            elseif icon == "" then
                icon = "data/textures/icons/sectoroverview/pixel/diamond.png"
            end
            local group = sectorOverview_GT135 and " "..self.getGroupString(selectionGroups, pair.entity.factionIndex, pair.entity.name) or ""
            sectorOverview_stationList:addRow(pair.entity.id.string)
            sectorOverview_stationList:setEntry(0, sectorOverview_stationList.rows - 1, icon, false, false, self.sectorOverview_getOwnershipTypeColor(pair.entity))
            sectorOverview_stationList:setEntry(1, sectorOverview_stationList.rows - 1, secondaryIcon, false, false, white)
            sectorOverview_stationList:setEntry(2, sectorOverview_stationList.rows - 1, pair.name, false, false, entryColor)
            sectorOverview_stationList:setEntry(3, sectorOverview_stationList.rows - 1, group, false, false, white)
            sectorOverview_stationList:setEntryType(0, sectorOverview_stationList.rows - 1, 3)
            sectorOverview_stationList:setEntryType(1, sectorOverview_stationList.rows - 1, 3)
        end
        sectorOverview_stationList:selectValueNoCallback(selectedValue)

    elseif sectorOverview_shipTab.isActiveTab then -- ships

        for _, entity in ipairs({Sector():getEntitiesByComponents(ComponentType.Engine)}) do
            if entity.isShip or entity.isDrone then
                entities[#entities+1] = {entity = entity, name = self.sectorOverview_getEntityName(entity)}
            end
        end
        sort(entities)
        local selectedValue = sectorOverview_shipList.selectedValue
        sectorOverview_shipList:clear()
        for _, pair in ipairs(entities) do
            local entryColor
            if sectorOverview_GT135 then
                entryColor = renderer:getEntityTargeterColor(pair.entity)
            else
                entryColor = ownerFaction:getRelation(pair.entity.factionIndex).color -- Relation object
            end
            local icon = ""
            local secondaryIcon = ""
            local iconComponent = EntityIcon(pair.entity)
            if iconComponent then
                if sectorOverview_GT135 and player.craftIndex == pair.entity.id then
                    icon = "data/textures/icons/pixel/player.png"
                else
                    icon = iconComponent.icon
                end
                secondaryIcon = iconComponent.secondaryIcon
            end
            if icon == "" then
                icon = "data/textures/icons/sectoroverview/pixel/diamond.png"
            end
            local group = sectorOverview_GT135 and " "..self.getGroupString(selectionGroups, pair.entity.factionIndex, pair.entity.name) or ""
            sectorOverview_shipList:addRow(pair.entity.id.string)
            sectorOverview_shipList:setEntry(0, sectorOverview_shipList.rows - 1, icon, false, false, self.sectorOverview_getOwnershipTypeColor(pair.entity))
            sectorOverview_shipList:setEntry(1, sectorOverview_shipList.rows - 1, secondaryIcon, false, false, white)
            sectorOverview_shipList:setEntry(2, sectorOverview_shipList.rows - 1, pair.name, false, false, entryColor)
            sectorOverview_shipList:setEntry(3, sectorOverview_shipList.rows - 1, group, false, false, white)
            sectorOverview_shipList:setEntryType(0, sectorOverview_shipList.rows - 1, 3)
            sectorOverview_shipList:setEntryType(1, sectorOverview_shipList.rows - 1, 3)
        end
        sectorOverview_shipList:selectValueNoCallback(selectedValue)

    elseif sectorOverview_gateTab.isActiveTab then -- gates

        for _, entity in ipairs({Sector():getEntitiesByComponents(ComponentType.WormHole)}) do
            local isGate = entity:hasComponent(ComponentType.Plan)
            entities[#entities+1] = {
              entity = entity,
              name = isGate and self.sectorOverview_getEntityName(entity) or "Wormhole"%_t,
              isGate = isGate
            }
        end
        sort(entities)
        local selectedValue = sectorOverview_gateList.selectedValue
        sectorOverview_gateList:clear()
        for _, pair in ipairs(entities) do
            local icon = ""
            local ownershipColor = white
            local entryColor = white
            if pair.isGate then
                ownershipColor = self.sectorOverview_getOwnershipTypeColor(pair.entity)
                if sectorOverview_GT135 then
                    entryColor = renderer:getEntityTargeterColor(pair.entity)
                else
                    entryColor = ownerFaction:getRelation(pair.entity.factionIndex).color
                end
                local iconComponent = EntityIcon(pair.entity)
                if iconComponent then
                    icon = iconComponent.icon
                end
            else
                icon = "data/textures/icons/sectoroverview/pixel/spiral.png"
            end
            sectorOverview_gateList:addRow(pair.entity.id.string)
            sectorOverview_gateList:setEntry(0, sectorOverview_gateList.rows - 1, icon, false, false, ownershipColor)
            sectorOverview_gateList:setEntry(1, sectorOverview_gateList.rows - 1, pair.name, false, false, entryColor)
            sectorOverview_gateList:setEntryType(0, sectorOverview_gateList.rows - 1, 3)
        end
        sectorOverview_gateList:selectValueNoCallback(selectedValue)

    end
end

if sectorOverview_GT135 then

local doubleClick = {}
function SectorShipOverview.onEntrySelected(index, value) -- overridden
    if not value or value == "" then return end

    local time = appTime()
    if doubleClick.value ~= value then
        doubleClick.value = value
        doubleClick.time = time
    else
        if time - doubleClick.time < 0.5 then
            if Player().state == PlayerStateType.Strategy then
                StrategyState():centerCameraOnSelection()
            end
        else
            doubleClick.time = time
        end
    end

    local player = Player()

    if Keyboard().controlPressed then
        StrategyState():toggleSelect(value)
        return
    end

    StrategyState():clearSelection()
    player.selectedObject = Entity(value)
end

end

function SectorShipOverview.sectorOverview_toggleWindow()
    if self.window.visible then
        self.hide()
    else
        self.show()
    end
end

function SectorShipOverview.sectorOverview_getOwnershipTypeColor(entity)
    local player = Player()
    local factionIndex = entity.factionIndex or -1
    if not entity.aiOwned then
        if factionIndex == player.index then
            return ColorInt(0xff4CE34B)
        elseif player.allianceIndex and factionIndex == player.allianceIndex then
            return ColorInt(0xffFF00FF)
        elseif entity.playerOwned then
            return ColorInt(0xffFCFF3A)
        else
            return ColorInt(0xff4B9EF2)
        end
    end
    return ColorRGB(1, 1, 1)
end

function SectorShipOverview.sectorOverview_getEntityName(entity, custom)
    local entryName = ""
    if custom then
        entryName = custom
    else
        if entity.translatedTitle and entity.translatedTitle ~= "" then
            entryName = entity.translatedTitle
        elseif entity.title and entity.title ~= "" then
            entryName = (entity.title % entity:getTitleArguments())
        end
        if entity.name and (entryName == "" or not entity.aiOwned or SectorOverviewConfig.ShowNPCNames) then
            if entryName == "" then
                entryName = entity.name
            else
                entryName = entryName.." - "..entity.name
            end
        end
    end
    if entryName == "" and not entity.name then
        entryName = "<No Name>"%_t
    end
    if Galaxy():factionExists(entity.factionIndex) then
        entryName = entryName .. " | " .. Faction(entity.factionIndex).translatedName
    else
        entryName = entryName .. " | " .. ("Not owned"%_t)
    end
    return entryName
end

function SectorShipOverview.sectorOverview_refreshPlayerList(updateAllCoordinates)
    local sorted = {}
    for name, index in pairs(sectorOverview_playerAddedList) do
        sorted[#sorted+1] = name
    end
    table.sort(sorted)

    local trackedPlayerIndexes = {}
    local white = ColorRGB(1, 1, 1)

    sectorOverview_playerList:clear()
    for _, name in ipairs(sorted) do
        local index = sectorOverview_playerAddedList[name]
        local coord = sectorOverview_playerCoords[index]
        sectorOverview_playerList:addRow(name)
        if coord then
            sectorOverview_playerList:setEntry(0, sectorOverview_playerList.rows-1, string.format("%s (%i:%i)", name, coord[1], coord[2]), false, false, white)
        else
            sectorOverview_playerList:setEntry(0, sectorOverview_playerList.rows-1, name, false, false, white)
        end
        
        trackedPlayerIndexes[#trackedPlayerIndexes+1] = index
    end

    if updateAllCoordinates and #trackedPlayerIndexes > 0 then
        invokeServerFunction("sectorOverview_sendPlayersCoord", trackedPlayerIndexes)
    end
end

-- CALLBACKS --

function SectorShipOverview.onPlayerStateChanged(new, old) -- overridden
    local isOldNormal = old == PlayerStateType.Fly or old == PlayerStateType.Interact
    local isNewNormal = new == PlayerStateType.Fly or new == PlayerStateType.Interact
    
    if isOldNormal and not isNewNormal then -- save status
        sectorOverview_isVisible = self.window.visible
        if new == PlayerStateType.Strategy then -- always show
            self.show()
        else -- always hide in build mode
            self.hide()
        end
    elseif not isOldNormal and isNewNormal then
        if sectorOverview_isVisible then
            self.show()
        else
            self.hide()
        end
    end
end

function SectorShipOverview.sectorOverview_onPlayerTabSelected(tab)
    -- fill player combo box
    sectorOverview_playerCombo:clear()
    local playerName = Player().name
    for index, name in pairs(Galaxy():getPlayerNames()) do
        if playerName ~= name then
            sectorOverview_playerCombo:addEntry(index, name)
        end
    end

    self.sectorOverview_refreshPlayerList(true)
end

function SectorShipOverview.sectorOverview_onShowPlayerPressed()
    local name = sectorOverview_playerList.selectedValue
    if name then
        local index = sectorOverview_playerAddedList[name]
        if index then
            local coords = sectorOverview_playerCoords[index]
            if coords then
                GalaxyMap():show(coords[1], coords[2])
            end
        end
    end
end

function SectorShipOverview.sectorOverview_onAddPlayerTracking()
    local name = sectorOverview_playerCombo.selectedEntry
    if name ~= "" and not sectorOverview_playerAddedList[name] then
        sectorOverview_playerAddedList[name] = sectorOverview_playerCombo.selectedValue
        self.sectorOverview_refreshPlayerList()
        invokeServerFunction("sectorOverview_sendPlayersCoord", sectorOverview_playerCombo.selectedValue)
    end
end

function SectorShipOverview.sectorOverview_onRemovePlayerTracking()
    local name = sectorOverview_playerList.selectedValue
    if name then
        local index = sectorOverview_playerAddedList[name]
        if index then
            sectorOverview_playerAddedList[name] = nil
            sectorOverview_playerCoords[index] = nil
            self.sectorOverview_refreshPlayerList()
        end
    end
end

function SectorShipOverview.sectorOverview_onSettingsModified()
    sectorOverview_settingsModified = 1
end

function SectorShipOverview.sectorOverview_onResetBtnPressed()
    SectorOverviewConfig.WindowWidth = sectorOverview_configOptions.WindowWidth.default
    sectorOverview_windowWidthBox.text = SectorOverviewConfig.WindowWidth

    SectorOverviewConfig.WindowHeight = sectorOverview_configOptions.WindowHeight.default
    sectorOverview_windowHeightBox.text = SectorOverviewConfig.WindowHeight

    SectorOverviewConfig.NotifyAboutEnemies = sectorOverview_configOptions.NotifyAboutEnemies.default
    sectorOverview_notifyAboutEnemiesCheckBox:setCheckedNoCallback(SectorOverviewConfig.NotifyAboutEnemies)

    SectorOverviewConfig.ShowNPCNames = sectorOverview_configOptions.ShowNPCNames.default
    sectorOverview_showNPCNamesCheckBox:setCheckedNoCallback(SectorOverviewConfig.ShowNPCNames)

    SectorOverviewConfig.ToggleButton = sectorOverview_configOptions.ToggleButton.default
    sectorOverview_toggleBtnComboBox:setSelectedValueNoCallback(SectorOverviewConfig.ToggleButton)

    SectorOverviewConfig.PrevTabButton = sectorOverview_configOptions.PrevTabButton.default
    sectorOverview_prevTabBtnComboBox:setSelectedValueNoCallback(SectorOverviewConfig.PrevTabButton)

    SectorOverviewConfig.NextTabButton = sectorOverview_configOptions.NextTabButton.default
    sectorOverview_nextTabBtnComboBox:setSelectedValueNoCallback(SectorOverviewConfig.NextTabButton)

    Azimuth.saveConfig("SectorOverview", SectorOverviewConfig, sectorOverview_configOptions)

    invokeServerFunction("sectorOverview_setNotifyAboutEnemies", SectorOverviewConfig.NotifyAboutEnemies)
end


else -- onServer


-- PREDEFINED --

function SectorShipOverview.initialize()
    local configOptions = {
      ["_version"] = {"1.1", comment = "Config version. Don't touch."},
      ["AllowPlayerTracking"] = {true, comment = "If false, server will not reveal players coordinates (useful for PvP servers)."}
    }
    local isModified
    SectorOverviewConfig, isModified = Azimuth.loadConfig("SectorOverview", configOptions)
    if isModified then
        Azimuth.saveConfig("SectorOverview", SectorOverviewConfig, configOptions)
    end

    Player():registerCallback("onSectorEntered", "sectorOverview_onSectorEntered")
end

-- CALLABLE --

function SectorShipOverview.sectorOverview_sendServerConfig()
    invokeClientFunction(Player(callingPlayer), "sectorOverview_receiveServerConfig", { AllowPlayerTracking = SectorOverviewConfig.AllowPlayerTracking })
end
callable(SectorShipOverview, "sectorOverview_sendServerConfig")

function SectorShipOverview.sectorOverview_setNotifyAboutEnemies(value)
    sectorOverview_notifyAboutEnemies = value
    self.sectorOverview_onSectorEntered()
end
callable(SectorShipOverview, "sectorOverview_setNotifyAboutEnemies")

function SectorShipOverview.sectorOverview_sendPlayersCoord(playerIndexes)
    local player = Player()
    if not SectorOverviewConfig.AllowPlayerTracking then
        player:sendChatMessage("", ChatMessageType.Error, "Server doesn't allow to track players."%_t)
        return
    end

    local typestr = type(playerIndexes)
    if typestr == "number" then
        playerIndexes = { playerIndexes }
    elseif typestr ~= "table" then
        return
    end

    local results = {}
    for _, v in ipairs(playerIndexes) do
        local otherPlayer = Player(v)
        if otherPlayer then
            results[v] = { otherPlayer:getSectorCoordinates() }
        else
            player:sendChatMessage("", ChatMessageType.Error, "Can't get coordinates, %s doesn't exist."%_t, otherPlayer.name)
        end
    end

    invokeClientFunction(player, "sectorOverview_receivePlayerCoord", results)
end
callable(SectorShipOverview, "sectorOverview_sendPlayersCoord")

-- CALLBACKS --

function SectorShipOverview.sectorOverview_onSectorEntered()
    if sectorOverview_notifyAboutEnemies then
        Sector():registerCallback("onEntityCreated", "sectorOverview_onEntityEntered")
        Sector():registerCallback("onEntityEntered", "sectorOverview_onEntityEntered")
    end
end

function SectorShipOverview.sectorOverview_onEntityEntered(entityIndex)
    if not sectorOverview_notifyAboutEnemies then return end

    local entity = Entity(entityIndex)
    if not entity.isShip or entity.isDrone or entity.aiOwned then return end

    local player = Player()
    if player:getRelationStatus(entity.factionIndex) == RelationStatus.War
      or (player.alliance and player.alliance:getRelationStatus(entity.factionIndex) == RelationStatus.War) then
        invokeClientFunction(player, "sectorOverview_enemySpotted", entityIndex)
    end
end


end