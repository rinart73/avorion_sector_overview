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
  WindowWidth = { default = 300, min = 200, max = 800, comment = "UI window width" },
  WindowHeight = { default = 400, min = 200, max = 800, comment = "UI window height" }
}
local config, isModified = Azimuth.loadConfig("SectorOverview", configOptions)
if isModified then
    Azimuth.saveConfig("SectorOverview", config, configOptions)
end

local window, tabbedWindow, stationList, gateList, playerTab, playerList, playerCombo, entities, playerSortedList
local listBoxes = {}
local playerAddedList = {}
local playerIndexMap = {}
local playerCoords = {}


function SectorOverview.getIcon()
    return "data/textures/icons/sectoroverview/icon.png"
end


function SectorOverview.interactionPossible(playerIndex, option)
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
    
    tabbedWindow = window:createTabbedWindow(Rect(vec2(10, 10), size - 10))

    -- stations
    local tab = tabbedWindow:createTab("Station List", "data/textures/icons/solar-system.png", "Station List"%_t)
    local hsplit = UIHorizontalSplitter(Rect(vec2(0, 0), tabbedWindow.size ), 10, 0, 0.5)
    hsplit.bottomSize = 40
    stationList = tab:createListBox(hsplit.top)
    stationList.onSelectFunction = "onEntityNameSelect"
    listBoxes[tab.index] = stationList
    
    -- gates
    tab = tabbedWindow:createTab("Gate List", "data/textures/icons/vortex.png", "Gate List"%_t)
    gateList = tab:createListBox(hsplit.top)
    gateList.onSelectFunction = "onEntityNameSelect"
    listBoxes[tab.index] = gateList
    
    -- players
    playerTab = tabbedWindow:createTab("Player List", "data/textures/icons/crew.png", "Player List"%_t)
    local showButton = playerTab:createButton(Rect(0, 0, tabbedWindow.width, 30), "Show on Galaxy Map"%_t, "onShowPlayerPressed")
    showButton.maxTextSize = 14
    showButton.tooltip = [[Show the selected player on the galaxy map.]]%_t

    hsplit = UIHorizontalSplitter(Rect(vec2(0, 40), tabbedWindow.size - vec2(0, 50) ), 10, 0, 0.5)
    hsplit.bottomSize = 65
    playerList = playerTab:createListBox(hsplit.top)
    listBoxes[playerTab.index] = playerList

    local hsplit = UIHorizontalSplitter(hsplit.bottom, 10, 0, 0.5)
    hsplit.bottomSize = 35

    playerCombo = playerTab:createComboBox(hsplit.top, "")

    local vsplit = UIVerticalSplitter(hsplit.bottom, 10, 0, 0.5)

    local button = playerTab:createButton(vsplit.left, "Add"%_t, "onAddPlayerTracking")
    button.maxTextSize = 14
    button.tooltip = "Add the selected player from the combo box to the list of tracked players."%_t
    button = playerTab:createButton(vsplit.right, "Remove"%_t, "onRemovePlayerTracking")
    button.maxTextSize = 14
    button.tooltip = "Remove the selected player from the list of tracked players."%_t
end

function SectorOverview.onShowWindow()
    entities = {}
    stationList:clear()
    gateList:clear()
    
    -- fill list for station and gates
    local entryName
    for index, entity in pairs({Sector():getEntities()}) do
        if entity.type == EntityType.Station then
            if entity.translatedTitle then
                entryName = entity.translatedTitle .. "    " .. entity.name
            else
                entryName = (entity.title % entity:getTitleArguments()) .. "    " .. entity.name
            end
            stationList:addEntry(entryName)
            entities[entryName] = entity
        end
        if entity.type == 0 and entity:hasScript("data/scripts/entity/gate.lua") then
            entryName = entity.title 
            gateList:addEntry(entryName)
            entities[entryName] = entity
        end
    end
    
    local player = Player()
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
    if not config.AllowPlayerTracking then return end
    Player():invokeFunction("azimuthlib-clientdata.lua", "setValue", "SectorOverview.playerTracking", {
      playerAddedList = playerAddedList,
      playerIndexMap = playerIndexMap,
      playerCoords = playerCoords,
      playerSortedList = playerSortedList
    })
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