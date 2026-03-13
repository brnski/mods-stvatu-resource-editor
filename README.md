# ResourceEditor

A UE4SS Lua mod for **Star Trek: Voyager – Across the Unknown** that adds in-game console commands to view and edit ship resources (Food, Deuterium, Energy, Morale, and more).

## Commands

Open the in-game console with `` ` `` (backtick) or `~` (tilde), then use:

| Command | Description |
|---|---|
| `listresources` | Show all resources and their current values |
| `getresource <Name>` | Show a single resource value |
| `setresource <Name> <Value>` | Set a resource to a specific value |

**Examples:**
```
listresources
getresource Food
setresource Food 500
setresource Deuterium 1000
setresource Morale 80
```

**Available resource names:** `Food`, `Deuterium`, `Energy`, `Morale`, `MaxMorale`, `Happiness`, `LivingSpace`, `Resilience`

## Requirements

- [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS) experimental build for UE 5.6

## Installation

### Step 1 — Configure UE4SS

Open `UE4SS-settings.ini` (in the same folder as `UE4SS.dll`) and ensure these values are set:

```ini
[General]
bUseUObjectArrayCache = false

[EngineVersionOverride]
MajorVersion = 5
MinorVersion = 0
```

> `bUseUObjectArrayCache = false` is required for UE 5.6 — the game will crash on startup without it.

### Step 2 — Install the mod

Copy both folders from the zip into your UE4SS `Mods` directory:

```
STVoyager/Binaries/Win64/ue4ss/Mods/
├── ResourceEditor/
│   ├── Scripts/
│   │   └── main.lua
│   └── enabled.txt
└── UE4SS_Signatures/
    └── StaticConstructObject.lua
```

The `UE4SS_Signatures/` folder is required for UE4SS to initialise correctly with this game. If you already have it from another mod (e.g. AutoScanSystem), you do not need to copy it again.

### Step 3 — Verify

Launch the game and open `UE4SS.log`. You should see:

```
[ResourceEditor] v1.0 loaded — commands: listresources | getresource <Name> | setresource <Name> <Value>
```
