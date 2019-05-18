package.path = package.path .. ";data/scripts/lib/?.lua"
package.path = package.path .. ";data/scripts/player/?.lua"
include("utility")
include("stringutility")
include("callable")
local Azimuth = include("azimuthlib-basic")

-- namespace SectorOverview
SectorOverview = {}

if onClient() then -- CLIENT


local configOptions = {
  _version = { default = "1.1", comment = "Config version. Don't touch." },
  WindowWidth = { default = 300, min = 280, max = 800, format = "floor", comment = "UI window width" },
  WindowHeight = { default = 400, min = 200, max = 800, format = "floor", comment = "UI window height" },
  NotifyAboutEnemies = { default = true, comment = "If true, will notify when enemy player (< -40000) enters a sector." }
}
local config, isModified = Azimuth.loadConfig("SectorOverview", configOptions)
if isModified then
    Azimuth.saveConfig("SectorOverview", config, configOptions)
end

local window, tabbedWindow, stationList, gateList, shipList, playerTab, playerList, playerCombo, entities, playerSortedList
local windowWidthBox, windowHeightBox, notifyAboutEnemiesCheckBox
local settingsModified = false
local listBoxes = {}
local playerAddedList = {}
local playerIndexMap = {}
local playerCoords = {}
local ships = {}

local function relationsColor(value, moreGreen)
    if value >= 75000 then
        return moreGreen and ColorRGB(0.149, 0.898, 0.149) or ColorRGB(0.5764, 0.9529, 0.5725)
    end
    if value >= 55000 then
        local green = vec3(0.5764, 0.9529, 0.5725)
        if moreGreen then
            green = vec3(0.149, 0.898, 0.149)
        end
        local c = lerp(value, 55000, 75000, vec3(0.3764, 0.9411, 0.749), green)
        return ColorRGB(c.x, c.y, c.z)
    end
    if value >= 50000 then
        local c = lerp(value, 50000, 55000, vec3(0.447, 0.8705, 0.7764), vec3(0.3764, 0.9411, 0.749))
        return ColorRGB(c.x, c.y, c.z)
    end
    if value >= 40000 then
        local c = lerp(value, 40000, 50000, vec3(0.349, 0.8549, 0.8392), vec3(0.447, 0.8705, 0.7764))
        return ColorRGB(c.x, c.y, c.z)
    end
    if value >= 20000 then
        local c = lerp(value, 20000, 40000, vec3(0.6313, 0.7372, 0.8509), vec3(0.349, 0.8549, 0.8392))
        return ColorRGB(c.x, c.y, c.z)
    end
    if value >= 0 then
        local c = lerp(value, 0, 20000, vec3(0.5411, 0.4274, 0.749), vec3(0.6313, 0.7372, 0.8509))
        return ColorRGB(c.x, c.y, c.z)
    end
    if value >= -5000 then
        local c = lerp(value, -5000, 0, vec3(0.749, 0.6862, 0.596), vec3(0.5411, 0.4274, 0.749))
        return ColorRGB(c.x, c.y, c.z)
    end
    if value >= -15000 then
        local c = lerp(value, -15000, -5000, vec3(0.8705, 0.7411, 0.3686), vec3(0.749, 0.6862, 0.596))
        return ColorRGB(c.x, c.y, c.z)
    end
    if value >= -20000 then
        local c = lerp(value, -20000, -15000, vec3(0.745, 0.4156, 0.2431), vec3(0.8705, 0.7411, 0.3686))
        return ColorRGB(c.x, c.y, c.z)
    end
    local c = lerp(value, -75000, -20000, vec3(0.3254, 0.0745, 0.0666), vec3(0.745, 0.4156, 0.2431))
    return ColorRGB(c.x, c.y, c.z)
end

local function updateShipList()
    shipList:clear()
    local player = Player()
    local ship, factionIndex, relations, nameColor
    for _, shipName in ipairs(ships) do
        ship = entities[shipName]
        if valid(ship) then
            factionIndex = ship.factionIndex or -1
            relations = player:getRelations(factionIndex)
            nameColor = ColorRGB(1, 1, 1)
            if not ship.aiOwned then
                if factionIndex == player.index then
                    nameColor = ColorInt(0xff93F392)
                elseif factionIndex == player.allianceIndex then
                    nameColor = ColorInt(0xffB534B3)
                elseif ship.playerOwned then
                    nameColor = ColorInt(0xffF1F361)
                else
                    nameColor = ColorInt(0xff6666CC)
                end
            end
            shipList:addRow()
            shipList:setEntry(0, shipList.rows - 1, "█", false, false, relationsColor(relations, true))
            shipList:setEntry(1, shipList.rows - 1, shipName, false, false, nameColor)
        end
    end
end

local function getEntityName(entity)
    local entryName
    if entity.translatedTitle and entity.translatedTitle ~= "" then
        entryName = entity.translatedTitle .. " - " .. entity.name
    elseif entity.title and entity.title ~= "" then
        entryName = (entity.title % entity:getTitleArguments()) .. " - " .. entity.name
    else
        entryName = entity.name
    end
    if Galaxy():factionExists(entity.factionIndex) then
        entryName = entryName .. " | " .. Faction(entity.factionIndex).translatedName
    else
        entryName = entryName .. " | " .. ("Not owned"%_t)
    end
    return entryName
end

function SectorOverview.initialize()
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
    local _, clientData = Player():invokeFunction("azimuthlib-clientdata.lua", "getValue", "SectorOverview.config")
    if not clientData then
        Player():invokeFunction("azimuthlib-clientdata.lua", "setValue", "SectorOverview.config", {})
        invokeServerFunction("sendServerConfig")
    end

    local res = getResolution()
    local size = vec2(config.WindowWidth, config.WindowHeight)

    local menu = ScriptUI()
    window = menu:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5))
    menu:registerWindow(window, "Sector Overview"%_t)
    window.caption = "Sector Overview"%_t
    window.showCloseButton = 1
    window.moveable = 1
    
    local helpLabel = window:createLabel(Rect(size.x - 55, -29, size.x - 30, -10), "?", 15)
    helpLabel.tooltip =
[[Rectangles '█' near stations and ships names indicate relations with an owner faction.

Green object name means that ship/station belongs to you.
Purple - your alliance.
Yellow - other players.
Blue - other alliances.
White - NPC factions.]]%_t
    
    tabbedWindow = window:createTabbedWindow(Rect(vec2(10, 10), size - 10))

    -- stations
    local tab = tabbedWindow:createTab("Station List", "data/textures/icons/solar-system.png", "Station List"%_t)
    local hsplit = UIHorizontalSplitter(Rect(vec2(0, 0), tabbedWindow.size), 10, 0, 0.5)
    hsplit.bottomSize = 40
    stationList = tab:createListBoxEx(hsplit.top)
    stationList.columns = 2
    stationList:setColumnWidth(0, 15)
    stationList:setColumnWidth(1, hsplit.top.size.x - 25) -- additional 10px margin, otherwise text goes out of the listbox
    stationList.onSelectFunction = "onEntityExNameSelect"
    listBoxes[tab.index] = stationList
    
    -- ships
    tab = tabbedWindow:createTab("Ship List", "data/textures/icons/ship.png", "Ship List"%_t)
    shipList = tab:createListBoxEx(hsplit.top)
    shipList.columns = 2
    shipList:setColumnWidth(0, 15)
    shipList:setColumnWidth(1, hsplit.top.size.x - 25)
    shipList.onSelectFunction = "onEntityExNameSelect"
    listBoxes[tab.index] = shipList
    
    -- gates
    tab = tabbedWindow:createTab("Gate List", "data/textures/icons/vortex.png", "Gate List"%_t)
    gateList = tab:createListBoxEx(hsplit.top)
    gateList.columns = 2
    gateList:setColumnWidth(0, 15)
    gateList:setColumnWidth(1, hsplit.top.size.x - 25)
    gateList.onSelectFunction = "onEntityExNameSelect"
    listBoxes[tab.index] = gateList
    
    -- players
    playerTab = tabbedWindow:createTab("Player List", "data/textures/icons/crew.png", "Player List"%_t)
    local showButton = playerTab:createButton(Rect(0, 0, tabbedWindow.width, 30), "Show on Galaxy Map"%_t, "onShowPlayerPressed")
    showButton.maxTextSize = 14
    showButton.tooltip = [[Show the selected player on the galaxy map.]]%_t

    local hsplit2 = UIHorizontalSplitter(Rect(vec2(0, 40), tabbedWindow.size - vec2(0, 50) ), 10, 0, 0.5)
    hsplit2.bottomSize = 65
    playerList = playerTab:createListBox(hsplit2.top)
    listBoxes[playerTab.index] = playerList

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
    windowWidthBox.text = config.WindowWidth
    windowWidthBox.onTextChangedFunction = "onSettingsModified"
    -- window height
    rect = lister:placeCenter(vec2(lister.inner.width, 25))
    splitter = UIVerticalSplitter(rect, 10, 0, 0.65)
    tab:createLabel(splitter.left.lower + vec2(0, 3), "Window height"%_t, 14)
    windowHeightBox = tab:createTextBox(splitter.right, "")
    windowHeightBox.allowedCharacters = "0123456789"
    windowHeightBox.text = config.WindowHeight
    windowHeightBox.onTextChangedFunction = "onSettingsModified"
    -- notify about enemies
    rect = lister:placeCenter(vec2(lister.inner.width, 25))
    notifyAboutEnemiesCheckBox = tab:createCheckBox(rect, "Notify - enemy players"%_t, "onSettingsModified")
    notifyAboutEnemiesCheckBox:setCheckedNoCallback(config.NotifyAboutEnemies)
end

function SectorOverview.onShowWindow()
    entities = {}
    stationList:clear()
    gateList:clear()

    local player = Player()
    -- stations
    local entryName
    local stations = {}
    for _, station in ipairs({Sector():getEntitiesByType(EntityType.Station)}) do
        entryName = getEntityName(station)
        stations[#stations+1] = entryName
        entities[entryName] = station
    end
    table.sort(stations)
    local station, relations, factionIndex, nameColor
    for _, stationName in ipairs(stations) do
        station = entities[stationName]
        factionIndex = station.factionIndex or -1
        relations = player:getRelations(factionIndex)
        nameColor = ColorRGB(1, 1, 1)
        if not station.aiOwned then
            if factionIndex == player.index then
                nameColor = ColorInt(0xff93F392)
            elseif factionIndex == player.allianceIndex then
                nameColor = ColorInt(0xffB534B3)
            elseif station.playerOwned then
                nameColor = ColorInt(0xffF1F361)
            else
                nameColor = ColorInt(0xff6666CC)
            end
        end
        
        stationList:addRow()
        stationList:setEntry(0, stationList.rows - 1, "█", false, false, relationsColor(relations, true))
        stationList:setEntry(1, stationList.rows - 1, stationName, false, false, nameColor)
    end
    -- ships
    ships = {}
    for _, ship in ipairs({Sector():getEntitiesByComponents(ComponentType.Engine)}) do
        if ship.isShip or ship.isDrone then
            entryName = getEntityName(ship)
            ships[#ships+1] = entryName
            entities[entryName] = ship
        end
    end
    table.sort(ships)
    updateShipList()
    -- gates
    local gateName
    for _, gate in pairs({Sector():getEntitiesByScript("data/scripts/entity/gate.lua")}) do
        factionIndex = gate.factionIndex or -1
        relations = player:getRelations(factionIndex)
        nameColor = ColorRGB(1, 1, 1)
        if not gate.aiOwned then
            if factionIndex == player.index then
                nameColor = ColorInt(0xff93F392)
            elseif factionIndex == player.allianceIndex then
                nameColor = ColorInt(0xffB534B3)
            elseif gate.playerOwned then
                nameColor = ColorInt(0xffF1F361)
            else
                nameColor = ColorInt(0xff6666CC)
            end
        end
        gateName = gate.title
        if Galaxy():factionExists(factionIndex) then
            gateName = gateName .. " | " .. Faction(factionIndex).translatedName
        else
            gateName = gateName .. " | " .. ("Not owned"%_t)
        end
        
        entities[gate.title] = gate
        gateList:addRow()
        gateList:setEntry(0, gateList.rows - 1, "█", false, false, relationsColor(relations, true))
        gateList:setEntry(1, gateList.rows - 1, gateName, false, false, nameColor)
    end

    local status, serverConfig, playerTracking = player:invokeFunction("azimuthlib-clientdata.lua", "getValuem", "SectorOverview.config", "SectorOverview.playerTracking")
    if status == 0 and serverConfig then
        config.AllowPlayerTracking = serverConfig.AllowPlayerTracking
        if playerTracking then
            playerAddedList = playerTracking.playerAddedList or {}
            playerIndexMap = playerTracking.playerIndexMap or {}
            playerCoords = playerTracking.playerCoords or {}
            playerSortedList = playerTracking.playerSortedList or {}
        end
    end
    
    if config.AllowPlayerTracking then
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
    if config.AllowPlayerTracking then
        Player():invokeFunction("azimuthlib-clientdata.lua", "setValue", "SectorOverview.playerTracking", {
          playerAddedList = playerAddedList,
          playerIndexMap = playerIndexMap,
          playerCoords = playerCoords,
          playerSortedList = playerSortedList
        })
    end
    -- save config
    if settingsModified then
        -- width
        config.WindowWidth = tonumber(windowWidthBox.text) or 0
        if config.WindowWidth < 280 then config.WindowWidth = 280
        elseif config.WindowWidth > 800 then config.WindowWidth = 800 end
        windowWidthBox.text = config.WindowWidth
        -- height
        config.WindowHeight = tonumber(windowHeightBox.text) or 0
        if config.WindowHeight < 200 then config.WindowHeight = 200
        elseif config.WindowHeight > 800 then config.WindowHeight = 800 end
        windowHeightBox.text = config.WindowHeight
        -- notify about enemies
        config.NotifyAboutEnemies = notifyAboutEnemiesCheckBox.checked
        -- remove server settings
        config.AllowPlayerTracking = nil

        Azimuth.saveConfig("SectorOverview", config, configOptions)
        settingsModified = false
    end
end

function SectorOverview.update() -- for deferredCallback to work
end

function SectorOverview.onEntityEntered(entityIndex)
    deferredCallback(0.2, "deferredOnEntityEntered", entityIndex)
end

function SectorOverview.deferredOnEntityEntered(entityIndex)
    local entity = Entity(entityIndex)
    if not valid(entity) then return end
    local player = Player()
    -- notify
    if config.NotifyAboutEnemies and not entity.aiOwned and player:getRelations(entity.factionIndex) < -40000 then
        local factionName = "?"
        if Galaxy():factionExists(entity.factionIndex) then
            factionName = Faction(entity.factionIndex).translatedName
        end
        displayChatMessage(string.format("Detected enemy ship %s (%s) in the sector!"%_t, entity.name, factionName), "Sector Overview"%_t, 2)
    end
    -- add to ship list
    if window.visible then
        local entryName = getEntityName(entity)
        ships[#ships+1] = entryName
        entities[entryName] = entity
        table.sort(ships)
        updateShipList()
    end
end

function SectorOverview.onEntityLeft(entityIndex)
    local entity = Entity(entityIndex)
    if not valid(entity) or (not entity.isShip and not entity.isDrone) or not window or not window.visible then return end

    local entryName = getEntityName(entity)
    for i = 1, #ships do
        if ships[i] == entryName then
            table.remove(ships, i)
            break
        end
    end
    entities[entryName] = nil
    updateShipList()
end

function SectorOverview.onEntityExNameSelect(entryId)
    if entryId == -1 then return end -- when window opens, list box resets trigger callback too
    local tabIndex = tabbedWindow:getActiveTab().index
    local listBoxEx = listBoxes[tabIndex]
    local selectedEntry = listBoxEx:getEntry(1, listBoxEx.selected)
    local entity = entities[selectedEntry]
    if entity then
        Player().selectedObject = entity
    end
end

function SectorOverview.onEntityNameSelect(entryId)
    if entryId == -1 then return end -- when window opens, list box resets trigger callback too
    local tabIndex = tabbedWindow:getActiveTab().index
    local selectedEntry = listBoxes[tabIndex]:getSelectedEntry()
    local entity = entities[selectedEntry]
    if entity then
        Player().selectedObject = entity
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
    if not config.AllowPlayerTracking then return end

    local tabIndex = tabbedWindow:getActiveTab().index
    local selectedIndex = listBoxes[tabIndex].selected
    if selectedIndex then
        local selectedName = playerSortedList[selectedIndex+1]
        local coord = playerCoords[playerIndexMap[selectedName]]
        if coord then
            GalaxyMap():show(coord[1], coord[2])
        end
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

function SectorOverview.receiveServerConfig(serverConfig) -- called by server
    config.AllowPlayerTracking = serverConfig.AllowPlayerTracking
    Player():invokeFunction("azimuthlib-clientdata.lua", "setValue", "SectorOverview.config", { AllowPlayerTracking = serverConfig.AllowPlayerTracking })
end

function SectorOverview.receivePlayerCoord(data) -- called by server
    for pIndex, coord in pairs(data) do
        playerCoords[pIndex] = coord
    end
    SectorOverview.refreshPlayerList()
end


else -- SERVER


local configOptions = {
  _version = { default = "1.1", comment = "Config version. Don't touch." },
  AllowPlayerTracking = { default = true, comment = "If false, server will not reveal players coordinates (useful for PvP servers)." }
}
local config, isModified = Azimuth.loadConfig("SectorOverview", configOptions)
if isModified then
    Azimuth.saveConfig("SectorOverview", config, configOptions)
end

function SectorOverview.initialize()
    Sector():registerCallback("onEntityCreate", "onEntityEntered")
    Sector():registerCallback("onEntityEntered", "onEntityEntered")
end

function SectorOverview.onEntityEntered(entityIndex)
    local entity = Entity(entityIndex)
    if not entity.isShip or entity.isDrone then return end
    for _, playerIndex in pairs({Entity():getPilotIndices()}) do
        invokeClientFunction(Player(playerIndex), "onEntityEntered", entityIndex)
    end
end

function SectorOverview.sendServerConfig()
    invokeClientFunction(Player(callingPlayer), "receiveServerConfig", { AllowPlayerTracking = config.AllowPlayerTracking })
end
callable(SectorOverview, "sendServerConfig")

function SectorOverview.sendPlayersCoord(playerIndexes)
    local currentPlayer = Player(callingPlayer)
    if not config.AllowPlayerTracking then
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