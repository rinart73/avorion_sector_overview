local config = {}
config.author = "Rinart73"
config.credits = "shulrak" -- For developing the original version of the mod
config.name = "Sector Overview"
config.version = {
    major = 1, minor = 0, patch = 0, -- 0.22
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
config.AllowPlayerTracking = true


return config