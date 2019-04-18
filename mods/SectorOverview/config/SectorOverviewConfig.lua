local config = {}
config.author = "Rinart73"
config.credits = "shulrak" -- For developing the original version of the mod
config.name = "Sector Overview"
config.homepage = "https://www.avorion.net/forum/index.php?topic=5596"
config.version = {
    major = 0, minor = 4, patch = 0, -- 0.21.4
}
config.version.string = config.version.major..'.'..config.version.minor..'.'..config.version.patch


-- CLIENT SETTINGS --
-- Default: 300
config.WindowWidth = 300
-- Default: 400
config.WindowHeight = 400

-- SERVER SETTINGS --
-- If false, server will not reveal player coordinates (useful for PvP servers)
-- Default: true
config.AllowPlayerCoordinates = true


return config