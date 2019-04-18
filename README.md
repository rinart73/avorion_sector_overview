# avorion_sector_overview
Mod for Avorion.
This is a sector overview mod, that shows stations and gates in the sector. You can also track other players coordinates on Galaxy Map.

## Installation
1. *Optionally install* [i18n - Internationalization](https://www.avorion.net/forum/index.php/topic,4330.0.html) if you want to use this mod in your language.
2. Unpack the mod archive in your Avorion folder, not in a `data` folder.
3. Open `data/scripts/entity/init.lua` and add the following code to the bottom of the file:
```
if not entity.aiOwned and (entity.isShip or entity.isStation or entity.isDrone) then entity:addScriptOnce("mods/SectorOverview/scripts/entity/sectoroverview.lua") end -- MOD: SectorOverview
```

More info in the [forum thread](https://www.avorion.net/forum/index.php?topic=5596).