package.path = package.path .. ";data/scripts/lib/?.lua"

require("utility")
require("stringutility")


local entityList = nil
local gateList = nil
local tabMap = {}
local entities = {}
local isWindowShowing = false
local window = nil
local tabbedWindow = nil

function getIcon()
    return "data/textures/icons/computer.png"
end

-- if this function returns false, the script will not be listed in the interaction window,
-- even though its UI may be registered
function interactionPossible(playerIndex, option)
    if Entity().factionIndex == playerIndex then
        return true, ""
    end

    return false
end

-- create all required UI elements for the client side
function initUI()
    local res = getResolution()
    local size = vec2(300, 400)

    local menu = ScriptUI()
    window = menu:createWindow(Rect(res * 0.5 - size * 0.5, res * 0.5 + size * 0.5))
    menu:registerWindow(window, "Sector Overview"%_t)
    window.caption = "Sector Overview"%_t
    window.showCloseButton = 1
    window.moveable = 1

    -- create a tabbed window inside the main window
    tabbedWindow = window:createTabbedWindow(Rect(vec2(10, 10), size - 10))

    -- stations
    local buildTab = tabbedWindow:createTab("Build"%_t, "data/textures/icons/rss.png", "Station List"%_t)
    local hsplit = UIHorizontalSplitter(Rect(vec2(0, 0), tabbedWindow.size ), 10, 0, 0.5)
    hsplit.bottomSize = 40
    entityList = buildTab:createListBox(hsplit.top)
    tabMap[buildTab.index] = entityList

    -- ship
    local buildTab = tabbedWindow:createTab("Build"%_t, "data/textures/icons/vortex.png", "Gate List"%_t)
    local hsplit = UIHorizontalSplitter(Rect(vec2(0, 0), tabbedWindow.size ), 10, 0, 0.5)
    hsplit.bottomSize = 40
    gateList = buildTab:createListBox(hsplit.top)
    tabMap[buildTab.index] = gateList
end

function onShowWindow()
    entities = {}
    entityList:clear()
    gateList:clear()

    local player = Player()
    for index, entity in pairs({Sector():getEntities()}) do
      if (entity.type == EntityType.Station) then
        local titleArgs = entity:getTitleArguments()
        local title =  entity.title % titleArgs
        local entryName = title .. "    " .. entity.name 
        entityList:addEntry(entryName)
        entities[entryName] = entity
      end
      if (entity.title and string.match(entity.title, "Gate"))then
        local entryName = entity.title 
        gateList:addEntry(entryName)
        entities[entryName] = entity
      end
    end
    isWindowShowing = true
end

function onCloseWindow()
    isWindowShowing = false
end

function updateUI()
  if not isWindowShowing then
    return end

  if Mouse():mouseDown(1) then
    local tabIndex = tabbedWindow:getActiveTab().index
    local selectedEntry = tabMap[tabIndex]:getSelectedEntry()
    if (selectedEntry) then
      local entityToTarget = entities[selectedEntry];
      if (entityToTarget) then
        Player().selectedObject = entityToTarget
      end
    end
  end
end


