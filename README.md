# SpellCoda
SpellCoda is an AddOn for World of Warcraft Classic and features a dynamic, configurable ability calculator. It implements many combat mechanics and makes use of thousands of spells, items and effects obtained from a custom generator (not public at this time), always staying up to date with client builds.

Before raising issues regarding calculator correctness, please breeze through the Discord's #info page first to help distinguish between intended behaviour and bugs.

If you clone this repository, you will need to populate the git submodule `generated`.

Releases are automatically built when there are changes in `generated` repository (from client data) or in `release-autotagged` branch.

Any problems with the generated data, whether something is missing or needs modifying, can be handled in the client variation's respective `override.lua` file, e.g. `vanilla/override.lua`.

See the project page here: https://www.curseforge.com/wow/addons/spellcoda
