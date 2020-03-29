local sectorOverview_initialize -- client extended functions
local sectorOverview_data = {} -- client


if onClient() then


-- HELPERS --

function SectorShipOverview.getOwnershipTypeColor(entity)
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

function SectorShipOverview.getEntityName(entity)
    local entryName = ""
    if entity.translatedTitle and entity.translatedTitle ~= "" then
        entryName = entity.translatedTitle
    elseif entity.title and entity.title ~= "" then
        entryName = (entity.title % entity:getTitleArguments())
    end
    if entity.name and (entryName == "" or not entity.aiOwned) then
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

sectorOverview_initialize = SectorShipOverview.initialize
function SectorShipOverview.initialize(...)
    sectorOverview_initialize(...)

    self.list.columns = 3
    self.list:setColumnWidth(0, 25)
    self.list:setColumnWidth(1, 25)
    self.list:setColumnWidth(2, self.list.width - 60)
end

function SectorShipOverview.refreshList() -- overridden
    local player = Player()
    local sector = Sector()

    local stationList = {header = "Stations"%_t, entries = {}}
    local shipList = {header = "Ships"%_t, entries = {}}
    local gateList = {header = "Other"%_t, entries = {}}
    local lists = {stationList, shipList, gateList}


    -- collect stations
    local stations = {sector:getEntitiesByType(EntityType.Station)}
    for _, entity in ipairs(stations) do

        local name = SectorShipOverview.getEntityName(entity)
        local icon = ""
        local secondaryIcon = ""

        local iconComponent = EntityIcon(entity)
        if iconComponent then
            icon = iconComponent.icon
            secondaryIcon = iconComponent.secondaryIcon
        end
        if icon == "" then
            icon = "data/textures/icons/sectoroverview/pixel/diamond.png"
        end

        table.insert(stationList.entries, {entity = entity, icon = icon, secondaryIcon = secondaryIcon, name = name, faction = entity.factionIndex or 0})
    end

    -- collect ships
    local ships = {sector:getEntitiesByType(EntityType.Ship)}
    for _, entity in ipairs(ships) do

        local name = SectorShipOverview.getEntityName(entity)
        local icon = ""
        local secondaryIcon = ""

        local iconComponent = EntityIcon(entity)
        if iconComponent then
            icon = iconComponent.icon
            secondaryIcon = iconComponent.secondaryIcon
        end
        if icon == "" then
            icon = "data/textures/icons/sectoroverview/pixel/diamond.png"
        end

        table.insert(shipList.entries, {entity = entity, icon = icon, secondaryIcon = secondaryIcon, name = name, faction = entity.factionIndex or 0})
    end

    -- collect all other objects
    local gates = {sector:getEntitiesByComponent(ComponentType.WormHole)}
    for _, entity in ipairs(gates) do

        local name = ""
        local icon = ""
        local isWormhole

        if entity:hasComponent(ComponentType.Plan) then
            name = SectorShipOverview.getEntityName(entity)

            local iconComponent = EntityIcon(entity)
            if iconComponent then icon = iconComponent.icon end
        else
            name = "Wormhole"%_t
            icon = "data/textures/icons/sectoroverview/pixel/spiral.png"
            isWormhole = true
        end

        table.insert(gateList.entries, {entity = entity, icon = icon, name = name, faction = 0, isWormhole = isWormhole})
    end

    -- sort to make it easier to read
    for _, list in pairs(lists) do
        table.sort(list.entries, function(a, b)
            if a.faction == b.faction then
                if a.name == b.name then
                    return a.entity.id.string < b.entity.id.string
                end
                return a.name < b.name
            end
            return a.faction < b.faction
        end)
    end

    local selected = self.list.selectedValue
    local scrollPosition = self.list.scrollPosition

    self.list:clear()

    local white = ColorRGB(1, 1, 1)

    for _, list in pairs(lists) do
        if #list.entries > 0 then
            self.list:addRow(nil, "", "", "--- " .. list.header .. " ---")

            for _, entry in pairs(list.entries) do

                local entity = entry.entity

                local ownershipColor = white
                if not entry.isWormhole then
                    ownershipColor = SectorShipOverview.getOwnershipTypeColor(entity)
                end
                local relationColor = white
                if entity.factionIndex and entity.factionIndex > 0 then
                    local relation = player:getRelation(entity.factionIndex)

                    relationColor = relation.color
                end

                self.list:addRow(entity.id.string)
                self.list:setEntry(0, self.list.rows-1, entry.icon, false, false, ownershipColor)
                self.list:setEntry(1, self.list.rows-1, entry.secondaryIcon or "", false, false, white)
                self.list:setEntry(2, self.list.rows-1, entry.name, false, false, relationColor)

                self.list:setEntryType(0, self.list.rows-1, 3)
                self.list:setEntryType(1, self.list.rows-1, 3)
            end

            self.list:addRow()
        end
    end

    if player.selectedObject then
        self.list:selectValueNoCallback(player.selectedObject.string)
    end

    self.list.scrollPosition = scrollPosition
end

-- CUSTOM --

function SectorShipOverview.sectorOverview_setValue(key, value)
    sectorOverview_data[key] = value
end

function SectorShipOverview.sectorOverview_getValue(key)
    return sectorOverview_data[key]
end

function SectorShipOverview.sectorOverview_getValuem(...)
    local result = {}
    for _, key in ipairs({...}) do
        result[#result+1] = sectorOverview_data[key]
    end
    return unpack(result)
end


end