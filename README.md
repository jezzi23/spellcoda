# SpellCoda
SpellCoda is an AddOn for World of Warcraft Classic and features a dynamic, configurable ability calculator. It implements many combat mechanics and makes use of thousands of spells and effects obtained from a custom generator (not contained in this repository, nor public at this time).

If you clone this repository, you will need to populate the git submodule `generated`.

Releases are automatically built when there are changes in client data (`generated`) or in release-autotagged repository.

`release-autotagged` branch is only meant for producing automatic builds and not viable for regular usage.

Any problems with the generated data, whether something is missing or needs modifying, can be handled in the client variation's respective `override.lua` file, e.g. `vanilla/override.lua`.

See the project page here: https://www.curseforge.com/wow/addons/spellcoda
