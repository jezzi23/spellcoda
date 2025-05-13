# SpellCoda
SpellCoda is an AddOn for World of Warcraft Classic and features a dynamic, configurable ability calculator. It implements many combat mechanics and makes use of thousands of spells and effects obtained from a custom generator (not contained in this repository, nor public at this time).

An external runner is scheduled to periodically try and fetch updated client data, generate the AddOn data for each supported client and commits (version tagged) to `release-autotagged` branch which creates a release build.

Any problems with the generated data, whether something is missing or needs modifying, can be handled in the client variation's respective `override.lua` file, e.g. `vanilla/override.lua`.

See the project page here: https://www.curseforge.com/wow/addons/spellcoda
