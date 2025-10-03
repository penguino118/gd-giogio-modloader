# GioGio Mod Loader

A work-in-progress mod loader for [GioGio's Bizarre Adventure](https://jojowiki.com/GioGio%27s_Bizarre_Adventure).

Current interface is entirely preliminary, lots of feedback (for both ux and ui) needed!!!!!

If you're building this manually, you need to add the modloader .pnach and .bin under included non-resource files for it to be exported correctly.

## Setup
1. Get an .iso format dump of the retail version of the game (SLPM-65140)
2. [Download](https://pcsx2.net/downloads) and [setup](https://pcsx2.net/docs/category/setup) PCSX2's nightly release
3. Extracts the contents of the .iso dump of the game onto a folder
4. Open the mod loader and set the game directory in the settings tab to where the disc files were extracted. It should say the game executable has been found under the option after that.
5. Add that same directory as a game folder in PCSX2, recursive scanning is not needed. The game list should now show an entry for `gg-modloader.elf`
6. Set the PCSX2 cheats folder in the mod loader settings to point to the same path that PCSX2 is using. If you can't find it, open PCSX2 and go to `Settings`, then `Folders`, and the "Cheats Directory" field should show you.
7. Add any mod to the mod loader and click "Apply".
8. Enable `Show Advanced Settings` under `Tools` in PCSX2.
9. On the game list, right click `gg-modloader.elf` and click `Properties`.
10. Set the `Disc Path` field under `Summary` to the original unedited .iso dump of the game.
11. Under the `Emulation` tab, click on `Enable Host Filesystem`.
12. On the `Cheats` section, enable `HostFS Loading Hooks`. This cheat should always remain enabled
  - If you don't have any cheats listed, please make sure that the PCSX2 cheats directory in the mod loader settings is set correctly, and then reapply your mods.
  - Mods can include their own pnach cheats, enable them if needed.
14. Under `Advanced`, click on `Enable 128MB RAM (Dev Console)`
15. Run the game

### Mod management
Mods are stored in the `mods` folder of the game directory, the mod loader *should* have created it automatically.

To add mods to the mod list, click the plus button on the top right and add one the .zip files from the sample mods list.

Mods will be applied bottom-to-top, with the top-most mod having the highest priority. You can use the arrow keys on the side-bar to change the apply priority of the mods.

To remove a mod, just select one and click the minus button.

### Mod Format

There's four different types of files packaged in the mod files: 

1. **AFS Assets**: Any assets originating from `AFS_DATA.AFS`, `AFS00.AFS`, or `AFS01.AFS` that will be loaded instead of their unmodified counterparts via the mod loader file hooks cheat. Files included must retain the original filename of the file that's being replaced for the game to detect them.
2. **Global Textures**: Any TIM2 (.tm2) format images that will override any textures based on their global loading ID. This is helpful for assets such as character textures which have multiple duplicates spread around cutscene actor data files. The filenames must be just their respective ID number with a .tm2 extension. For example, a texture taking up the ID 118 in a .TXB file must be extracted as TIM2 and be named `118.tm2` for the game to detect it. One caveat to using this method to replace textures is that the new texture's filesize must always be smaller than any copies it might be overriding, since it being bigger might result in textures placed afterwards having part of their data overwritten by it.
3. **PNACH Patches**: Runtime memory patches written in [PCSX2's PNACH Format](https://forums.pcsx2.net/Thread-Sticky-Important-Patching-Notes-1-7-4546-Pnach-2-0). Inner lines of the patch must be properly tagged with titles at the very least, otherwise the modloader will add it's own title with the format: "Untagged (mod title)". Patches will be merged alongside those from other mods into one single pnach file that the Modloader will write into the provided cheats folder used by PCSX2. After merging, it's up to the user to enable them in PCSX2 via their interface.
4. **IPS Patches**: Patches in the IPS (International Patching Standard) Format. The IPS format is very basic and limited, but it's fine for modifying the other, tinier files that are not covered by the mod format, such as the IRX modules, or the game's executable. All files modified via IPS will have generated backups, so the original data can be reinstated if the mod is disabled. The only file that will not create backup data is the executable, since the modloader will always work over a copy of it (`gg-modloader.elf`), rather than the original.

The mod list view in the mod loader should show you what each mod is using under the 'Tags' column

## FAQ
### Mods were applied, but the game never starts
It's possible that the host fileloading is working, but it couldn't find either the modules or AFS archives for one reason or another.

If you're on Linux or any other case sensitive OS, make sure that the filenames of the AFS archives and 0flist.dir are all *lowercase*, as even though the `ISO 9660` format only allows for uppercase filenames, the game stores the paths to AFS archives in lowercase.
All IRX modules and their folder should remain in uppercase.

If it's something else, please enable EE and IOP console logging and turn on the Log Window in PCSX2, then restart the game and report what it says.

### Game starts, but no mods seem to have been applied
Make sure that the host fileloading cheat is enabled, since otherwise it'll load files from the .ISO set under `Disc Path` in the game settings.


### Mod Loader says the CRC changed?
This can happen if one mod or more have modified the game's executable via IPS patches.

The "CRC" is a check PCSX2 makes to distinguish between the different regions and the different editions of one game. The game properties are unique for each CRC, meaning you will have to set up the game configuration again starting from step 9 in the mod loader setup instructions.


### something else happened 😂😂😂
If there's an error with the mod loader program, please report what's happening to me so I can fix it, and please include the console log with it.
If you're on windows, run the console enabled .exe, and if you're on Linux just run it from the terminal.
Note that it will print out filepaths which could reveal your username depending on how you set up your directories, feel free to erase those names from the logs if you include them.

## Misc notes
- Currently, files are removed using the `OS.send_to_trash` function, meaning they aren't completely deleted, maybe it should be switched to permanent deletion once everything is confirmed to be working fine.
