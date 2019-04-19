--[[ This script is supposed to help modders to keep client side data between multiple entities and sectors within one game session.
For example: Instead of getting server settings for each entity in the every sector, you could just get it once and store it here. ]]

if onServer() then return end

-- Don't remove or alter the following comment, it tells the game the namespace this script lives in. If you remove it, the script will break.
-- namespace ClientData
ClientData = {}

function ClientData.setValue(key, value)
    ClientData[key] = value
end

function ClientData.getValue(key)
    return ClientData[key]
end