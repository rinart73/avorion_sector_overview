package.path = package.path .. ";data/scripts/lib/?.lua"
include("utility")
include("callable")
local Azimuth = include("azimuthlib-basic")

-- namespace SectorOverview
SectorOverview = {}

local Config -- client/server
local configOptions, settingsModified, playerAddedList, playerIndexMap, playerCoords -- client
local window, tabbedWindow, stationList, gateList, shipList, playerTab, playerList, playerCombo, playerSortedList, windowWidthBox, windowHeightBox, notifyAboutEnemiesCheckBox, showNPCNamesCheckBox -- client UI


if onClient() then


-- HELPERS --

function SectorOverview.getOwnershipTypeColor(entity)
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

function SectorOverview.updateShipList()
    local ships = {}
    for _, ship in ipairs({Sector():getEntitiesByComponents(ComponentType.Engine)}) do
        if ship.isShip or ship.isDrone then
            ships[#ships+1] = { ship = ship, name = SectorOverview.getEntityName(ship) }
        end
    end
    table.sort(ships, function(a, b)
        if a.ship.factionIndex == b.ship.factionIndex then
            if a.name == b.name then
                return a.ship.id.string < b.ship.id.string
            end
            return a.name < b.name
        end
        return a.ship.factionIndex < b.ship.factionIndex
    end)
    local selectedValue = shipList.selectedValue
    shipList:clear()
    local ownerFaction = Entity().allianceOwned and Alliance() or Player()
    for _, pair in ipairs(ships) do
        local relations = ownerFaction:getRelation(pair.ship.factionIndex) -- Relation object
        local icon = ""
        local iconComponent = EntityIcon(pair.ship)
        if iconComponent then
            icon = iconComponent.icon
        end
        if icon == "" then
            icon = "data/textures/icons/sectoroverview/pixel/diamond.png"
        end
        shipList:addRow(pair.ship.id.string)
        shipList:setEntry(0, shipList.rows - 1, icon, false, false, SectorOverview.getOwnershipTypeColor(pair.ship))
        shipList:setEntry(1, shipList.rows - 1, pair.name, false, false, relations.color)
        shipList:setEntryType(0, shipList.rows - 1, 3)
    end
    shipList:selectValueNoCallback(selectedValue)
end

function SectorOverview.getEntityName(entity)
    local entryName = ""
    if entity.translatedTitle and entity.translatedTitle ~= "" then
        entryName = entity.translatedTitle
    elseif entity.title and entity.title ~= "" then
        entryName = (entity.title % entity:getTitleArguments())
    end
    if entity.name and (entryName == "" or not entity.aiOwned or Config.ShowNPCNames) then
        if entryName == "" then
            entryName = entity.name
        else
            entryName = entryName.." - "..entity.name
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

-- PREDEFINED --

function SectorOverview.initialize()
    playerAddedList = {}
    playerIndexMap = {}
    playerCoords = {}

    configOptions = {
      _version = { default = "1.1", comment = "Config version. Don't touch." },
      WindowWidth = { default = 320, min = 320, max = 800, format = "floor", comment = "UI window width" },
      WindowHeight = { default = 400, min = 200, max = 800, format = "floor", comment = "UI window height" },
      NotifyAboutEnemies = { default = true, comment = "If true, will notify when enemy player (at war) enters a sector." },
      ShowNPCNames = { default = true, comment = "If true, sector overview will show unique NPC names in addition to their titles." }
    }
    local isModified
    Config, isModified = Azimuth.loadConfig("SectorOverview", configOptions)
    if Config.WindowWidth < 320 then
        Config.WindowWidth = 320
        isModified = true
    end
    if isModified then
        Azimuth.saveConfig("SectorOverview", Config, configOptions)
    end

    Sector():registerCallback("onEntityJump", "onEntityLeft")
    Sector():registerCallback("onDestroyed", "onEntityLeft")
end

function SectorOverview.getIcon()
    return "data/textures/icons/sectoroverview/icon.png"
end

function SectorOverview.interactionPossible(playerIndex)
    local player = Player(playerIndex)

    local craft = player.craft
    if craft == nil then return false end

    -- players can only use from the craft they are inside
    if craft.index == Entity().index then
        return true
    end

    return false
end

function SectorOverview.initUI()
    -- check if server settings are loaded/requested, if not - request them
    local _, clientData = Player():invokeFunction("sectorshipoverview.lua", "sectorOverview_getValue", "config")
    if not clientData then
        Player():invokeFunction("sectorshipoverview.lua", "sectorOverview_setValue", "config", {})
        invokeServerFunction("sendServerConfig")
    end

    local res = getResolution()
    local size = vec2(Config.WindowWidth, Config.WindowHeight)

    local menu = ScriptUI()
    window = menu:createWindow(Rect(vec2(res.x - size.x - 10, res.y * 0.5 - size.y * 0.5), vec2(res.x - 10, res.y * 0.5 + size.y * 0.5)))
    menu:registerWindow(window, "Sector Overview"%_t)
    window.caption = "Sector Overview"%_t
    window.showCloseButton = 1
    window.moveable = 1
    
    local helpLabel = window:createLabel(Rect(size.x - 55, -29, size.x - 30, -10), "?", 15)
    helpLabel.tooltip =
[[Colors of the object icons indicate ownership type:
* Green - yours.
* Purple - your alliance.
* Yellow - other player.
* Blue - other alliance.
* White - NPC.

Object name color represents relation status (war, ceasefire, neutral, allies)]]%_t
    
    tabbedWindow = window:createTabbedWindow(Rect(vec2(10, 10), size - 10))

    -- stations
    local tab = tabbedWindow:createTab("Station List", "data/textures/icons/solar-system.png", "Station List"%_t)
    local hsplit = UIHorizontalSplitter(Rect(vec2(0, 0), tabbedWindow.size), 10, 0, 0.5)
    hsplit.bottomSize = 40
    stationList = tab:createListBoxEx(hsplit.top)
    stationList.columns = 3
    stationList:setColumnWidth(0, 25)
    stationList:setColumnWidth(1, 25)
    stationList:setColumnWidth(2, stationList.width - 60)
    stationList.onSelectFunction = "onEntitySelect"
    
    -- ships
    tab = tabbedWindow:createTab("Ship List", "data/textures/icons/ship.png", "Ship List"%_t)
    shipList = tab:createListBoxEx(hsplit.top)
    shipList.columns = 2
    shipList:setColumnWidth(0, 25)
    shipList:setColumnWidth(1, shipList.width - 35)
    shipList.onSelectFunction = "onEntitySelect"
    
    -- gates
    tab = tabbedWindow:createTab("Gate List", "data/textures/icons/vortex.png", "Gate & Wormhole List"%_t)
    gateList = tab:createListBoxEx(hsplit.top)
    gateList.columns = 2
    gateList:setColumnWidth(0, 25)
    gateList:setColumnWidth(1, gateList.width - 35)
    gateList.onSelectFunction = "onEntitySelect"
    
    -- players
    playerTab = tabbedWindow:createTab("Player List", "data/textures/icons/crew.png", "Player List"%_t)
    local showButton = playerTab:createButton(Rect(0, 0, tabbedWindow.width, 30), "Show on Galaxy Map"%_t, "onShowPlayerPressed")
    showButton.maxTextSize = 14
    showButton.tooltip = [[Show the selected player on the galaxy map.]]%_t

    local hsplit2 = UIHorizontalSplitter(Rect(vec2(0, 40), tabbedWindow.size - vec2(0, 50) ), 10, 0, 0.5)
    hsplit2.bottomSize = 65
    playerList = playerTab:createListBox(hsplit2.top)

    hsplit2 = UIHorizontalSplitter(hsplit2.bottom, 10, 0, 0.5)
    hsplit2.bottomSize = 35

    playerCombo = playerTab:createComboBox(hsplit2.top, "")

    local vsplit = UIVerticalSplitter(hsplit2.bottom, 10, 0, 0.5)

    local button = playerTab:createButton(vsplit.left, "Add"%_t, "onAddPlayerTracking")
    button.maxTextSize = 14
    button.tooltip = "Add the selected player from the combo box to the list of tracked players."%_t
    button = playerTab:createButton(vsplit.right, "Remove"%_t, "onRemovePlayerTracking")
    button.maxTextSize = 14
    button.tooltip = "Remove the selected player from the list of tracked players."%_t
    
    -- settings
    tab = tabbedWindow:createTab("Settings", "data/textures/icons/gears.png", "Settings"%_t)
    local lister = UIVerticalLister(hsplit.top, 5, 0)
    -- window width
    local rect = lister:placeCenter(vec2(lister.inner.width, 25))
    local splitter = UIVerticalSplitter(rect, 10, 0, 0.65)
    tab:createLabel(splitter.left.lower + vec2(0, 3), "Window width"%_t, 14)
    windowWidthBox = tab:createTextBox(splitter.right, "")
    windowWidthBox.allowedCharacters = "0123456789"
    windowWidthBox.text = Config.WindowWidth
    windowWidthBox.onTextChangedFunction = "onSettingsModified"
    -- window height
    rect = lister:placeCenter(vec2(lister.inner.width, 25))
    splitter = UIVerticalSplitter(rect, 10, 0, 0.65)
    tab:createLabel(splitter.left.lower + vec2(0, 3), "Window height"%_t, 14)
    windowHeightBox = tab:createTextBox(splitter.right, "")
    windowHeightBox.allowedCharacters = "0123456789"
    windowHeightBox.text = Config.WindowHeight
    windowHeightBox.onTextChangedFunction = "onSettingsModified"
    -- notify about enemies
    rect = lister:placeCenter(vec2(lister.inner.width, 45))
    notifyAboutEnemiesCheckBox = tab:createCheckBox(rect, "Notify - enemy players"%_t, "onSettingsModified")
    notifyAboutEnemiesCheckBox:setCheckedNoCallback(Config.NotifyAboutEnemies)
    rect = lister:placeCenter(vec2(lister.inner.width, 45))
    showNPCNamesCheckBox = tab:createCheckBox(rect, "Show NPC names"%_t, "onSettingsModified")
    showNPCNamesCheckBox:setCheckedNoCallback(Config.ShowNPCNames)
end

function SectorOverview.onShowWindow()
    local white = ColorRGB(1, 1, 1)
    local ownerFaction = Entity().allianceOwned and Alliance() or Player()
    -- stations
    local stations = {}
    for _, station in ipairs({Sector():getEntitiesByType(EntityType.Station)}) do
        stations[#stations+1] = { station = station, name = SectorOverview.getEntityName(station) }
    end
    table.sort(stations, function(a, b)
        if a.station.factionIndex == b.station.factionIndex then
            if a.name == b.name then
                return a.station.id.string < b.station.id.string
            end
            return a.name < b.name
        end
        return a.station.factionIndex < b.station.factionIndex
    end)
    local selectedValue = stationList.selectedValue
    stationList:clear()
    for _, pair in ipairs(stations) do
        local relations = ownerFaction:getRelation(pair.station.factionIndex) -- Relation object
        local icon = ""
        local secondaryIcon = ""
        local iconComponent = EntityIcon(pair.station)
        if iconComponent then
            icon = iconComponent.icon
            secondaryIcon = iconComponent.secondaryIcon
        end
        if icon == "" then
            icon = "data/textures/icons/sectoroverview/pixel/diamond.png"
        end
        stationList:addRow(pair.station.id.string)
        stationList:setEntry(0, stationList.rows - 1, icon, false, false, SectorOverview.getOwnershipTypeColor(pair.station))
        stationList:setEntry(1, stationList.rows - 1, secondaryIcon, false, false, white)
        stationList:setEntry(2, stationList.rows - 1, pair.name, false, false, relations.color)
        stationList:setEntryType(0, stationList.rows - 1, 3)
        stationList:setEntryType(1, stationList.rows - 1, 3)
    end
    stationList:selectValueNoCallback(selectedValue)
    -- ships
    SectorOverview.updateShipList()
    -- gates
    selectedValue = gateList.selectedValue
    gateList:clear()
    for _, entity in ipairs({Sector():getEntitiesByComponent(ComponentType.WormHole)}) do
        local name = ""
        local icon = ""
        local ownershipColor = white
        local relationsColor = white
        if entity:hasComponent(ComponentType.Plan) then
            name = SectorOverview.getEntityName(entity)
            local relations = ownerFaction:getRelation(entity.factionIndex) -- Relation object
            ownershipColor = SectorOverview.getOwnershipTypeColor(entity)
            relationsColor = relations.color
            local iconComponent = EntityIcon(entity)
            if iconComponent then
                icon = iconComponent.icon
            end
        else
            name = "Wormhole"%_t
            icon = "data/textures/icons/sectoroverview/pixel/spiral.png"
        end
        gateList:addRow(entity.id.string)
        gateList:setEntry(0, gateList.rows - 1, icon, false, false, ownershipColor)
        gateList:setEntry(1, gateList.rows - 1, name, false, false, relationsColor)
        gateList:setEntryType(0, gateList.rows - 1, 3)
    end
    gateList:selectValueNoCallback(selectedValue)

    local player = Player()
    local status, serverConfig, playerTracking = player:invokeFunction("sectorshipoverview.lua", "sectorOverview_getValuem", "config", "playerTracking")
    if status == 0 and serverConfig then
        Config.AllowPlayerTracking = serverConfig.AllowPlayerTracking
        if playerTracking then
            playerAddedList = playerTracking.playerAddedList or {}
            playerIndexMap = playerTracking.playerIndexMap or {}
            playerCoords = playerTracking.playerCoords or {}
            playerSortedList = playerTracking.playerSortedList or {}
        end
    end
    
    if Config.AllowPlayerTracking then
        playerList:clear()
        playerCombo:clear()
    
        -- fill player combo box
        for index, name in pairs(Galaxy():getPlayerNames()) do
            if player.name:lower() ~= name:lower() then
                playerCombo:addEntry(name)
                playerIndexMap[name] = index
            end
        end

        SectorOverview.refreshPlayerList(true)
    else
        tabbedWindow:deactivateTab(playerTab)
    end
end

function SectorOverview.onCloseWindow()
    if Config.AllowPlayerTracking then
        Player():invokeFunction("sectorshipoverview.lua", "sectorOverview_setValue", "playerTracking", {
          playerAddedList = playerAddedList,
          playerIndexMap = playerIndexMap,
          playerCoords = playerCoords,
          playerSortedList = playerSortedList
        })
    end
    -- save Config
    if settingsModified then
        -- width
        Config.WindowWidth = tonumber(windowWidthBox.text) or 0
        if Config.WindowWidth < 280 then Config.WindowWidth = 280
        elseif Config.WindowWidth > 800 then Config.WindowWidth = 800 end
        windowWidthBox.text = Config.WindowWidth
        -- height
        Config.WindowHeight = tonumber(windowHeightBox.text) or 0
        if Config.WindowHeight < 200 then Config.WindowHeight = 200
        elseif Config.WindowHeight > 800 then Config.WindowHeight = 800 end
        windowHeightBox.text = Config.WindowHeight
        -- notify about enemies
        Config.NotifyAboutEnemies = notifyAboutEnemiesCheckBox.checked
        Config.ShowNPCNames = showNPCNamesCheckBox.checked
        -- remove server settings
        Config.AllowPlayerTracking = nil

        Azimuth.saveConfig("SectorOverview", Config, configOptions)
        settingsModified = false
    end
end

-- CALLABLE --

function SectorOverview.onEntityEntered(entityIndex)
    deferredCallback(0.2, "deferredOnEntityEntered", entityIndex)
end

function SectorOverview.receiveServerConfig(serverConfig) -- called by server
    Config.AllowPlayerTracking = serverConfig.AllowPlayerTracking
    Player():invokeFunction("sectorshipoverview.lua", "sectorOverview_setValue", "config", { AllowPlayerTracking = serverConfig.AllowPlayerTracking })
end

function SectorOverview.receivePlayerCoord(data) -- called by server
    for pIndex, coord in pairs(data) do
        playerCoords[pIndex] = coord
    end
    SectorOverview.refreshPlayerList()
end

-- FUNCTIONS --

function SectorOverview.deferredOnEntityEntered(entityIndex, secondAttempt)
    local entity = Sector():getEntity(entityIndex)
    if not entity or not valid(entity) then
        if not secondAttempt then -- try even later
            deferredCallback(1, "deferredOnEntityEntered", entityIndex, true)
        end
        return
    end
    local player = Player()
    -- notify
    if Config.NotifyAboutEnemies and not entity.aiOwned
      and (player:getRelationStatus(entity.factionIndex) == RelationStatus.War or (player.alliance and player.alliance:getRelationStatus(entity.factionIndex) == RelationStatus.War)) then
        local factionName = "?"
        if Galaxy():factionExists(entity.factionIndex) then
            factionName = Faction(entity.factionIndex).translatedName
        end
        displayChatMessage(string.format("Detected enemy ship '%s' (%s) in the sector!"%_t, entity.name, factionName), "Sector Overview"%_t, 2)
    end
    -- add to ship list
    if window.visible then
        SectorOverview.updateShipList()
    end
end

function SectorOverview.refreshPlayerList(refreshCoordinates)
    playerList:clear()
    playerSortedList = {}
    for name, isInList in pairs(playerAddedList) do
        if isInList then
            playerSortedList[#playerSortedList+1] = name
        end
    end

    table.sort(playerSortedList)
    local pIndex, coord
    local trackedPlayerIndexes = {}
    for _, name in ipairs(playerSortedList) do
        pIndex = playerIndexMap[name]
        coord = playerCoords[pIndex]
        if coord then
            playerList:addEntry(string.format("%s (%i:%i)", name, coord[1], coord[2]))
        else
            playerList:addEntry(name)
        end
        
        trackedPlayerIndexes[#trackedPlayerIndexes+1] = pIndex
    end
    
    if refreshCoordinates and #trackedPlayerIndexes > 0 then
        invokeServerFunction("sendPlayersCoord", trackedPlayerIndexes)
    end
end

-- CALLBACKS --

function SectorOverview.onEntityLeft(entityIndex)
    local entity = Entity(entityIndex)
    if not valid(entity) or (not entity.isShip and not entity.isDrone) or not window or not window.visible then return end

    SectorOverview.updateShipList()
end

function SectorOverview.onEntitySelect(index, value)
    if index == -1 then return end -- when window opens, list box resets trigger callback too
    if value and value ~= "" then
        Player().selectedObject = Entity(value)
    end
end

function SectorOverview.onSettingsModified()
    settingsModified = true
end

function SectorOverview.onAddPlayerTracking()
    local name = playerCombo.selectedEntry
    if name ~= "" and not playerAddedList[name] then
        playerList:addEntry(name)
        playerAddedList[name] = true
        SectorOverview.refreshPlayerList()
        invokeServerFunction("sendPlayersCoord", playerIndexMap[name])
    end
end

function SectorOverview.onRemovePlayerTracking()
    local selectedIndex = playerList.selected
    if selectedIndex then
        local name = playerSortedList[selectedIndex+1]
        if playerAddedList[name] then
            playerAddedList[name] = nil 
            SectorOverview.refreshPlayerList()
        end
    end
end

function SectorOverview.onShowPlayerPressed()
    if not Config.AllowPlayerTracking then return end

    local selectedIndex = playerList.selected
    if selectedIndex then
        local selectedName = playerSortedList[selectedIndex+1]
        local coord = playerCoords[playerIndexMap[selectedName]]
        if coord then
            GalaxyMap():show(coord[1], coord[2])
        end
    end
end


else -- onServer


-- PREDEFINED --

function SectorOverview.initialize()
    local configOptions = {
      _version = { default = "1.1", comment = "Config version. Don't touch." },
      AllowPlayerTracking = { default = true, comment = "If false, server will not reveal players coordinates (useful for PvP servers)." }
    }
    local isModified
    Config, isModified = Azimuth.loadConfig("SectorOverview", configOptions)
    if isModified then
        Azimuth.saveConfig("SectorOverview", Config, configOptions)
    end

    Sector():registerCallback("onEntityCreated", "onEntityEntered")
    Sector():registerCallback("onEntityEntered", "onEntityEntered")
end

-- CALLBACKS --

function SectorOverview.onEntityEntered(entityIndex)
    local entity = Entity(entityIndex)
    if not entity.isShip or entity.isDrone then return end

    for _, playerIndex in pairs({Entity():getPilotIndices()}) do
        invokeClientFunction(Player(playerIndex), "onEntityEntered", entityIndex)
    end
end

-- CALLABLE --

function SectorOverview.sendServerConfig()
    invokeClientFunction(Player(callingPlayer), "receiveServerConfig", { AllowPlayerTracking = Config.AllowPlayerTracking })
end
callable(SectorOverview, "sendServerConfig")

function SectorOverview.sendPlayersCoord(playerIndexes)
    local currentPlayer = Player(callingPlayer)
    if not Config.AllowPlayerTracking then
        currentPlayer:sendChatMessage("", ChatMessageType.Error, "Server doesn't allow to track players."%_t)
        return
    end

    local typestr = type(playerIndexes)
    if typestr == "number" then
        playerIndexes = { playerIndexes }
    elseif typestr ~= "table" then
        return
    end
    local results = {}
    
    local otherPlayer, px, py
    for i = 1, #playerIndexes do
        otherPlayer = Player(playerIndexes[i])
        if otherPlayer then
            results[playerIndexes[i]] = { otherPlayer:getSectorCoordinates() }
        else
            currentPlayer:sendChatMessage("", ChatMessageType.Error, "Can't get coordinates, %s doesn't exist."%_t, otherPlayer.name)
        end
    end
    
    invokeClientFunction(currentPlayer, "receivePlayerCoord", results)
end
callable(SectorOverview, "sendPlayersCoord")


end