if onServer then
    package.path = package.path .. ";data/scripts/player/?.lua"

    function initialize()
        Player():registerCallback("onSectorEntered", "enteredSector" )
    end

    function enteredSector()
        --Get the players index
        local sector = Sector()
        local ships = {sector:getEntitiesByType(EntityType.Ship)}
        --Get the players ship
        for _, ship in pairs(ships) do
            local faction = Faction(ship.factionIndex)
            if faction.isPlayer then
                if not ship:hasScript("data/scripts/entity/sectoroverview.lua") then
                    ship:addScriptOnce("data/scripts/entity/sectoroverview.lua")
                end
            end
        end
    end
end
