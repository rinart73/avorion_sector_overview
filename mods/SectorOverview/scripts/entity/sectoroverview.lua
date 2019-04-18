package.path = package.path .. ";data/scripts/lib/?.lua"
require("utility")
require("stringutility")

if i18n then i18n.registerMod("SectorOverview") end

local status, config = pcall(require, 'mods/SectorOverview/config/SectorOverviewConfig')
if not status then
    eprint("[ERROR][SectorOverview]: Couldn't load config, using default settings")
    config = { WindowWidth = 300, WindowHeight = 400, AllowPlayerCoordinates = true }
end

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace SectorOverview
SectorOverview = {}

local stationList
local gateList
local playerList
local tabMap = {}
local playerTab
local entities = {}
local playerAddedList = {}
local isWindowShowing = false
local window
local tabbedWindow
local playerTabIndex
local playerIndexMap = {}
local playerCombo
local playerCoords = {}
local playerSortedList


if onClient() then -- CLIENT


function SectorOverview.initialize()
    invokeServerFunction("sendServerConfig")
end

function SectorOverview.getIcon()
    return "data/textures/icons/sector.png"
end

-- if this function returns false, the script will not be listed in the interaction window,
-- even though its UI may be registered
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

-- create all required UI elements for the client side
function SectorOverview.initUI()
    local res = getResolution()
    local size = vec2(config.WindowWidth, config.WindowHeight)

    local menu = ScriptUI()
    window = menu:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5))
    menu:registerWindow(window, "Sector Overview"%_t)
    window.caption = "Sector Overview"%_t
    window.showCloseButton = 1
    window.moveable = 1

    -- create a tabbed window inside the main window
    tabbedWindow = window:createTabbedWindow(Rect(vec2(10, 10), size - 10))

    -- stations
    local buildTab = tabbedWindow:createTab("Station List", "data/textures/icons/solar-system.png", "Station List"%_t)
    local hsplit = UIHorizontalSplitter(Rect(vec2(0, 0), tabbedWindow.size ), 10, 0, 0.5)
    hsplit.bottomSize = 40
    stationList = buildTab:createListBox(hsplit.top)
    tabMap[buildTab.index] = stationList

    -- ship
    local buildTab = tabbedWindow:createTab("Gate List", "data/textures/icons/vortex.png", "Gate List"%_t)
    local hsplit = UIHorizontalSplitter(Rect(vec2(0, 0), tabbedWindow.size ), 10, 0, 0.5)
    hsplit.bottomSize = 40
    gateList = buildTab:createListBox(hsplit.top)
    tabMap[buildTab.index] = gateList

    -- Players
    if config.AllowPlayerCoordinates then
        local buildTab = tabbedWindow:createTab("Player List", "data/textures/icons/crew.png", "Player List"%_t)
        local showButton = buildTab:createButton(Rect(0, 0, tabbedWindow.width, 30), "Show on Galaxy Map"%_t, "onShowPlayerPressed")
        showButton.maxTextSize = 14
        showButton.tooltip = [[Show the selected player on the galaxy map.]]%_t

        local hsplit = UIHorizontalSplitter(Rect(vec2(0, 40), tabbedWindow.size - vec2(0, 50) ), 10, 0, 0.5)
        hsplit.bottomSize = 65
        playerList = buildTab:createListBox(hsplit.top)
        tabMap[buildTab.index] = playerList 
        playerTabIndex = buildTab.index

        local hsplit = UIHorizontalSplitter(hsplit.bottom, 10, 0, 0.5)
        hsplit.bottomSize = 35

        playerCombo = buildTab:createComboBox(hsplit.top, "")

        local vsplit = UIVerticalSplitter(hsplit.bottom, 10, 0, 0.5)

        addScriptButton = buildTab:createButton(vsplit.left, "Add"%_t, "onAddPlayerToGroupPressed")
        addScriptButton.maxTextSize = 14
        addScriptButton.tooltip = 
            [[Add the selected player from the combo box to the list of tracked players.]]%_t
        removeScriptButton = buildTab:createButton(vsplit.right, "Remove"%_t, "onRemovePlayerFromGroupPressed")
        removeScriptButton.maxTextSize = 14
        removeScriptButton.tooltip =
            [[Remove the selected player from the list of tracked players.]]%_t
    end
end

function SectorOverview.refreshPlayerList(refreshCoordinates)
    -- small hack to keep the order of the players consistent on the screen
    playerList:clear()
    playerSortedList = {}
    for name, isInList in pairs(playerAddedList) do
        if (isInList) then
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
        invokeServerFunction("sendPlayerCoord", trackedPlayerIndexes)
    end
end

function SectorOverview.onAddPlayerToGroupPressed()
    local name = playerCombo.selectedEntry
    if (name ~= "" and not playerAddedList[name]) then
        playerList:addEntry(name)
        playerAddedList[name] = true
        SectorOverview.refreshPlayerList()
        invokeServerFunction("sendPlayerCoord", playerIndexMap[name])
    end
end

function SectorOverview.onRemovePlayerFromGroupPressed()
    local selectedIndex = playerList.selected
    if selectedIndex then
        local name = playerSortedList[selectedIndex+1]
        if (playerAddedList[name]) then
            playerAddedList[name] = nil 
            SectorOverview.refreshPlayerList()
            entity:invokeFunction("mods/SectorOverview/scripts/entity/sectoroverview.lua", "clientSyncEntities", playerAddedList, playerIndexMap, playerSortedList, playerCoords)
        end
    end
end

function SectorOverview.onShowPlayerPressed()
    if not config.AllowPlayerCoordinates then return end

    local tabIndex = tabbedWindow:getActiveTab().index
    local selectedIndex = tabMap[tabIndex].selected
    if selectedIndex then
        local selectedName = playerSortedList[selectedIndex+1]
        local coord = playerCoords[playerIndexMap[selectedName]]
        if coord then
            GalaxyMap():show(coord[1], coord[2])
        end
    end
end

function SectorOverview.onShowWindow()
    entities = {}
    stationList:clear()
    gateList:clear()
    
    if config.AllowPlayerCoordinates then
        playerList:clear()
        playerCombo:clear()

        -- fill list for station and gates
        local player = Player()
        for index, entity in pairs({Sector():getEntities()}) do
            if (entity.type == EntityType.Station) then
                local entryName
                if entity.translatedTitle then
                    entryName = entity.translatedTitle .. "    " .. entity.name
                else
                    local titleArgs = entity:getTitleArguments()
                    local title =  entity.title % titleArgs
                    entryName = title .. "    " .. entity.name
                end
                stationList:addEntry(entryName)
                entities[entryName] = entity
            end
            if (entity.type == 0 and entity:hasScript("data/scripts/entity/gate.lua")) then
                local entryName = entity.title 
                gateList:addEntry(entryName)
                entities[entryName] = entity
            end
        end

        -- fill player combo box
        for index, name in pairs(Galaxy():getPlayerNames()) do
            if player.name:lower() ~= name:lower() then
                playerCombo:addEntry(name)
                playerIndexMap[name] = index
            end
        end

        SectorOverview.refreshPlayerList(true)
    end

    isWindowShowing = true
end

function SectorOverview.onCloseWindow()
    isWindowShowing = false
end

function SectorOverview.receivePlayerCoord(data)
    for pIndex, coord in pairs(data) do
        playerCoords[pIndex] = coord
    end
    SectorOverview.refreshPlayerList()
    -- Pass playerlist to the other entities
    local index = Entity().index
    local entities = {Sector():getEntitiesByComponent(ComponentType.ShipAI)}
    local entity
    for i = 1, #entities do
        entity = entities[i]
        if not entity.aiOwned and (entity.isShip or entity.isStation or entity.isDrone) and entity.index ~= index then
            entity:invokeFunction("mods/SectorOverview/scripts/entity/sectoroverview.lua", "clientSyncEntities", playerAddedList, playerIndexMap, playerSortedList, playerCoords)
        end
    end
end

function SectorOverview.updateUI()
    if not isWindowShowing then
        return end

    if Mouse():mouseDown(1) then
        local tabIndex = tabbedWindow:getActiveTab().index
        local selectedEntry = tabMap[tabIndex]:getSelectedEntry()
        if (selectedEntry) then
            if (tabIndex == playerTabIndex) then
                return
            end
            local entityToTarget = entities[selectedEntry];
            if (entityToTarget) then
                Player().selectedObject = entityToTarget
            end
        end
    end
end

function SectorOverview.receiveServerConfig(serverConfig)
    config.AllowPlayerCoordinates = serverConfig.AllowPlayerCoordinates
    if not config.AllowPlayerCoordinates and tabbedWindow then
        tabbedWindow:deactivateTab(tabbedWindow:getTab("Player List"))
    end
end

-- Sync data between entities
function SectorOverview.clientSyncEntities(otherPlayerAddedList, otherPlayerIndexMap, otherPlayerSortedList, otherplayerCoords)
    playerAddedList = otherPlayerAddedList
    playerIndexMap = otherPlayerIndexMap
    playerSortedList = otherPlayerSortedList
    playerCoords = otherplayerCoords
end


else -- SERVER


function SectorOverview.sendServerConfig()
    invokeClientFunction(Player(callingPlayer), "receiveServerConfig", { AllowPlayerCoordinates = config.AllowPlayerCoordinates })
end

function SectorOverview.sendPlayerCoord(playerIndexes)
    local currentPlayer = Player(callingPlayer)
    if not config.AllowPlayerCoordinates then
        currentPlayer:sendChatMessage("Sector Overview"%_t, ChatMessageType.Error, "Server doesn't allow to get player coordinates")
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
            currentPlayer:sendChatMessage("Sector Overview"%_t, ChatMessageType.Error, "Can't get coordinate, " .. otherPlayer.name .. " doesn't exist ?")
        end
    end
    
    invokeClientFunction(currentPlayer, "receivePlayerCoord", results)
end

callable(SectorOverview, "sendServerConfig")
callable(SectorOverview, "sendPlayerCoord")


end