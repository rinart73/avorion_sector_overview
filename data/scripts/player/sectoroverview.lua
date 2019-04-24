--[[
* Stores server settings on client so mod requests them only once
* Stores player tracking data between sectors
]]

if onServer() then return end

local data = {}

-- namespace SectorOverview
SectorOverview = {}

function SectorOverview.setValue(key, value)
    data[key] = value
end

function SectorOverview.getValue(key)
    return data[key]
end

function SectorOverview.getValues()
    return data
end