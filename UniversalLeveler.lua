--[=====[
[[SND Metadata]]
author:  'CraftLeveler'
version: 1.0.0
description: Universal 1-100 Crafter & Gatherer Leveling - One Button Solution
configs:
  Mode:
    description: Leveling mode - which classes to level
    is_choice: true
    choices: ["All Crafters", "All Gatherers", "Single Crafter", "Single Gatherer", "Everything"]
    default: "All Crafters"
  SingleClass:
    description: If Single mode, which class (CRP/BSM/ARM/GSM/LTW/WVR/ALC/CUL/BTN/MIN/FSH)
    type: string
    default: "CRP"
  TargetLevel:
    description: Target level to reach (1-100)
    type: integer
    default: 100
  HubCity:
    description: Home city for operations
    is_choice: true
    choices: ["Limsa", "Gridania", "Ul'dah", "Solution Nine"]
    default: "Limsa"
  AutoRepair:
    description: Automatically repair gear when needed
    type: boolean
    default: true
  MinInventorySlots:
    description: Minimum free inventory slots to maintain
    type: integer
    default: 10
  UseFood:
    description: Use crafting/gathering food for XP bonus
    type: boolean
    default: false
  FoodName:
    description: Name of food to use (if UseFood enabled)
    type: string
    default: "Tsai tou Vounou"
  UseManual:
    description: Use GC XP Manuals (+150% XP bonus)
    type: boolean
    default: true
  ManualSource:
    description: Where to get XP manuals
    is_choice: true
    choices: ["Grand Company", "Marketboard", "Inventory Only"]
    default: "Grand Company"
  GrandCompany:
    description: Your Grand Company (for seal exchange)
    is_choice: true
    choices: ["Maelstrom", "Twin Adder", "Immortal Flames"]
    default: "Maelstrom"
  AutoUpgradeGear:
    description: Automatically buy scrip gear when stats too low
    type: boolean
    default: true
  AutoDesynthGear:
    description: Desynth or GC turn-in excess gear (protects gearsets)
    type: boolean
    default: true
  UseLeves:
    description: Use leve allowances for bonus XP (level 10-80)
    type: boolean
    default: true
  DoGCDailies:
    description: Complete GC supply/provisioning daily turn-ins
    type: boolean
    default: true
  DoStudium:
    description: Complete Studium weekly deliveries (Endwalker)
    type: boolean
    default: true
  UseFirmament:
    description: Use Ishgard Restoration for leveling 20-80
    type: boolean
    default: false
  UseOceanFishing:
    description: Use Ocean Fishing for Fisher leveling (every 2 hours)
    type: boolean
    default: true
  AutoRetrieverMaterials:
    description: Check retainers for materials before gathering (requires AutoRetainer)
    type: boolean
    default: true
  ItemToBuy:
    description: Item to buy with scrips when capped (Materia/Tokens/etc)
    type: string
    default: "Crafter's Competence Materia X"

[[End Metadata]]
--]=====]

--[[
================================================================================
                    UNIVERSAL 1-100 CRAFTER & GATHERER LEVELER
                              Version 1.0.0
================================================================================

One-button solution to level all crafters and gatherers from 1 to 100.

REQUIRED PLUGINS:
  1. SND (Something Need Doing) - Croizat fork from puni.sh
  2. Artisan - For dynamic crafting rotations
  3. vnavmesh - For pathfinding
  4. Lifestream - For teleportation

OPTIONAL PLUGINS:
  - GatherBuddyReborn - Enhanced gathering automation

LEVELING STRATEGY:
  Level 1-20:   Quick Synthesis spam + Class quests
  Level 20-50:  Leves (if available) or Grand Company turn-ins
  Level 50-60:  Collectables + Moogle Beast Tribe
  Level 60-70:  Collectables + Namazu Beast Tribe
  Level 70-80:  Collectables + Dwarf/Qitari Beast Tribe
  Level 80-90:  Collectables + Studium Deliveries
  Level 90-100: Orange/Purple Scrip Collectables (most efficient)

================================================================================
]]

-- Imports
import("System.Numerics")

--#region Configuration
Mode                = Config.Get("Mode")
SingleClass         = Config.Get("SingleClass")
TargetLevel         = Config.Get("TargetLevel")
HubCity             = Config.Get("HubCity")
AutoRepair          = Config.Get("AutoRepair")
MinInventorySlots   = Config.Get("MinInventorySlots")
UseFood             = Config.Get("UseFood")
FoodName            = Config.Get("FoodName")
UseManual           = Config.Get("UseManual")
ManualSource        = Config.Get("ManualSource")
GrandCompany        = Config.Get("GrandCompany")
AutoUpgradeGear     = Config.Get("AutoUpgradeGear")
AutoDesynthGear     = Config.Get("AutoDesynthGear")
UseLeves            = Config.Get("UseLeves")
DoGCDailies         = Config.Get("DoGCDailies")
DoStudium           = Config.Get("DoStudium")
UseFirmament        = Config.Get("UseFirmament")
AutoRetrieverMaterials = Config.Get("AutoRetrieverMaterials")
UseOceanFishing     = Config.Get("UseOceanFishing")
ItemToBuy           = Config.Get("ItemToBuy")
--#endregion Configuration

--#region Constants

-- Character Conditions (from game client)
-- See: https://github.com/xivapi/ffxiv-datamining/blob/master/csv/Condition.csv
Condition = {
    normal                              = 1,
    unconscious                         = 2,
    none                                = 0, -- Original 'none'
    normalConditions                    = 1, -- Original 'normalConditions'
    inCombat                            = 26,
    casting                             = 27,
    fishing                             = 28,  -- Add missing condition
    baiting                             = 29,  -- Bite? No, 29 is ??? Need to verify
    occupiedInEvent                     = 31,
    occupiedInQuestEvent                = 32,
    occupied                            = 33,
    boundByDuty                         = 34,
    occupied30                          = 36,
    occupiedMateriaExtractionAndRepair  = 39,
    betweenAreas                        = 45,
    betweenAreas51                      = 51,
    mounted                             = 77,
    flying                              = 77,
    -- Crafting specific
    crafting                            = 5,
    preparingToCraft                    = 6,
    crafting2                           = 7,
    craftingModeIdle                    = 41,
    executingCraftingSkill              = 40,
    -- Gathering specific
    gathering                           = 6,
    occupiedSummoningBell               = 50,
    beingMoved                          = 70
}

-- Class Data
CrafterClasses = {
    { id = 8,  abbr = "CRP", name = "Carpenter",     guildZone = 133, guildAetheryte = "New Gridania" },
    { id = 9,  abbr = "BSM", name = "Blacksmith",    guildZone = 128, guildAetheryte = "Limsa Lominsa Lower Decks" },
    { id = 10, abbr = "ARM", name = "Armorer",       guildZone = 128, guildAetheryte = "Limsa Lominsa Lower Decks" },
    { id = 11, abbr = "GSM", name = "Goldsmith",     guildZone = 131, guildAetheryte = "Ul'dah - Steps of Thal" },
    { id = 12, abbr = "LTW", name = "Leatherworker", guildZone = 133, guildAetheryte = "New Gridania" },
    { id = 13, abbr = "WVR", name = "Weaver",        guildZone = 131, guildAetheryte = "Ul'dah - Steps of Thal" },
    { id = 14, abbr = "ALC", name = "Alchemist",     guildZone = 131, guildAetheryte = "Ul'dah - Steps of Thal" },
    { id = 15, abbr = "CUL", name = "Culinarian",    guildZone = 128, guildAetheryte = "Limsa Lominsa Lower Decks" }
}

GathererClasses = {
    { id = 16, abbr = "MIN", name = "Miner",    guildZone = 131, guildAetheryte = "Ul'dah - Steps of Thal" },
    { id = 17, abbr = "BTN", name = "Botanist", guildZone = 133, guildAetheryte = "New Gridania" },
    { id = 18, abbr = "FSH", name = "Fisher",   guildZone = 128, guildAetheryte = "Limsa Lominsa Lower Decks" }
}

-- Hub Cities data
HubCities = {
    {
        name = "Limsa",
        zoneId = 129,
        aetheryteId = 8,
        aethernetName = "Hawkers' Alley",
        scripExchange = { x = -258.52, y = 16.2, z = 40.65 },
        retainerBell = { x = -124.7, y = 18, z = 19.88 },
        repairNpc = { x = -246.8, y = 16.2, z = 49.5 }
    },
    {
        name = "Gridania",
        zoneId = 132,
        aetheryteId = 2,
        aethernetName = "Leatherworkers' Guild & Shaded Bower",
        scripExchange = { x = 142.15, y = 13.74, z = -105.39 },
        retainerBell = { x = 168.72, y = 15.5, z = -100.06 },
        repairNpc = { x = 158.3, y = 15.5, z = -93.2 }
    },
    {
        name = "Ul'dah",
        zoneId = 130,
        aetheryteId = 9,
        aethernetName = "Sapphire Avenue Exchange",
        scripExchange = { x = 147.73, y = 4, z = -18.19 },
        retainerBell = { x = 146.76, y = 4, z = -42.99 },
        repairNpc = { x = 143.2, y = 4, z = -35.5 }
    },
    {
        name = "Solution Nine",
        zoneId = 1186,
        aetheryteId = 227,
        aethernetName = "Nexus Arcade",
        scripExchange = { x = -158.019, y = 0.922, z = -37.884 },
        retainerBell = { x = -152.465, y = 0.660, z = -13.557 },
        repairNpc = { x = -145.2, y = 0.9, z = -25.3 }
    }
}

-- Grand Company Data
GrandCompanyData = {
    {
        name = "Maelstrom",
        zoneId = 128,
        aetheryte = "Limsa Lominsa Lower Decks",
        aethernetName = "Maelstrom Command",
        quartermaster = { x = -68.34, y = 18.2, z = 0.04, npcName = "Storm Quartermaster" }
    },
    {
        name = "Twin Adder",
        zoneId = 132,
        aetheryte = "New Gridania",
        aethernetName = "Adders' Nest",
        quartermaster = { x = -66.56, y = -0.5, z = -1.13, npcName = "Serpent Quartermaster" }
    },
    {
        name = "Immortal Flames",
        zoneId = 130,
        aetheryte = "Ul'dah - Steps of Nald",
        aethernetName = "Hall of Flames",
        quartermaster = { x = -139.39, y = 4.1, z = -101.27, npcName = "Flame Quartermaster" }
    }
}

-- XP Manual Items (GC Shop)
XPManuals = {
    -- Company-issue manuals (GC Seals) - 1400 seals each, +150% XP up to bonus cap
    engineering = {
        itemId = 4634,
        itemName = "Company-issue Engineering Manual",
        gcCost = 1400,
        buffId = 45,  -- Crafting XP buff
        buffName = "The Heat of Battle"
    },
    survival = {
        itemId = 4635,
        itemName = "Company-issue Survival Manual",
        gcCost = 1400,
        buffId = 46,  -- Gathering XP buff
        buffName = "The Heat of Battle"
    }
}

-- Orange Scrip Collectable Recipes (Level 90-100)
OrangeScripCrafts = {
    { classId = 8,  itemName = "Rarefied Claro Walnut Fishing Rod",       recipeId = 35787 },
    { classId = 9,  itemName = "Rarefied Ra'Kaznar Round Knife",          recipeId = 35793 },
    { classId = 10, itemName = "Rarefied Ra'Kaznar Ring",                 recipeId = 35799 },
    { classId = 11, itemName = "Rarefied Black Star Earrings",            recipeId = 35805 },
    { classId = 12, itemName = "Rarefied Gargantuaskin Hat",              recipeId = 35811 },
    { classId = 13, itemName = "Rarefied Thunderyard Silk Culottes",      recipeId = 35817 },
    { classId = 14, itemName = "Rarefied Claro Walnut Flat Brush",        recipeId = 35823 },
    { classId = 15, itemName = "Rarefied Tacos de Carne Asada",           recipeId = 35829 }
}

-- Purple Scrip Collectable Recipes (Level 90-100, higher tier)
PurpleScripCrafts = {
    { classId = 8,  itemName = "Rarefied Claro Walnut Grinding Wheel",    recipeId = 35786 },
    { classId = 9,  itemName = "Rarefied Ra'Kaznar War Scythe",           recipeId = 35792 },
    { classId = 10, itemName = "Rarefied Ra'Kaznar Greaves",              recipeId = 35798 },
    { classId = 11, itemName = "Rarefied Ra'Kaznar Orrery",               recipeId = 35804 },
    { classId = 12, itemName = "Rarefied Gargantuaskin Trousers",         recipeId = 35810 },
    { classId = 13, itemName = "Rarefied Thunderyard Silk Gloves",        recipeId = 35816 },
    { classId = 14, itemName = "Rarefied Gemdraught of Vitality",         recipeId = 35822 },
    { classId = 15, itemName = "Rarefied Stuffed Peppers",                recipeId = 35828 }
}

-- Collectable items by level bracket
CollectableCrafts = {
    -- Level 50-60 Collectables
    { minLevel = 50, maxLevel = 60, classId = 8,  itemName = "Rarefied Yew Longbow",           recipeId = 31200 },
    { minLevel = 50, maxLevel = 60, classId = 9,  itemName = "Rarefied Titanium Broadsword",   recipeId = 31206 },
    { minLevel = 50, maxLevel = 60, classId = 10, itemName = "Rarefied Titanium Cuirass",      recipeId = 31212 },
    { minLevel = 50, maxLevel = 60, classId = 11, itemName = "Rarefied Titanium Earrings",     recipeId = 31218 },
    { minLevel = 50, maxLevel = 60, classId = 12, itemName = "Rarefied Archaeoskin Jacket",    recipeId = 31224 },
    { minLevel = 50, maxLevel = 60, classId = 13, itemName = "Rarefied Ramie Cloth",           recipeId = 31230 },
    { minLevel = 50, maxLevel = 60, classId = 14, itemName = "Rarefied Growth Formula Gamma",  recipeId = 31236 },
    { minLevel = 50, maxLevel = 60, classId = 15, itemName = "Rarefied Beet Soup",             recipeId = 31242 },
    
    -- Level 60-70 Collectables
    { minLevel = 60, maxLevel = 70, classId = 8,  itemName = "Rarefied Pine Lumber",           recipeId = 32100 },
    { minLevel = 60, maxLevel = 70, classId = 9,  itemName = "Rarefied High Steel Ingot",      recipeId = 32106 },
    { minLevel = 60, maxLevel = 70, classId = 10, itemName = "Rarefied Chromite Ingot",        recipeId = 32112 },
    { minLevel = 60, maxLevel = 70, classId = 11, itemName = "Rarefied Star Ruby",             recipeId = 32118 },
    { minLevel = 60, maxLevel = 70, classId = 12, itemName = "Rarefied Gazelle Leather",       recipeId = 32124 },
    { minLevel = 60, maxLevel = 70, classId = 13, itemName = "Rarefied Kudzu Cloth",           recipeId = 32130 },
    { minLevel = 60, maxLevel = 70, classId = 14, itemName = "Rarefied Vitality Draught",      recipeId = 32136 },
    { minLevel = 60, maxLevel = 70, classId = 15, itemName = "Rarefied Lemonade",              recipeId = 32142 },
    
    -- Level 70-80 Collectables
    { minLevel = 70, maxLevel = 80, classId = 8,  itemName = "Rarefied White Oak Lumber",      recipeId = 33000 },
    { minLevel = 70, maxLevel = 80, classId = 9,  itemName = "Rarefied Titanbronze Ingot",     recipeId = 33006 },
    { minLevel = 70, maxLevel = 80, classId = 10, itemName = "Rarefied Dwarven Mythril Ingot", recipeId = 33012 },
    { minLevel = 70, maxLevel = 80, classId = 11, itemName = "Rarefied Bluespirit Tile",       recipeId = 33018 },
    { minLevel = 70, maxLevel = 80, classId = 12, itemName = "Rarefied Zonure Leather",        recipeId = 33024 },
    { minLevel = 70, maxLevel = 80, classId = 13, itemName = "Rarefied Pixie Cotton",          recipeId = 33030 },
    { minLevel = 70, maxLevel = 80, classId = 14, itemName = "Rarefied Syrup",                 recipeId = 33036 },
    { minLevel = 70, maxLevel = 80, classId = 15, itemName = "Rarefied Coffee Biscuit",        recipeId = 33042 },
    
    -- Level 80-90 Collectables
    { minLevel = 80, maxLevel = 90, classId = 8,  itemName = "Rarefied Integral Lumber",       recipeId = 34500 },
    { minLevel = 80, maxLevel = 90, classId = 9,  itemName = "Rarefied Chondrite Ingot",       recipeId = 34506 },
    { minLevel = 80, maxLevel = 90, classId = 10, itemName = "Rarefied Manganese Ingot",       recipeId = 34512 },
    { minLevel = 80, maxLevel = 90, classId = 11, itemName = "Rarefied Integral Coating",      recipeId = 34518 },
    { minLevel = 80, maxLevel = 90, classId = 12, itemName = "Rarefied Saiga Leather",         recipeId = 34524 },
    { minLevel = 80, maxLevel = 90, classId = 13, itemName = "Rarefied AR-Caean Cotton",       recipeId = 34530 },
    { minLevel = 80, maxLevel = 90, classId = 14, itemName = "Rarefied Draught",               recipeId = 34536 },
    { minLevel = 80, maxLevel = 90, classId = 15, itemName = "Rarefied Sykon Compote",         recipeId = 34542 }
}

-- Material Requirements Database
-- Maps crafting recipes to their base gathered materials
-- gathererClass: 16 = MIN, 17 = BTN, 18 = FSH
-- requiredLevel: minimum gatherer level needed to gather this material
MaterialRequirements = {
    -- Level 90-100 Orange Scrip Materials (Dawntrail)
    [35787] = { -- Rarefied Claro Walnut Fishing Rod (CRP)
        { itemName = "Claro Walnut Log", gathererClass = 17, quantity = 3, requiredLevel = 90 },
    },
    [35793] = { -- Rarefied Ra'Kaznar Round Knife (BSM)
        { itemName = "Ra'Kaznar Ore", gathererClass = 16, quantity = 3, requiredLevel = 90 },
    },
    [35799] = { -- Rarefied Ra'Kaznar Ring (ARM)
        { itemName = "Ra'Kaznar Ore", gathererClass = 16, quantity = 3, requiredLevel = 90 },
    },
    [35805] = { -- Rarefied Black Star Earrings (GSM)
        { itemName = "Black Star", gathererClass = 16, quantity = 2, requiredLevel = 96 },
    },
    [35811] = { -- Rarefied Gargantuaskin Hat (LTW)
        { itemName = "Gargantua Skin", gathererClass = 17, quantity = 2, requiredLevel = 93 },
    },
    [35817] = { -- Rarefied Thunderyard Silk Culottes (WVR)
        { itemName = "Thunderyard Cocoon", gathererClass = 17, quantity = 3, requiredLevel = 90 },
    },
    [35823] = { -- Rarefied Claro Walnut Flat Brush (ALC)
        { itemName = "Claro Walnut Log", gathererClass = 17, quantity = 2, requiredLevel = 90 },
    },
    [35829] = { -- Rarefied Tacos de Carne Asada (CUL)
        { itemName = "Yyasulani Garlic", gathererClass = 17, quantity = 2, requiredLevel = 91 },
    },
    
    -- Level 80-90 Materials (Endwalker)
    [34500] = { { itemName = "Integral Log", gathererClass = 17, quantity = 3, requiredLevel = 80 } },
    [34506] = { { itemName = "Chondrite", gathererClass = 16, quantity = 3, requiredLevel = 80 } },
    
    -- Level 70-80 Materials (Shadowbringers)
    [33000] = { { itemName = "White Oak Log", gathererClass = 17, quantity = 3, requiredLevel = 70 } },
    [33006] = { { itemName = "Titanbronze Ore", gathererClass = 16, quantity = 3, requiredLevel = 70 } },
    
    -- Level 60-70 Materials (Stormblood)
    [32100] = { { itemName = "Pine Log", gathererClass = 17, quantity = 3, requiredLevel = 60 } },
    [32106] = { { itemName = "High Steel Ore", gathererClass = 16, quantity = 3, requiredLevel = 60 } },
    
    -- Level 50-60 Materials (Heavensward)
    [31200] = { { itemName = "Yew Log", gathererClass = 17, quantity = 3, requiredLevel = 50 } },
    [31206] = { { itemName = "Titanium Ore", gathererClass = 16, quantity = 3, requiredLevel = 50 } },
}

-- Scrip Gear Tiers (for auto-upgrade)
-- Each tier has recommended scrip gear from the Scrip Exchange
ScripGearTiers = {
    -- Level 50 gear (White Scrips from ARR vendors)
    { minLevel = 50, maxLevel = 60, scripType = "white", setName = "Forager's" },
    -- Level 60 gear (White Scrips)
    { minLevel = 60, maxLevel = 70, scripType = "white", setName = "Augmented Fieldkeep's" },
    -- Level 70 gear (White Scrips)
    { minLevel = 70, maxLevel = 80, scripType = "white", setName = "Handsaint's" },
    -- Level 80 gear (White Scrips)
    { minLevel = 80, maxLevel = 90, scripType = "white", setName = "Perfectionist's" },
    -- Level 90+ gear (Orange Scrips)  
    { minLevel = 90, maxLevel = 100, scripType = "orange", setName = "Indagator's" },
}

-- State Machine States
State = {
    IDLE = "IDLE",
    SWITCHING_CLASS = "SWITCHING_CLASS",
    BUFFING = "BUFFING",
    UPGRADING_GEAR = "UPGRADING_GEAR",              -- Buying/updating gear
    CRAFTING = "CRAFTING",
    GATHERING = "GATHERING",
    GATHERING_MATERIALS = "GATHERING_MATERIALS",    -- Gathering materials for crafting
    LEVELING_GATHERER = "LEVELING_GATHERER",        -- Leveling gatherer to unlock materials
    TURNING_IN = "TURNING_IN",
    DISPOSING_GEAR = "DISPOSING_GEAR",              -- Desynth/GC turn-in old gear
    REPAIRING = "REPAIRING",
    TRAVELING = "TRAVELING",
    WAITING = "WAITING",
    COMPLETE = "COMPLETE",
    ERROR = "ERROR"
}

--#endregion Constants

--#region Global Variables
CurrentState = State.IDLE
CurrentClassIndex = 1
ClassesToLevel = {}
SelectedHub = nil
StopScript = false
LastError = ""

-- Material Sourcing State
PreviousCrafterClass = nil      -- Class to return to after gathering materials
MaterialsToGather = {}          -- List of materials needed
CurrentMaterialIndex = 1        -- Current material being gathered

-- Gatherer Leveling Queue (for when gatherer is too low)
PendingCrafter = nil            -- Crafter waiting for gatherer to level up
PendingRecipe = nil             -- Recipe the crafter was trying to make
RequiredGathererLevel = 0       -- Level gatherer needs to reach
GathererBeingLeveled = nil      -- Which gatherer we're leveling for crafting

-- Progress file path (for save/resume)
-- Uses FFXIV plugin config directory
ProgressFilePath = Svc.PluginInterface.ConfigDirectory.FullName .. "/UniversalLeveler_progress.json"
--#endregion Global Variables

--#region Progress Persistence

function SaveProgress()
    -- Save current progress to file for resume capability
    local data = {
        currentClassIndex = CurrentClassIndex,
        currentState = CurrentState,
        previousCrafterClass = PreviousCrafterClass,
        currentMaterialIndex = CurrentMaterialIndex,
        pendingCrafter = PendingCrafter,
        requiredGathererLevel = RequiredGathererLevel,
        gathererBeingLeveled = GathererBeingLeveled,
        timestamp = os.time(),
        mode = Mode
    }
    
    -- Simple JSON serialization
    local json = "{\n"
    for k, v in pairs(data) do
        if type(v) == "string" then
            json = json .. '  "' .. k .. '": "' .. tostring(v) .. '",\n'
        elseif type(v) == "number" or type(v) == "boolean" then
            json = json .. '  "' .. k .. '": ' .. tostring(v) .. ',\n'
        elseif v == nil then
            json = json .. '  "' .. k .. '": null,\n'
        end
    end
    json = json:sub(1, -3) .. "\n}"  -- Remove trailing comma
    
    -- Write to file
    local file = io.open(ProgressFilePath, "w")
    if file then
        file:write(json)
        file:close()
        Log("Progress saved to " .. ProgressFilePath)
        return true
    else
        Log("Failed to save progress")
        return false
    end
end

function LoadProgress()
    -- Load progress from file
    local file = io.open(ProgressFilePath, "r")
    if not file then
        Log("No progress file found, starting fresh")
        return false
    end
    
    local content = file:read("*all")
    file:close()
    
    if not content or content == "" then
        return false
    end
    
    -- Simple JSON parsing (basic patterns)
    local function getValue(key)
        local pattern = '"' .. key .. '":%s*"?([^",}]+)"?'
        local match = content:match(pattern)
        return match
    end
    
    -- Restore state
    local savedIndex = tonumber(getValue("currentClassIndex"))
    local savedState = getValue("currentState")
    local savedTimestamp = tonumber(getValue("timestamp"))
    
    if not savedIndex or not savedState then
        Log("Invalid progress file")
        return false
    end
    
    -- Check if progress is stale (older than 24 hours)
    if savedTimestamp and (os.time() - savedTimestamp > 86400) then
        Log("Progress file is stale (>24h), starting fresh")
        return false
    end
    
    CurrentClassIndex = savedIndex
    CurrentState = savedState
    PreviousCrafterClass = tonumber(getValue("previousCrafterClass"))
    CurrentMaterialIndex = tonumber(getValue("currentMaterialIndex")) or 1
    PendingCrafter = tonumber(getValue("pendingCrafter"))
    RequiredGathererLevel = tonumber(getValue("requiredGathererLevel")) or 0
    GathererBeingLeveled = tonumber(getValue("gathererBeingLeveled"))
    
    Log("Progress loaded: Class index " .. CurrentClassIndex .. ", State " .. CurrentState)
    Echo("Resuming from saved progress!")
    
    return true
end

function ClearProgress()
    -- Delete progress file (call on completion)
    os.remove(ProgressFilePath)
    Log("Progress file cleared")
end

--#endregion Progress Persistence

--#region Utility Functions

function Log(message)
    Dalamud.Log("[UniversalLeveler] " .. message)
end

function Echo(message)
    yield("/echo [Leveler] " .. message)
end

function Wait(seconds)
    yield("/wait " .. tostring(seconds))
end

function WaitUntilReady()
    while not Player.Available or Svc.Condition[CharacterCondition.betweenAreas] or 
          Svc.Condition[CharacterCondition.betweenAreas51] or
          Svc.Condition[CharacterCondition.casting] do
        Wait(0.5)
    end
    Wait(0.5)
end

function GetDistance(x1, y1, z1, x2, y2, z2)
    local dx = x2 - x1
    local dy = y2 - y1
    local dz = z2 - z1
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

function GetDistanceToPoint(x, y, z)
    if not Player.Available then return 9999 end
    local pos = Entity.Player.Position
    return GetDistance(pos.X, pos.Y, pos.Z, x, y, z)
end

function HasPlugin(name)
    local target = string.lower(name)
    for plugin in luanet.each(Svc.PluginInterface.InstalledPlugins) do
        if string.lower(plugin.InternalName) == target and plugin.IsLoaded then
            return true
        end
    end
    return false
end

function HasGatherBuddy()
    return HasPlugin("GatherBuddy") or HasPlugin("GatherBuddyReborn") or HasPlugin("GatherBuddy Reborn")
end

function GetFreeInventorySlots()
    return Inventory.GetFreeInventorySlots() or 0
end

function NeedsRepair()
    -- Check if any equipped gear is below 30% durability
    return Snd.NeedsRepair(30)
end

--#endregion Utility Functions

--#region Buff Functions

function GetSelectedGC()
    for _, gc in ipairs(GrandCompanyData) do
        if gc.name == GrandCompany then
            return gc
        end
    end
    return GrandCompanyData[1] -- Default to Maelstrom
end

function GetRequiredManual(classId)
    -- Return the appropriate manual based on class type
    if IsCrafter(classId) then
        return XPManuals.engineering
    else
        return XPManuals.survival
    end
end

function HasXPBuff(classId)
    -- Check if player has the appropriate XP buff active
    local manual = GetRequiredManual(classId)
    local statusList = Player.Status
    
    if not statusList then
        return false
    end
    
    -- Check for any crafting/gathering XP buff
    -- Status IDs: 45 = Engineering Manual, 46 = Survival Manual
    for i = 0, statusList.Count - 1 do
        local status = statusList:get_Item(i)
        if status then
            -- Engineering Manual buff = 45, Survival Manual = 46
            -- Also check for squadron/FC buffs
            if status.StatusId == manual.buffId or 
               status.StatusId == 45 or status.StatusId == 46 or
               status.StatusId == 1081 or status.StatusId == 1082 then -- Squadron manuals
                return true
            end
        end
    end
    
    return false
end

function GetManualCount(classId)
    local manual = GetRequiredManual(classId)
    return Inventory.GetItemCount(manual.itemId) or 0
end

function UseManualItem(classId)
    local manual = GetRequiredManual(classId)
    Log("Using " .. manual.itemName)
    
    -- Use the item
    yield("/item " .. manual.itemName)
    Wait(2)
    
    -- Verify buff was applied
    return HasXPBuff(classId)
end

function BuyManualFromGC(classId, quantity)
    local manual = GetRequiredManual(classId)
    local gc = GetSelectedGC()
    
    Log("Buying " .. quantity .. "x " .. manual.itemName .. " from " .. gc.name)
    
    -- Teleport to GC
    TeleportTo(gc.aetheryte)
    WaitUntilReady()
    
    -- Navigate to quartermaster
    NavigateToPoint(gc.quartermaster.x, gc.quartermaster.y, gc.quartermaster.z)
    Wait(1)
    
    -- Target and interact with quartermaster
    yield("/target " .. gc.quartermaster.npcName)
    Wait(1)
    yield("/interact")
    Wait(2)
    
    -- Wait for shop to open
    local timeout = 10
    local startTime = os.clock()
    while not Addons.GetAddon("GrandCompanyExchange").Ready do
        if os.clock() - startTime > timeout then
            Log("GC Exchange not opening")
            return false
        end
        Wait(0.5)
    end
    
    -- Navigate to Materials category (where manuals are)
    -- Category: Materials -> Materiel
    yield("/callback GrandCompanyExchange true 1 1") -- Select Materials
    Wait(0.5)
    yield("/callback GrandCompanyExchange true 2 0") -- Select Materiel subcategory
    Wait(0.5)
    
    -- Find and purchase the manual
    -- The exact callback depends on the shop layout, may need adjustment
    if IsCrafter(classId) then
        yield("/callback GrandCompanyExchange true 3 0") -- Engineering Manual
    else
        yield("/callback GrandCompanyExchange true 3 1") -- Survival Manual
    end
    Wait(0.5)
    
    -- Set quantity and purchase
    for i = 1, quantity do
        yield("/callback GrandCompanyExchange true 0") -- Purchase
        Wait(0.5)
        
        -- Confirm if needed
        if Addons.GetAddon("SelectYesno").Ready then
            yield("/callback SelectYesno true 0")
            Wait(0.5)
        end
    end
    
    -- Close the window
    yield("/callback GrandCompanyExchange true -1")
    Wait(1)
    
    Log("Purchased " .. quantity .. " manuals")
    return true
end

function EnsureBuff(classId)
    -- Skip if manual usage is disabled
    if not UseManual then
        return true
    end
    
    -- Check if already buffed
    if HasXPBuff(classId) then
        Log("XP buff already active")
        return true
    end
    
    local manual = GetRequiredManual(classId)
    local manualCount = GetManualCount(classId)
    
    Log("Manual count: " .. manualCount .. " (" .. manual.itemName .. ")")
    
    -- If we have manuals in inventory, use one
    if manualCount > 0 then
        return UseManualItem(classId)
    end
    
    -- Need to acquire manuals
    if ManualSource == "Grand Company" then
        -- Buy from GC
        if BuyManualFromGC(classId, 5) then
            Wait(1)
            return UseManualItem(classId)
        else
            Echo("Failed to buy manuals from GC - continuing without buff")
            return true
        end
    elseif ManualSource == "Marketboard" then
        -- Marketboard purchase would require additional plugin support
        Echo("Marketboard purchase not implemented - please buy manuals manually")
        return true
    else
        -- Inventory Only - no manuals available
        Log("No manuals in inventory and source is Inventory Only")
        return true
    end
end

--#endregion Buff Functions

--#region Spiritbond Functions

function CheckAndExtractMateria()
    -- Check if any gear has 100% spiritbond and extract materia
    -- This gives free materia while leveling
    
    if not Player.Available then return end
    
    -- Check for spiritbond ready (SND function)
    local hasSpiritbond = false
    
    -- Check equipped gear spiritbond
    -- Iterate through equipped items
    for slot = 0, 12 do
        local item = Inventory.GetEquippedItem(slot)
        if item and item.Spiritbond >= 10000 then  -- 10000 = 100%
            hasSpiritbond = true
            break
        end
    end
    
    if not hasSpiritbond then
        return false
    end
    
    Log("Spiritbond ready - extracting materia")
    Echo("Extracting materia from spiritbonded gear...")
    
    -- Open materia extraction window
    yield("/generalaction Materia Extraction")
    Wait(2)
    
    -- Wait for window
    local timeout = 5
    local startTime = os.clock()
    while not Addons.GetAddon("Materialize").Ready do
        if os.clock() - startTime > timeout then
            Log("Materia extraction window didn't open")
            return false
        end
        Wait(0.5)
    end
    
    -- Extract all available materia
    local extractCount = 0
    local maxExtract = 20
    
    while Addons.GetAddon("Materialize").Ready and extractCount < maxExtract do
        -- Click extract on first item
        yield("/callback Materialize true 0")
        Wait(1.5)  -- Extraction animation
        
        -- Check if window closed (no more items)
        if not Addons.GetAddon("Materialize").Ready then
            break
        end
        
        extractCount = extractCount + 1
    end
    
    -- Close window if still open
    if Addons.GetAddon("Materialize").Ready then
        yield("/callback Materialize true -1")
    end
    
    Log("Extracted " .. extractCount .. " materia")
    Echo("Extracted " .. extractCount .. " materia!")
    Wait(1)
    
    return extractCount > 0
end

--#endregion Spiritbond Functions

--#region Retainer Functions

function CheckRetainerMaterials(itemName, needed)
    -- Check if retainers have the material and retrieve it
    -- Requires AutoRetainer plugin
    
    if not HasPlugin("AutoRetainer") then
        Log("AutoRetainer not available")
        return 0
    end
    
    local currentCount = Inventory.GetItemCount(itemName) or 0
    if currentCount >= needed then
        return currentCount
    end
    
    Log("Checking retainers for: " .. itemName)
    
    -- Navigate to retainer bell
    local hub = GetSelectedHub()
    
    -- Check if we're at hub
    if Svc.ClientState.TerritoryType ~= hub.zoneId then
        GoToHub()
        Wait(2)
    end
    
    -- Go to retainer bell
    NavigateToPoint(hub.retainerBell.x, hub.retainerBell.y, hub.retainerBell.z)
    Wait(1)
    
    -- Target and interact with summoning bell
    yield("/target Summoning Bell")
    Wait(1)
    yield("/interact")
    Wait(2)
    
    -- Wait for retainer list
    local timeout = 10
    local startTime = os.clock()
    while not Addons.GetAddon("RetainerList").Ready do
        if os.clock() - startTime > timeout then
            Log("Retainer list not opening")
            return currentCount
        end
        Wait(0.5)
    end
    
    -- Use AutoRetainer to handle multi-retainer retrieval
    -- This command processes all retainers
    yield("/ays multi")
    Wait(10)  -- Wait for AutoRetainer to cycle through retainers
    
    -- Close retainer window if still open
    if Addons.GetAddon("RetainerList").Ready then
        yield("/callback RetainerList true -1")
        Wait(1)
    end
    
    -- Check new count
    local newCount = Inventory.GetItemCount(itemName) or 0
    local retrieved = newCount - currentCount
    
    if retrieved > 0 then
        Log("Retrieved " .. retrieved .. "x " .. itemName .. " from retainers")
        Echo("Got " .. retrieved .. "x " .. itemName .. " from retainers!")
    end
    
    return newCount
end

--#endregion Retainer Functions

--#region Leve Functions

-- Leve NPC locations by level range
LeveNPCs = {
    { minLevel = 10, maxLevel = 15, city = "Limsa", npcName = "T'mokkri", zone = 129 },
    { minLevel = 15, maxLevel = 25, city = "Limsa", npcName = "Gontrant", zone = 129 },
    { minLevel = 25, maxLevel = 35, city = "Ul'dah", npcName = "Eustace", zone = 130 },
    { minLevel = 35, maxLevel = 45, city = "Ishgard", npcName = "Eloin", zone = 418 },
    { minLevel = 45, maxLevel = 50, city = "Mor Dhona", npcName = "K'leytai", zone = 156 },
    { minLevel = 50, maxLevel = 58, city = "Ishgard", npcName = "Eloin", zone = 418 },
    { minLevel = 58, maxLevel = 70, city = "Kugane", npcName = "Keltraeng", zone = 628 },
    { minLevel = 70, maxLevel = 80, city = "Crystarium", npcName = "Eirikur", zone = 819 },
}

function GetLeveAllowances()
    -- Get current leve allowances
    return Player.LeveAllowances or 0
end

function DoLeveQuest(classId, level)
    -- Use leve allowances for bonus XP
    local allowances = GetLeveAllowances()
    if allowances <= 0 then
        Log("No leve allowances available")
        return false
    end
    
    -- Find appropriate leve NPC
    local leveNPC = nil
    for _, npc in ipairs(LeveNPCs) do
        if level >= npc.minLevel and level < npc.maxLevel then
            leveNPC = npc
            break
        end
    end
    
    if not leveNPC then
        Log("No leve NPC for level " .. level)
        return false
    end
    
    Log("Using leves at " .. leveNPC.city .. " (" .. allowances .. " allowances)")
    Echo("Doing leve quests at " .. leveNPC.city)
    
    -- Teleport to leve city
    TeleportTo(leveNPC.city)
    WaitUntilReady()
    
    -- Target leve NPC
    yield("/target " .. leveNPC.npcName)
    Wait(1)
    yield("/interact")
    Wait(2)
    
    -- Wait for leve window
    local timeout = 10
    local startTime = os.clock()
    while not Addons.GetAddon("GuildLeve").Ready do
        if os.clock() - startTime > timeout then
            Log("Leve window not opening")
            return false
        end
        Wait(0.5)
    end
    
    -- Accept first available crafting leve
    yield("/callback GuildLeve true 0")  -- Select crafting tab
    Wait(0.5)
    yield("/callback GuildLeve true 3 0")  -- Accept first leve
    Wait(1)
    
    -- Close window
    yield("/callback GuildLeve true -1")
    Wait(1)
    
    -- Craft the leve item using Artisan
    Echo("Crafting leve item...")
    yield("/artisan")
    Wait(30)  -- Give time for crafting
    
    -- Turn in leve (need to find levemete)
    yield("/target " .. leveNPC.npcName)
    Wait(1)
    yield("/interact")
    Wait(2)
    
    -- Turn in
    if Addons.GetAddon("JournalResult").Ready then
        yield("/callback JournalResult true 0")  -- Complete
        Wait(2)
    end
    
    return true
end

--#endregion Leve Functions

--#region GC Daily Functions

function CheckGCDailies()
    -- Check if GC supply/provisioning dailies are available
    local gc = GetSelectedGC()
    
    Log("Checking GC dailies at " .. gc.name)
    
    -- Teleport to GC
    TeleportTo(gc.aetheryte)
    WaitUntilReady()
    
    -- Open timers window to check dailies
    yield("/timers")
    Wait(2)
    
    -- Check if supply/provisioning is available
    -- This requires reading the ContentsInfoDetail addon
    local dailyAvailable = true  -- Simplified - actual implementation would check reset timer
    
    if not dailyAvailable then
        Log("GC dailies not available (already done)")
        return false
    end
    
    return true
end

function DoGCDailyTurnIn(classId)
    -- Complete GC supply mission for current class
    local gc = GetSelectedGC()
    
    Log("Completing GC supply mission for class " .. classId)
    Echo("GC Supply Turn-in")
    
    -- Navigate to Personnel Officer
    NavigateToPoint(gc.quartermaster.x, gc.quartermaster.y, gc.quartermaster.z)
    Wait(1)
    
    -- Target Personnel Officer
    if gc.name == "Maelstrom" then
        yield("/target Storm Personnel Officer")
    elseif gc.name == "Twin Adder" then
        yield("/target Serpent Personnel Officer")
    else
        yield("/target Flame Personnel Officer")
    end
    Wait(1)
    yield("/interact")
    Wait(2)
    
    -- Wait for supply/provisioning window
    if Addons.GetAddon("GrandCompanySupplyList").Ready then
        -- Select Supply tab (crafters) or Provisioning (gatherers)
        if IsCrafter(classId) then
            yield("/callback GrandCompanySupplyList true 0")  -- Supply tab
        else
            yield("/callback GrandCompanySupplyList true 1")  -- Provisioning tab
        end
        Wait(0.5)
        
        -- Turn in current class item
        yield("/callback GrandCompanySupplyList true 0 0")  -- First item
        Wait(1)
        
        -- Confirm
        if Addons.GetAddon("SelectYesno").Ready then
            yield("/callback SelectYesno true 0")
            Wait(1)
        end
        
        -- Close
        yield("/callback GrandCompanySupplyList true -1")
    end
    
    return true
end

--#endregion GC Daily Functions

--#region Studium Functions

-- Studium NPC locations (Endwalker)
StudiumNPCs = {
    { classId = 8,  npcName = "Debroye",   zone = 962, x = -50.2, y = 20.0, z = -12.5 },  -- CRP
    { classId = 9,  npcName = "Lisette",   zone = 962, x = -48.5, y = 20.0, z = -15.3 },  -- BSM
    { classId = 10, npcName = "Iola",      zone = 962, x = -46.8, y = 20.0, z = -18.1 },  -- ARM
    { classId = 11, npcName = "Charlotte", zone = 962, x = -45.1, y = 20.0, z = -20.9 },  -- GSM
    { classId = 12, npcName = "Rosalind",  zone = 962, x = -43.4, y = 20.0, z = -23.7 },  -- LTW
    { classId = 13, npcName = "Dominiac",  zone = 962, x = -41.7, y = 20.0, z = -26.5 },  -- WVR
    { classId = 14, npcName = "Qih Aliapoh", zone = 962, x = -40.0, y = 20.0, z = -29.3 },  -- ALC
    { classId = 15, npcName = "Maudiuex",  zone = 962, x = -38.3, y = 20.0, z = -32.1 },  -- CUL
}

function CheckStudiumWeekly(classId)
    -- Check if Studium weekly is available for this class
    -- Requires level 80+ and weekly reset
    
    local level = GetClassLevel(classId)
    if level < 80 then
        return false
    end
    
    -- Find NPC for this class
    local studiumNPC = nil
    for _, npc in ipairs(StudiumNPCs) do
        if npc.classId == classId then
            studiumNPC = npc
            break
        end
    end
    
    if not studiumNPC then
        return false
    end
    
    return true, studiumNPC
end

function DoStudiumDelivery(classId)
    -- Complete Studium weekly delivery
    local available, studiumNPC = CheckStudiumWeekly(classId)
    
    if not available then
        Log("Studium not available for class " .. classId)
        return false
    end
    
    Log("Completing Studium delivery for " .. studiumNPC.npcName)
    Echo("Studium Delivery")
    
    -- Teleport to Old Sharlayan
    TeleportTo("Old Sharlayan")
    WaitUntilReady()
    
    -- Navigate to NPC
    NavigateToPoint(studiumNPC.x, studiumNPC.y, studiumNPC.z)
    Wait(1)
    
    -- Target NPC
    yield("/target " .. studiumNPC.npcName)
    Wait(1)
    yield("/interact")
    Wait(2)
    
    -- Handle Studium delivery window
    if Addons.GetAddon("HWDSupply").Ready then
        -- Accept delivery quest
        yield("/callback HWDSupply true 0")
        Wait(1)
    end
    
    -- Craft required item using Artisan
    Echo("Crafting Studium delivery item...")
    yield("/artisan")
    Wait(30)
    
    -- Turn in
    yield("/target " .. studiumNPC.npcName)
    Wait(1)
    yield("/interact")
    Wait(2)
    
    if Addons.GetAddon("HWDSupply").Ready then
        yield("/callback HWDSupply true 1")  -- Turn in
        Wait(2)
    end
    
    return true
end

--#endregion Studium Functions

--#region Firmament Functions (Ishgard Restoration)

-- Firmament crafting recipes by level range per class
FirmamentRecipes = {
    -- Level 20-40 (Grade 2)
    { minLevel = 20, maxLevel = 40, classId = 8,  itemName = "Grade 2 Skybuilders' Plywood" },
    { minLevel = 20, maxLevel = 40, classId = 9,  itemName = "Grade 2 Skybuilders' Ingot" },
    { minLevel = 20, maxLevel = 40, classId = 10, itemName = "Grade 2 Skybuilders' Rivets" },
    { minLevel = 20, maxLevel = 40, classId = 11, itemName = "Grade 2 Skybuilders' Wire" },
    { minLevel = 20, maxLevel = 40, classId = 12, itemName = "Grade 2 Skybuilders' Leather" },
    { minLevel = 20, maxLevel = 40, classId = 13, itemName = "Grade 2 Skybuilders' Cloth" },
    { minLevel = 20, maxLevel = 40, classId = 14, itemName = "Grade 2 Skybuilders' Ink" },
    { minLevel = 20, maxLevel = 40, classId = 15, itemName = "Grade 2 Skybuilders' Stew" },
    
    -- Level 40-60 (Grade 3)
    { minLevel = 40, maxLevel = 60, classId = 8,  itemName = "Grade 3 Skybuilders' Plywood" },
    { minLevel = 40, maxLevel = 60, classId = 9,  itemName = "Grade 3 Skybuilders' Ingot" },
    { minLevel = 40, maxLevel = 60, classId = 10, itemName = "Grade 3 Skybuilders' Rivets" },
    { minLevel = 40, maxLevel = 60, classId = 11, itemName = "Grade 3 Skybuilders' Wire" },
    { minLevel = 40, maxLevel = 60, classId = 12, itemName = "Grade 3 Skybuilders' Leather" },
    { minLevel = 40, maxLevel = 60, classId = 13, itemName = "Grade 3 Skybuilders' Cloth" },
    { minLevel = 40, maxLevel = 60, classId = 14, itemName = "Grade 3 Skybuilders' Ink" },
    { minLevel = 40, maxLevel = 60, classId = 15, itemName = "Grade 3 Skybuilders' Stew" },
    
    -- Level 60-70 (Grade 3 Expert)
    { minLevel = 60, maxLevel = 70, classId = 8,  itemName = "Grade 3 Artisanal Skybuilders' Composite Bow" },
    { minLevel = 60, maxLevel = 70, classId = 9,  itemName = "Grade 3 Artisanal Skybuilders' Chandelier" },
    -- Add more as needed
    
    -- Level 70-80 (Grade 4)
    { minLevel = 70, maxLevel = 80, classId = 8,  itemName = "Grade 4 Skybuilders' Plywood" },
    { minLevel = 70, maxLevel = 80, classId = 9,  itemName = "Grade 4 Skybuilders' Ingot" },
    { minLevel = 70, maxLevel = 80, classId = 10, itemName = "Grade 4 Skybuilders' Rivets" },
    { minLevel = 70, maxLevel = 80, classId = 11, itemName = "Grade 4 Skybuilders' Wire" },
    { minLevel = 70, maxLevel = 80, classId = 12, itemName = "Grade 4 Skybuilders' Leather" },
    { minLevel = 70, maxLevel = 80, classId = 13, itemName = "Grade 4 Skybuilders' Cloth" },
    { minLevel = 70, maxLevel = 80, classId = 14, itemName = "Grade 4 Skybuilders' Ink" },
    { minLevel = 70, maxLevel = 80, classId = 15, itemName = "Grade 4 Skybuilders' Stew" },
}

function GetFirmamentRecipe(classId, level)
    -- Get appropriate Firmament recipe for class and level
    for _, recipe in ipairs(FirmamentRecipes) do
        if recipe.classId == classId and level >= recipe.minLevel and level < recipe.maxLevel then
            return recipe
        end
    end
    return nil
end

function GoToFirmament()
    -- Teleport to Firmament
    Log("Traveling to Firmament")
    
    -- Teleport to Foundation first
    TeleportTo("Foundation")
    WaitUntilReady()
    
    -- Use Lifestream to enter Firmament
    yield("/li Firmament")
    Wait(5)
    
    WaitUntilReady()
end

function DoDiademGathering()
    -- Enter Diadem for gathering materials
    Log("Entering Diadem for gathering")
    Echo("Entering Diadem...")
    
    GoToFirmament()
    
    -- Navigate to Aurvael (Diadem entry NPC)
    NavigateToPoint(10.5, -16.0, -97.5)
    Wait(1)
    
    yield("/target Aurvael")
    Wait(1)
    yield("/interact")
    Wait(2)
    
    -- Handle Diadem entry
    if Addons.GetAddon("ContentsFinderConfirm").Ready then
        yield("/callback ContentsFinderConfirm true 8")  -- Enter
        Wait(5)
    end
    
    -- Wait for zone transition
    WaitUntilReady()
    
    -- In Diadem - use GatherBuddy to gather Skybuilders materials
    if HasGatherBuddy() then
        Echo("Gathering in Diadem...")
        yield("/gatherbuddy auto on")
        
        -- Gather for a set time or until inventory full
        local gatherTime = 600  -- 10 minutes
        local startTime = os.clock()
        
        while os.clock() - startTime < gatherTime do
            if GetFreeInventorySlots() < 5 then
                Log("Inventory nearly full, leaving Diadem")
                break
            end
            Wait(30)
        end
        
        yield("/gatherbuddy auto off")
    end
    
    -- Leave Diadem
    yield("/return")
    Wait(5)
    WaitUntilReady()
end

function DoFirmamentCraft(classId)
    -- Craft Firmament items for XP
    local level = GetClassLevel(classId)
    local recipe = GetFirmamentRecipe(classId, level)
    
    if not recipe then
        Log("No Firmament recipe for class " .. classId .. " at level " .. level)
        return false
    end
    
    Log("Crafting Firmament item: " .. recipe.itemName)
    Echo("Firmament crafting: " .. recipe.itemName)
    
    GoToFirmament()
    
    -- Craft using Artisan
    yield("/artisan")
    Wait(30)  -- Artisan handles recipe selection
    
    -- Navigate to Potkin (turn-in NPC)
    NavigateToPoint(-16.0, -16.0, -97.0)
    Wait(1)
    
    yield("/target Potkin")
    Wait(1)
    yield("/interact")
    Wait(2)
    
    -- Turn in items
    if Addons.GetAddon("HWDSupply").Ready then
        -- Turn in all Skybuilders items
        yield("/callback HWDSupply true 0")  -- Turn in tab
        Wait(1)
        yield("/callback HWDSupply true 1")  -- Confirm
        Wait(2)
        
        -- Close
        yield("/callback HWDSupply true -1")
    end
    
    return true
end

--#endregion Firmament Functions

--#region Material Sourcing Functions

function GetMaterialRequirements(recipeId)
    -- Get the materials needed for a recipe
    if MaterialRequirements[recipeId] then
        return MaterialRequirements[recipeId]
    end
    return nil
end

function CheckMaterialsAvailable(recipeId, craftCount)
    -- Check if we have enough materials for the recipe
    -- This uses Artisan's material checking or inventory lookup
    
    local requirements = GetMaterialRequirements(recipeId)
    if not requirements then
        -- No material database entry, assume Artisan will handle it
        return true, nil
    end
    
    local missingMaterials = {}
    
    for _, material in ipairs(requirements) do
        local needed = material.quantity * craftCount
        local have = Inventory.GetItemCount(material.itemName) or 0
        
        if have < needed then
            table.insert(missingMaterials, {
                itemName = material.itemName,
                gathererClass = material.gathererClass,
                needed = needed - have
            })
        end
    end
    
    if #missingMaterials > 0 then
        return false, missingMaterials
    end
    
    return true, nil
end

function StartMaterialGathering(missingMaterials, originalCrafterClass)
    -- Setup gathering state and switch to gathering mode
    Log("Need to gather materials - missing " .. #missingMaterials .. " types")
    
    PreviousCrafterClass = originalCrafterClass
    MaterialsToGather = missingMaterials
    CurrentMaterialIndex = 1
    
    -- Log what we need
    for i, mat in ipairs(missingMaterials) do
        Log("  " .. i .. ". " .. mat.itemName .. " x" .. mat.needed)
    end
    
    CurrentState = State.GATHERING_MATERIALS
end

function DoMaterialGatheringCycle()
    -- Gather materials for crafting
    
    if CurrentMaterialIndex > #MaterialsToGather then
        -- All materials gathered, return to crafting
        Log("All materials gathered, returning to crafter")
        
        if PreviousCrafterClass then
            SwitchToClass(PreviousCrafterClass)
        end
        
        -- Clear gathering state
        MaterialsToGather = {}
        CurrentMaterialIndex = 1
        PreviousCrafterClass = nil
        
        -- Go back to buffing (which will proceed to crafting)
        CurrentState = State.BUFFING
        return
    end
    
    local material = MaterialsToGather[CurrentMaterialIndex]
    Log("Gathering: " .. material.itemName .. " (need " .. material.needed .. ")")
    
    -- Check if gatherer level is high enough
    local requiredLevel = material.requiredLevel or 1
    local gathererLevel = GetClassLevel(material.gathererClass)
    
    if gathererLevel < requiredLevel then
        -- Gatherer is too low level! Need to level it first
        Log("Gatherer level " .. gathererLevel .. " too low, need level " .. requiredLevel)
        Echo("Gatherer too low (Lv" .. gathererLevel .. "), need Lv" .. requiredLevel .. " - leveling first!")
        
        -- Save pending crafter info to return to later
        PendingCrafter = PreviousCrafterClass
        PendingRecipe = material  -- Save what we were trying to gather
        RequiredGathererLevel = requiredLevel
        GathererBeingLeveled = material.gathererClass
        
        -- Switch to leveling this gatherer
        CurrentState = State.LEVELING_GATHERER
        return
    end
    
    -- Switch to appropriate gatherer class
    local currentClass = GetCurrentClassId()
    if currentClass ~= material.gathererClass then
        Log("Switching to gatherer class: " .. material.gathererClass)
        if not SwitchToClass(material.gathererClass) then
            Echo("Failed to switch to gatherer class!")
            CurrentState = State.ERROR
            return
        end
        Wait(1)
    end
    
    -- Ensure gatherer buff
    EnsureBuff(material.gathererClass)
    
    -- Use GatherBuddy to gather the specific item
    if HasGatherBuddy() then
        Log("Using GatherBuddy to gather: " .. material.itemName)
        
        -- Queue the item in GatherBuddy
        -- We won't use 'auto on' because it requires a preset list.
        -- Instead, we spam/monitor the 'gather' command which acts as a ONE-OFF gather.
        
        Log("Gathering via command loop (Bypassing Auto-Scheduler)")
        
        local startTime = os.clock()
        local timeout = 600  -- 10 minute timeout per material
        local startCount = Inventory.GetItemCount(material.itemName) or 0
        local lastGatherCommand = 0
        
        while true do
            local currentCount = Inventory.GetItemCount(material.itemName) or 0
            local gathered = currentCount - startCount
            
            if gathered >= material.needed then
                Log("Gathered enough " .. material.itemName)
                break
            end
            
            if os.clock() - startTime > timeout then
                Log("Gathering timeout for " .. material.itemName)
                break
            end
            
            -- Re-issue gather command if we are idle (not gathering, not moving)
            -- Condition 6: Gathering, 32: Quest, 45: BetweenAreas
            local isBusy = Svc.Condition[6] or Svc.Condition[45] or Svc.Condition[32]
            local isMoving = Svc.Condition[70] or (IPC.vnavmesh.PathfindInProgress and IPC.vnavmesh.PathfindInProgress())
            
            if not isBusy and not isMoving and (os.clock() - lastGatherCommand > 5) then
                 Log("Issuing gather command for " .. material.itemName)
                 yield("/gatherbuddy gather \"" .. material.itemName .. "\"")
                 lastGatherCommand = os.clock()
            end
            
            -- Check inventory mostly full
            if GetFreeInventorySlots() < 3 then
                Log("Inventory full, pausing gathering")
                break
            end
            
            Wait(1)
        end
        
        -- Stop any moving
        if IPC.vnavmesh.PathfindInProgress() then
            IPC.vnavmesh.Stop()
        end
        Wait(1)
        
        -- Check success
        local endCount = Inventory.GetItemCount(material.itemName) or 0
        if (endCount - startCount) >= material.needed then
            Log("Gathering complete for " .. material.itemName)
            -- Move to next material
            CurrentMaterialIndex = CurrentMaterialIndex + 1
        end
    else
        -- No GatherBuddy - show guidance
        Echo("Need to gather: " .. material.itemName .. " x" .. material.needed)
        Echo("Install GatherBuddyReborn for automatic gathering")
        Wait(10)
    end
    
    -- Move to next material
    CurrentMaterialIndex = CurrentMaterialIndex + 1
end

function DoGathererLevelingCycle()
    -- Level up a gatherer so we can gather required materials
    local gathererClass = GathererBeingLeveled
    local targetLevel = RequiredGathererLevel
    
    if not gathererClass or targetLevel <= 0 then
        Log("No gatherer leveling target set, returning to idle")
        CurrentState = State.IDLE
        return
    end
    
    -- Check current level
    local currentLevel = GetClassLevel(gathererClass)
    Log("Leveling gatherer class " .. gathererClass .. ": Level " .. currentLevel .. "/" .. targetLevel)
    
    -- Check if we've reached target level
    if currentLevel >= targetLevel then
        Log("Gatherer reached required level " .. targetLevel .. "!")
        Echo("Gatherer now level " .. currentLevel .. ", returning to materials!")
        
        -- Return to gathering materials (which will now succeed)
        -- Restore the previous crafter class info
        PreviousCrafterClass = PendingCrafter
        
        -- Clear the leveling state
        PendingCrafter = nil
        PendingRecipe = nil
        RequiredGathererLevel = 0
        GathererBeingLeveled = nil
        
        -- Go back to gathering materials
        CurrentState = State.GATHERING_MATERIALS
        return
    end
    
    -- Switch to the gatherer if needed
    local currentClass = GetCurrentClassId()
    if currentClass ~= gathererClass then
        Log("Switching to gatherer class for leveling")
        if not SwitchToClass(gathererClass) then
            Echo("Failed to switch to gatherer!")
            CurrentState = State.ERROR
            return
        end
        Wait(1)
    end
    
    -- Ensure buff
    EnsureBuff(gathererClass)
    
    -- Use GatherBuddy to level via specific item gathering
    -- (Fixed: No longer uses 'auto on' which requires presets)
    
    if HasGatherBuddy() then
        -- Find an appropriate item to gather for XP
        -- We'll check our MaterialRequirements DB for something close to our level
        local bestItem = nil
        local bestLevelDiff = 999
        
        for id, req in pairs(MaterialRequirements) do
            for _, mat in ipairs(req) do
                if mat.gathererClass == gathererClass then
                    local diff = math.abs(mat.requiredLevel - currentLevel)
                    -- We want item <= currentLevel but close to it
                    if mat.requiredLevel <= currentLevel and diff < bestLevelDiff then
                        bestLevelDiff = diff
                        bestItem = mat.itemName
                    end
                end
            end
        end
        
        -- Fallback items if DB is empty for this range
        if not bestItem then
            if gathererClass == 16 then bestItem = "Copper Ore" -- MIN default
            elseif gathererClass == 17 then bestItem = "Latex" -- BTN default
            end
        end
        
        if bestItem then
            Log("Leveling gatherer using item: " .. bestItem)
            
            -- Use our manual gathering loop
            local startTime = os.clock()
            local duration = 300 -- 5 mins
            local lastGather = 0
            
            while os.clock() - startTime < duration do
                local isBusy = Svc.Condition[6] or Svc.Condition[45] or Svc.Condition[32]
                local isMoving = Svc.Condition[70] or (IPC.vnavmesh.PathfindInProgress and IPC.vnavmesh.PathfindInProgress())
                
                if not isBusy and not isMoving and (os.clock() - lastGather > 5) then
                     yield("/gatherbuddy gather \"" .. bestItem .. "\"")
                     lastGather = os.clock()
                end
                
                -- Check for level up
                if GetClassLevel(gathererClass) > currentLevel then
                    Log("Level up detected!")
                    break
                end
                
                Wait(1)
            end
            
            if IPC.vnavmesh.PathfindInProgress() then IPC.vnavmesh.Stop() end
        else
            Log("Could not find item to level gatherer")
        end
        
    else
        Echo("GatherBuddyReborn required for auto-leveling!")
        Echo("Please level gatherer to " .. targetLevel .. " manually")
        Wait(30)
    end
    
    -- Stay in this state and loop (will check level again at top)
end

--#region Fisher Functions

function IsOceanFishingAvailable()
    -- Check if Ocean Fishing NPC is available/boarding
    -- NPC: Dryskthota in Limsa Lower Decks (X:3.2, Y:12.8, Z:0.0)
    
    -- Teleport to Limsa if not there (Ocean Fishing is only in Limsa)
    local limsaZone = 129
    if Svc.ClientState.TerritoryType ~= limsaZone then
        return false -- Too far to check quickly, rely on schedule or assume false unless main loop sends us
    end
    
    -- Just try to target the NPC and see if boarding is open
    -- This is a bit hacky, but robust enough
    
    return UseOceanFishing -- Placeholder for real schedule check
end

function RunSNDFishing(minutes)
    -- Native fishing loop using SND commands (no AutoHook required)
    Log("Starting native fishing loop for " .. minutes .. " minutes")
    
    local startTime = os.clock()
    local endTime = startTime + (minutes * 60)
    local castTime = 0
    
    while os.clock() < endTime and not StopScript do
        local isFishing = GetCharacterCondition(28) -- Fishing
        local isBaiting = GetCharacterCondition(29) -- Baiting/Bite
        
        if not isFishing and not isBaiting then
            -- Not fishing, cast output
            yield("/ac Cast")
            castTime = os.clock()
            Wait(2)
        elseif isBaiting then
            -- Fish bit! Hook it!
            -- Use Hookset if Patience is active, otherwise normal Hook
            if Snd.HasStatus(764) then -- Patience II?
               yield("/ac \"Powerful Hookset\"") -- Simplification
            else
               yield("/ac Hook") 
            end
            Wait(3) -- Wait for animation
        elseif isFishing then
            -- Waiting for bite...
            -- Timeout check (e.g., 20s max wait?)
            if os.clock() - castTime > 25 then
                -- Cast stuck?
                yield("/ac Quit")
                Wait(1)
            end
        end
        
        -- Check inventory space periodically
        if GetFreeInventorySlots() <= 3 then
             -- Cleanup needed
             break
        end

        Wait(0.1)
    end
end

function DoFisherLevelingCycle()
    -- Special logic for Fisher leveling
    local level = GetCurrentLevel()
    
    -- 0. Check AutoHook availability
    if HasPlugin("AutoHook") then
        yield("/autohook on")
    end
    
    -- 1. Ocean Fishing (Priority)
    if UseOceanFishing and level >= 1 then
        -- Check UTC time for window (every odd hour usually)
        local utcHour = tonumber(os.date("!%H"))
        if utcHour % 2 == 1 then -- Odd hour window
             Log("Ocean Fishing window potentially open (UTC " .. utcHour .. ")")
             
             -- Go to Limsa to check
             TeleportTo("Limsa Lominsa Lower Decks")
             WaitUntilReady()
             NavigateToPoint(-410.0, 3.0, 75.0) -- Near Dryskthota
             
             -- Try to board
             yield("/target Dryskthota")
             Wait(1)
             yield("/interact")
             Wait(2)
             
             -- If queue window pops...
             if Addons.GetAddon("SelectYesno").Ready then
                  yield("/callback SelectYesno true 0") -- Yes (Board)
                  Wait(10) -- Wait for queue/enter
                  
                  -- Inside instance?
                  if Svc.ClientState.TerritoryType == 900 then -- Ocean Fishing zone ID (example)
                      Log("Entered Ocean Fishing!")
                      RunSNDFishing(20) -- Fish for 20 mins
                      return
                  end
             end
        end
    end
    
    -- 2. Leves (Disabled for Fisher due to complexity of dynamic fish ID)
    -- if UseLeves then
    --      if DoLeveQuest(18, level) then
    --          return
    --      end
    -- end
    
    -- 3. Grinding fallback (Native)
    Echo("Fisher leveling fallback: Casting line...")
    RunSNDFishing(5) -- Fish for 5 mins then check state
end

--#endregion Fisher Functions    

function CheckAndSourceMaterials(recipeId, craftCount)
    -- Main function to check materials and initiate gathering if needed
    local hasEnough, missingMaterials = CheckMaterialsAvailable(recipeId, craftCount)
    
    if hasEnough then
        return true
    end
    
    -- Check retainers if enabled
    if AutoRetrieverMaterials and HasPlugin("AutoRetainer") then
        local retrievedAny = false
        -- Optimize: only check if we have missing materials that are likely on retainers
        -- For now, just check all missing materials
        
        -- We don't want to check retainers every single tick if they are empty
        -- So maybe we should have a flag or timer?
        -- For simplicity in this script: Check once per unique missing material set?
        -- Or just check. CheckRetainerMaterials is smart enough to skip if we have enough now.
        
        for _, mat in ipairs(missingMaterials) do
            local newCount = CheckRetainerMaterials(mat.itemName, mat.needed)
            -- CheckRetainerMaterials handles the navigation/interaction
        end
        
        -- Re-check availability after retainer check
        hasEnough, missingMaterials = CheckMaterialsAvailable(recipeId, craftCount)
        if hasEnough then
            Log("Retainers provided enough materials")
            return true
        end
    end
    
    -- Try Artisan first to craft intermediates
    if HasPlugin("Artisan") then
        Log("Trying Artisan to craft intermediate materials...")
        -- Artisan may be able to craft the intermediates from sub-materials
        -- Give it a chance before we go gathering
        yield("/artisan")
        Wait(3)
        
        -- Re-check after Artisan attempt
        hasEnough, missingMaterials = CheckMaterialsAvailable(recipeId, craftCount)
        if hasEnough then
            return true
        end
    end
    
    -- Need to gather base materials
    local originalClass = GetCurrentClassId()
    StartMaterialGathering(missingMaterials, originalClass)
    
    return false  -- Will need to gather first
end

function DoGathererLevelingCycle()
    -- Level up a gatherer so we can gather required materials
    local gathererClass = GathererBeingLeveled
    local targetLevel = RequiredGathererLevel
    
    if not gathererClass or targetLevel <= 0 then
        Log("No gatherer leveling target set, returning to idle")
        CurrentState = State.IDLE
        return
    end
    
    -- Check current level
    local currentLevel = GetClassLevel(gathererClass)
    Log("Leveling gatherer class " .. gathererClass .. ": Level " .. currentLevel .. "/" .. targetLevel)
    
    -- Check if we've reached target level
    if currentLevel >= targetLevel then
        Log("Gatherer reached required level " .. targetLevel .. "!")
        Echo("Gatherer now level " .. currentLevel .. ", returning to materials!")
        
        -- Return to gathering materials (which will now succeed)
        -- Restore the previous crafter class info
        PreviousCrafterClass = PendingCrafter
        
        -- Clear the leveling state
        PendingCrafter = nil
        PendingRecipe = nil
        RequiredGathererLevel = 0
        GathererBeingLeveled = nil
        
        -- Go back to gathering materials
        CurrentState = State.GATHERING_MATERIALS
        return
    end
    
    -- Switch to the gatherer if needed
    local currentClass = GetCurrentClassId()
    if currentClass ~= gathererClass then
        Log("Switching to gatherer class for leveling")
        if not SwitchToClass(gathererClass) then
            Echo("Failed to switch to gatherer!")
            CurrentState = State.ERROR
            return
        end
        Wait(1)
    end
    
    -- Ensure buff
    EnsureBuff(gathererClass)
    
    -- Use GatherBuddy to level via collectables or regular gathering
    if HasGatherBuddy() then
        -- At higher levels (50+), use collectables for faster XP
        if currentLevel >= 50 then
            Log("Using collectable gathering for faster XP")
            yield("/gatherbuddy collectables on")
        else
            Log("Using regular auto-gather")
            yield("/gatherbuddy auto on")
        end
        
        -- Gather for a while (or until level up detected)
        local startLevel = currentLevel
        local startTime = os.clock()
        local gatherDuration = 120  -- 2 minutes per cycle
        
        while os.clock() - startTime < gatherDuration do
            -- Check for level up
            local newLevel = GetClassLevel(gathererClass)
            if newLevel > startLevel then
                Log("Level up! Now level " .. newLevel)
                break
            end
            
            -- Check inventory
            if GetFreeInventorySlots() < MinInventorySlots then
                Log("Inventory getting full during gatherer leveling")
                -- Do a quick turn-in
                yield("/gatherbuddy auto off")
                TurnInCollectables()
                yield("/gatherbuddy auto on")
            end
            
            Wait(5)
        end
        
        -- Stop gathering
        yield("/gatherbuddy auto off")
        yield("/gatherbuddy collectables off")
        Wait(1)
        
        -- Turn in collectables for XP
        TurnInCollectables()
        
    else
        Echo("GatherBuddyReborn required for auto-leveling!")
        Echo("Please level gatherer to " .. targetLevel .. " manually")
        Wait(30)
    end
    
    -- Stay in this state and loop (will check level again at top)
end

--#endregion Material Sourcing Functions

--#region Gear Management Functions

function GetRequiredGearTier(level)
    -- Get the scrip gear tier for a given level
    for _, tier in ipairs(ScripGearTiers) do
        if level >= tier.minLevel and level < tier.maxLevel then
            return tier
        end
    end
    return ScripGearTiers[#ScripGearTiers] -- Highest tier
end

function CheckGearLevel(classId, level)
    -- Check if current gear is appropriate for the level
    -- This is a simplified check - in practice Artisan handles stat requirements
    
    if level < 50 then
        -- Low level gear doesn't matter much
        return true
    end
    
    local requiredTier = GetRequiredGearTier(level)
    if not requiredTier then
        return true
    end
    
    -- Check craftsmanship/gathering stat vs expected minimum
    -- These are rough minimums for each tier
    local minStats = {
        [50] = 300,
        [60] = 800,
        [70] = 1500,
        [80] = 2500,
        [90] = 3500
    }
    
    local tierLevel = requiredTier.minLevel
    local requiredStat = minStats[tierLevel] or 0
    
    -- Get current stats (this uses game client data)
    local currentStat = 0
    if IsCrafter(classId) then
        currentStat = Player.Craftsmanship or 0
    else
        currentStat = Player.Gathering or 0
    end
    
    if currentStat < requiredStat then
        Log("Gear check: Current stat " .. currentStat .. " < required " .. requiredStat)
        return false
    end
    
    return true
end

function DoGearUpgrade()
    -- Upgrade gear using scrips and Stylist
    local classId = GetCurrentClassId()
    local level = GetCurrentLevel()
    local tier = GetRequiredGearTier(level)
    
    if not tier then
        Log("No gear tier found for level " .. level)
        CurrentState = State.IDLE
        return
    end
    
    Log("Upgrading gear to tier: " .. tier.setName .. " (" .. tier.scripType .. " scrips)")
    Echo("Upgrading gear - " .. tier.setName .. " set")
    
    local hub = GetSelectedHub()
    
    -- Go to hub for scrip vendor
    if Svc.ClientState.TerritoryType ~= hub.zoneId then
        GoToHub()
        Wait(2)
    end
    
    -- Navigate to scrip exchange
    NavigateToPoint(hub.scripExchange.x, hub.scripExchange.y, hub.scripExchange.z)
    Wait(1)
    
    -- Target Scrip Exchange
    yield("/target Scrip Exchange")
    Wait(1)
    yield("/interact")
    Wait(2)
    
    -- Wait for shop window
    local timeout = 10
    local startTime = os.clock()
    while not Addons.GetAddon("ShopExchangeItem").Ready do
        if os.clock() - startTime > timeout then
            Log("Scrip Exchange not opening, using Stylist fallback")
            break
        end
        Wait(0.5)
    end
    
    -- Auto-buy is not fully supported due to complexity of item IDs
    -- Notify user to purchase the set
    if Addons.GetAddon("ShopExchangeItem").Ready then
        Echo("IMPORTANT: Please purchase " .. tier.setName .. " gear manually!")
        Echo("Waiting 30 seconds for you to buy gear...")
        
        -- Select category helper
        if tier.scripType == "orange" then
            yield("/callback ShopExchangeItem true 1 1")
        else
            yield("/callback ShopExchangeItem true 1 0")
        end
        
        -- Wait for user to buy
        Wait(30)
        
        -- Close shop
        yield("/callback ShopExchangeItem true -1")
        Wait(1)
    end
    
    -- Use Stylist to auto-update all gearsets with best available items
    if HasPlugin("Stylist") then
        Log("Running Stylist to update gearsets")
        Echo("Updating gearsets with best gear...")
        
        -- This command updates all gearsets with the best items you own
        yield("/stylist all")
        Wait(5)
        
        Echo("Gearsets updated!")
    else
        Echo("Install Stylist plugin for auto gearset updates")
    end
    
    -- After upgrades, check if we should dispose of old gear
    if AutoDesynthGear then
        CurrentState = State.DISPOSING_GEAR
    else
        CurrentState = State.IDLE
    end
end

function DisposeOldGear()
    -- Dispose of excess gear via desynth or GC turn-in
    -- IMPORTANT: Protect items in gearsets
    
    Log("Disposing of excess gear (protecting gearsets)")
    Echo("Cleaning up old gear...")
    
    -- Save current class to restore later
    local originalClassId = GetCurrentClassId()
    
    -- Desynthesis requires a crafter class
    -- Switch to lowest-level crafter for maximum skill-up potential
    local lowestCrafter = nil
    local lowestLevel = 999
    
    for _, class in ipairs(CrafterClasses) do
        local level = GetClassLevel(class.id)
        if level >= 30 and level < lowestLevel then  -- Desynth unlocks at 30
            lowestLevel = level
            lowestCrafter = class
        end
    end
    
    -- If no crafter at 30+, just use any crafter
    if not lowestCrafter then
        for _, class in ipairs(CrafterClasses) do
            local level = GetClassLevel(class.id)
            if level >= 1 then
                lowestCrafter = class
                break
            end
        end
    end
    
    -- Switch to crafter for desynth
    if lowestCrafter and not IsCrafter(originalClassId) then
        Log("Switching to " .. lowestCrafter.name .. " for desynthesis")
        SwitchToClass(lowestCrafter.id)
        Wait(1)
    end
    
    -- First, try desynthesis for skill-ups (requires crafter class)
    local currentClassId = GetCurrentClassId()
    if IsCrafter(currentClassId) and GetClassLevel(currentClassId) >= 30 then
        Log("Attempting desynthesis on " .. (GetClassById(currentClassId) and GetClassById(currentClassId).name or "crafter"))
        
        -- Open desynthesis window
        yield("/generalaction Desynthesis")
        Wait(2)
        
        if Addons.GetAddon("SalvageItemSelector").Ready then
            -- Desynth items that aren't equipped or in gearsets
            -- The game automatically protects gearset items from desynth
            
            local desynthCount = 0
            local maxDesynth = 20  -- Limit per cycle
            
            while Addons.GetAddon("SalvageItemSelector").Ready and desynthCount < maxDesynth do
                -- Click first available item (game filters out protected items)
                yield("/callback SalvageItemSelector true 0 0")
                Wait(0.5)
                
                -- Confirm desynth
                if Addons.GetAddon("SalvageDialog").Ready then
                    yield("/callback SalvageDialog true 0")
                    Wait(1)
                    desynthCount = desynthCount + 1
                else
                    -- No more items to desynth
                    break
                end
            end
            
            -- Close desynth window
            if Addons.GetAddon("SalvageItemSelector").Ready then
                yield("/callback SalvageItemSelector true -1")
            end
            
            Log("Desynthed " .. desynthCount .. " items")
        else
            Log("Desynth window didn't open")
        end
        
        Wait(1)
    end
    
    -- GC turn-in for remaining items
    local gc = GetSelectedGC()
    
    Log("Turning in remaining gear to Grand Company")
    TeleportTo(gc.aetheryte)
    WaitUntilReady()
    
    -- Navigate to Personnel Officer for GC item turn-in
    NavigateToPoint(gc.quartermaster.x, gc.quartermaster.y, gc.quartermaster.z)
    Wait(1)
    
    -- Target personnel officer (near quartermaster)
    if gc.name == "Maelstrom" then
        yield("/target Storm Personnel Officer")
    elseif gc.name == "Twin Adder" then
        yield("/target Serpent Personnel Officer")
    else
        yield("/target Flame Personnel Officer")
    end
    Wait(1)
    yield("/interact")
    Wait(2)
    
    -- Select Expert Delivery
    if Addons.GetAddon("GrandCompanySupplyList").Ready then
        yield("/callback GrandCompanySupplyList true 1") -- Expert Delivery tab
        Wait(1)
        
        -- Turn in items (game protects gearset items automatically)
        local turnInCount = 0
        local maxTurnIn = 30
        
        while Addons.GetAddon("GrandCompanySupplyList").Ready and turnInCount < maxTurnIn do
            yield("/callback GrandCompanySupplyList true 0 0") -- First item
            Wait(0.5)
            
            if Addons.GetAddon("SelectYesno").Ready then
                yield("/callback SelectYesno true 0")
                Wait(0.5)
                turnInCount = turnInCount + 1
            else
                break
            end
        end
        
        -- Close
        yield("/callback GrandCompanySupplyList true -1")
        Log("Turned in " .. turnInCount .. " items for GC seals")
    end
    
    Wait(1)
    Echo("Gear cleanup complete!")
    
    -- Restore original class if we switched for desynth
    if originalClassId and GetCurrentClassId() ~= originalClassId then
        Log("Restoring original class after gear disposal")
        SwitchToClass(originalClassId)
        Wait(1)
    end
    
    CurrentState = State.IDLE
end

--#endregion Gear Management Functions

--#region Class Functions

function GetClassById(classId)
    for _, class in ipairs(CrafterClasses) do
        if class.id == classId then return class end
    end
    for _, class in ipairs(GathererClasses) do
        if class.id == classId then return class end
    end
    return nil
end

function GetClassByAbbr(abbr)
    abbr = string.upper(abbr)
    for _, class in ipairs(CrafterClasses) do
        if class.abbr == abbr then return class end
    end
    for _, class in ipairs(GathererClasses) do
        if class.abbr == abbr then return class end
    end
    return nil
end

function GetCurrentClassId()
    return Player.Job
end

function GetCurrentLevel()
    return Player.Level
end

function GetClassLevel(classId)
    -- Use Artisan or player data to get class level
    local levels = Player.Levels
    if levels and levels[classId] then
        return levels[classId]
    end
    return 0
end

function IsCrafter(classId)
    return classId >= 8 and classId <= 15
end

function IsGatherer(classId)
    return classId >= 16 and classId <= 18
end

function SwitchToClass(classId)
    Log("Switching to class ID: " .. classId)
    local class = GetClassById(classId)
    if not class then
        Log("Unknown class ID: " .. classId)
        return false
    end
    
    -- Use gearset command
    yield("/gs change " .. class.name)
    Wait(1)
    
    -- Verify switch
    local attempts = 0
    while GetCurrentClassId() ~= classId and attempts < 10 do
        Wait(0.5)
        attempts = attempts + 1
    end
    
    if GetCurrentClassId() == classId then
        Log("Successfully switched to " .. class.name)
        return true
    else
        Log("Failed to switch to " .. class.name)
        return false
    end
end

--#endregion Class Functions

--#region Travel Functions

function GetSelectedHub()
    for _, hub in ipairs(HubCities) do
        if hub.name == HubCity then
            return hub
        end
    end
    return HubCities[4] -- Default to Solution Nine
end

function TeleportTo(aetheryteName)
    Log("Teleporting to " .. aetheryteName)
    
    -- Use Lifestream teleport
    yield("/li tp " .. aetheryteName)
    Wait(1)
    
    -- Wait for cast
    while Svc.Condition[CharacterCondition.casting] do
        Wait(0.5)
    end
    
    -- Wait for zone transition
    Wait(1)
    while Svc.Condition[CharacterCondition.betweenAreas] or 
          Svc.Condition[CharacterCondition.betweenAreas51] do
        Wait(0.5)
    end
    
    WaitUntilReady()
    Log("Teleport complete")
end

function NavigateToPoint(x, y, z)
    if GetDistanceToPoint(x, y, z) < 3 then
        return true
    end
    
    Log(string.format("Navigating to (%.1f, %.1f, %.1f)", x, y, z))
    yield(string.format("/vnav moveto %.2f %.2f %.2f", x, y, z))
    
    -- Wait for navigation to complete
    local timeout = 60
    local startTime = os.clock()
    
    while GetDistanceToPoint(x, y, z) > 3 do
        if os.clock() - startTime > timeout then
            Log("Navigation timeout!")
            yield("/vnav stop")
            return false
        end
        Wait(0.5)
    end
    
    yield("/vnav stop")
    Wait(0.5)
    return true
end

function GoToHub()
    local hub = GetSelectedHub()
    local currentZone = Svc.ClientState.TerritoryType
    
    if currentZone ~= hub.zoneId then
        TeleportTo(hub.name)
    end
    
    return true
end

--#endregion Travel Functions

--#region Crafting Functions

function GetCollectableRecipe(classId, level)
    -- Level 90-100: Use Orange Scrip Collectables
    if level >= 90 then
        for _, recipe in ipairs(OrangeScripCrafts) do
            if recipe.classId == classId then
                return recipe
            end
        end
    end
    
    -- Level 50-90: Use level-appropriate collectables
    for _, recipe in ipairs(CollectableCrafts) do
        if recipe.classId == classId and 
           level >= recipe.minLevel and 
           level < recipe.maxLevel then
            return recipe
        end
    end
    
    return nil
end

function StartArtisanCraft(recipeId, quantity)
    Log("Starting Artisan craft: Recipe " .. recipeId .. " x" .. quantity)
    
    -- Use Artisan IPC to craft
    if HasPlugin("Artisan") then
        IPC.Artisan.CraftItem(recipeId, quantity)
        return true
    else
        -- Fallback: Open recipe in crafting log
        yield("/craftinglog")
        Wait(1)
        return false
    end
end

function WaitForCraftingComplete()
    -- Wait for Artisan to finish
    while IPC.Artisan.GetEnduranceStatus() or 
          IPC.Artisan.IsListRunning() or
          Svc.Condition[CharacterCondition.crafting] or
          Svc.Condition[CharacterCondition.craftingModeIdle] do
        Wait(1)
    end
end

function DoCraftingCycle()
    local classId = GetCurrentClassId()
    local level = GetCurrentLevel()
    
    Log("Crafting cycle for class " .. classId .. " at level " .. level)
    
    -- Check inventory space
    if GetFreeInventorySlots() < MinInventorySlots then
        Log("Low inventory, going to turn in")
        CurrentState = State.TURNING_IN
        return
    end
    
    -- Check repair needs
    if AutoRepair and NeedsRepair() then
        Log("Gear needs repair")
        CurrentState = State.REPAIRING
        return
    end
    
    -- Get appropriate recipe
    local recipe = GetCollectableRecipe(classId, level)
    
    if recipe then
        local craftCount = math.min(10, GetFreeInventorySlots() - MinInventorySlots)
        if craftCount > 0 then
            -- Check if we have materials before crafting
            local hasMaterials = CheckAndSourceMaterials(recipe.recipeId, craftCount)
            
            if not hasMaterials then
                -- State was changed to GATHERING_MATERIALS, will return to crafting after
                Log("Missing materials, switching to gathering mode")
                return
            end
            
            StartArtisanCraft(recipe.recipeId, craftCount)
            WaitForCraftingComplete()
        end
    else
        -- Level 1-50: Quick synthesis spam
        Log("Low level crafting - using quick synthesis")
        yield("/clog")
        Wait(2)
        -- Let Artisan handle it with quick synth
        yield("/artisan quick-synth")
        Wait(30)
    end
    
    -- After crafting, check if we need to turn in
    CurrentState = State.TURNING_IN
end

--#endregion Crafting Functions

--#region Turn-in Functions

function CheckScripCap()
    -- Check if we're near the scrip cap (4000 max)
    -- If so, auto-spend on materia until below 1000
    local orangeScrips = Inventory.GetCurrencyCount(33913) or 0  -- Orange Crafters' Scrip
    local purpleScrips = Inventory.GetCurrencyCount(33914) or 0  -- Purple Crafters' Scrip
    
    if orangeScrips > 3500 then
        Log("Orange Scrips at " .. orangeScrips .. " - auto-spending on materia")
        Echo("Auto-spending scrips on materia...")
        
        -- Navigate to Scrip Exchange
        local hub = GetSelectedHub()
        if Svc.ClientState.TerritoryType ~= hub.zoneId then
            GoToHub()
            Wait(2)
        end
        
        NavigateToPoint(hub.scripExchange.x, hub.scripExchange.y, hub.scripExchange.z)
        Wait(1)
        
        yield("/target Scrip Exchange")
        Wait(1)
        yield("/interact")
        Wait(2)
        
        -- Wait for shop
        local timeout = 10
        local startTime = os.clock()
        while not Addons.GetAddon("ShopExchangeItem").Ready do
            if os.clock() - startTime > timeout then
                Log("Scrip Exchange not opening")
                return false
            end
            Wait(0.5)
        end
        
    -- Helper function to buy items
    local function BuyScripItem(scripType, currentScrips, itemToBuy)
        Log("Auto-spending " .. scripType .. " scrips on: " .. itemToBuy)
        Echo("Spending scrips on " .. itemToBuy .. "...")
        
        -- Navigate to Scrip Exchange
        local hub = GetSelectedHub()
        if Svc.ClientState.TerritoryType ~= hub.zoneId then
            GoToHub()
            Wait(2)
        end
        
        NavigateToPoint(hub.scripExchange.x, hub.scripExchange.y, hub.scripExchange.z)
        Wait(1)
        
        yield("/target Scrip Exchange")
        Wait(1)
        yield("/interact")
        Wait(2)
        
        -- Wait for shop
        local timeout = 10
        local startTime = os.clock()
        while not Addons.GetAddon("ShopExchangeItem").Ready do
            if os.clock() - startTime > timeout then
                Log("Scrip Exchange not opening")
                return false
            end
            Wait(0.5)
        end
        
        -- Select correct category
        if scripType == "Orange" then
            yield("/callback ShopExchangeItem true 1 1") -- Orange Scrips
        else
            yield("/callback ShopExchangeItem true 1 0") -- Purple Scrips
        end
        Wait(0.5)
        
        -- Navigate subcategories to find item? 
        -- Or just deafult to Materia category (Index 0 usually) logic:
        -- Most common dump is Materia X/IX.
        -- We'll default to Materia tab (2 -> 0)
        yield("/callback ShopExchangeItem true 2 0") 
        Wait(0.5)
        
        -- TODO: Search for specific item name would be better but requires complex addon inspection
        -- For now, we assume ItemToBuy is in the first slot OR we just buy the first slot if generic
        -- If user configured "ItemToBuy", we assume they want us to buy WHATEVER is in slot 0 of Materia tab
        -- unless we implement smart searching.
        
        -- Smart search fallback: If default Materia X, it's usually slot 0 or 1.
        -- We will just buy slot 0 for now as 'Dump Item'
        
        local cost = 500 -- Default safety cost
        if scripType == "Purple" then cost = 200 end
        local buyCount = 0
        
        while currentScrips > 1000 do
            yield("/callback ShopExchangeItem true 0 0") -- Buy first item in list
            Wait(0.3)
            
            if Addons.GetAddon("ShopExchangeItemDialog").Ready then
                yield("/callback ShopExchangeItemDialog true 0") -- Confirm
                Wait(0.5)
            end
            
            buyCount = buyCount + 1
            currentScrips = currentScrips - cost
            
            if buyCount >= 10 then break end
        end
        
        yield("/callback ShopExchangeItem true -1") -- Close
        Wait(1)
        Log("Bought " .. buyCount .. " items")
        Echo("Bought " .. buyCount .. " items with " .. scripType .. " scrips")
    end

    if orangeScrips > 3500 then
        BuyScripItem("Orange", orangeScrips, ItemToBuy)
    end
    
    if purpleScrips > 3500 then
        BuyScripItem("Purple", purpleScrips, ItemToBuy)
    end
    
    return true
end

function TurnInCollectables()
    -- Check scrip cap before turning in more
    if not CheckScripCap() then
        Log("Paused for scrip spending")
    end
    
    local hub = GetSelectedHub()
    local currentZone = Svc.ClientState.TerritoryType
    
    -- Make sure we're at the hub
    if currentZone ~= hub.zoneId then
        GoToHub()
        Wait(2)
    end
    
    -- Navigate to scrip exchange
    Log("Navigating to Scrip Exchange")
    NavigateToPoint(hub.scripExchange.x, hub.scripExchange.y, hub.scripExchange.z)
    Wait(1)
    
    -- Target the collectable appraiser
    yield("/target Collectable Appraiser")
    Wait(1)
    
    -- Interact
    yield("/interact")
    Wait(2)
    
    -- Handle the CollectablesShop addon
    local timeout = 10
    local startTime = os.clock()
    
    while not Addons.GetAddon("CollectablesShop").Ready do
        if os.clock() - startTime > timeout then
            Log("CollectablesShop not opening")
            return false
        end
        Wait(0.5)
    end
    
    -- Select crafters scrips tab (category 0 for DoH, 1 for DoL)
    local isCrafter = IsCrafter(GetCurrentClassId())
    local category = isCrafter and 0 or 1
    
    yield("/callback CollectablesShop true 1 " .. category)
    Wait(0.5)
    
    -- Turn in all collectables
    yield("/callback CollectablesShop true 3 0") -- Select first item
    Wait(0.5)
    
    -- Repeat turn-ins until done
    local turnInCount = 0
    while Addons.GetAddon("CollectablesShop").Ready and turnInCount < 50 do
        yield("/callback CollectablesShop true 0 0") -- Confirm turn-in
        Wait(0.5)
        turnInCount = turnInCount + 1
    end
    
    -- Close the window
    if Addons.GetAddon("CollectablesShop").Ready then
        yield("/callback CollectablesShop true -1")
    end
    
    Wait(1)
    Log("Turn-in complete")
    
    return true
end

--#endregion Turn-in Functions

--#region Repair Functions

function DoRepair()
    local hub = GetSelectedHub()
    
    -- Go to hub if needed
    if Svc.ClientState.TerritoryType ~= hub.zoneId then
        GoToHub()
    end
    
    -- Navigate to mender
    NavigateToPoint(hub.repairNpc.x, hub.repairNpc.y, hub.repairNpc.z)
    Wait(1)
    
    -- Target mender
    yield("/target Mender")
    Wait(1)
    yield("/interact")
    Wait(2)
    
    -- Wait for repair menu
    local timeout = 5
    local startTime = os.clock()
    while not Addons.GetAddon("Repair").Ready do
        if os.clock() - startTime > timeout then
            -- Try self-repair instead
            Log("NPC repair failed, trying self-repair")
            yield("/generalaction Repair")
            Wait(2)
            break
        end
        Wait(0.5)
    end
    
    -- Click repair all
    if Addons.GetAddon("Repair").Ready then
        yield("/callback Repair true 0") -- Repair all
        Wait(2)
        
        -- Confirm if needed
        if Addons.GetAddon("SelectYesno").Ready then
            yield("/callback SelectYesno true 0")
            Wait(1)
        end
        
        -- Close
        yield("/callback Repair true -1")
    end
    
    Wait(1)
    Log("Repair complete")
    
    return true
end

--#endregion Repair Functions

--#region Gathering Functions

function DoGatheringCycle()
    local classId = GetCurrentClassId()
    local level = GetCurrentLevel()
    
    Log("Gathering cycle for class " .. classId .. " at level " .. level)
    
    -- Special handling for Fisher
    if classId == 18 then
        DoFisherLevelingCycle()
        return
    end
    
    -- Check if GatherBuddy Reborn is available
    if HasGatherBuddy() then
        -- Find an appropriate item to gather for XP
        -- We'll check our MaterialRequirements DB for something close to our level
        local bestItem = nil
        local bestLevelDiff = 999
        
        for id, req in pairs(MaterialRequirements) do
            for _, mat in ipairs(req) do
                if mat.gathererClass == classId then
                    local diff = math.abs(mat.requiredLevel - level)
                    -- We want item <= currentLevel but close to it
                    if mat.requiredLevel <= level and diff < bestLevelDiff then
                        bestLevelDiff = diff
                        bestItem = mat.itemName
                    end
                end
            end
        end
        
        -- Fallback items if DB is empty for this range
        if not bestItem then
            if classId == 16 then bestItem = "Copper Ore" -- MIN default
            elseif classId == 17 then bestItem = "Latex" -- BTN default
            end
        end
        
        if bestItem then
            Log("Using GatherBuddy to gather: " .. bestItem)
            
            -- Use our manual gathering loop
            local startTime = os.clock()
            local duration = 300 -- 5 minutes per cycle
            local lastGather = 0
            
            while os.clock() - startTime < duration do
                -- Check for level up
                if GetClassLevel(classId) > level then
                    Log("Level up detected!")
                    break
                end
                
                local isBusy = Svc.Condition[6] or Svc.Condition[45] or Svc.Condition[32]
                local isMoving = Svc.Condition[70] or (IPC.vnavmesh.PathfindInProgress and IPC.vnavmesh.PathfindInProgress())
                
                if not isBusy and not isMoving and (os.clock() - lastGather > 5) then
                     yield("/gatherbuddy gather \"" .. bestItem .. "\"")
                     lastGather = os.clock()
                end
                
                -- Check inventory
                if GetFreeInventorySlots() < MinInventorySlots then
                    Log("Inventory full, pausing gathering")
                    CurrentState = State.TURNING_IN
                    return
                end
                
                Wait(1)
            end
            
            if IPC.vnavmesh.PathfindInProgress() then IPC.vnavmesh.Stop() end
        else
            Log("Could not find item to level gatherer")
            Wait(5)
        end
        
    else
        -- Manual gathering guidance
        Echo("GatherBuddy Reborn not found - manual gathering required")
        Echo("Install GatherBuddy Reborn for automatic gathering")
        Wait(10)
    end
end

--#endregion Gathering Functions

--#region Initialization

function Initialize()
    Log("Initializing Universal Leveler...")
    
    -- Verify required plugins
    if not HasPlugin("SomethingNeedDoing") then
        Echo("ERROR: SND plugin not loaded!")
        return false
    end
    
    -- Load saved progress if available
    LoadProgress()
    
    if not HasPlugin("Artisan") then
        Echo("WARNING: Artisan not found - crafting will be limited")
    end
    
    if not HasPlugin("vnavmesh") then
        Echo("WARNING: vnavmesh not found - navigation will be limited")
    end
    
    -- Setup hub
    SelectedHub = GetSelectedHub()
    Log("Using hub: " .. SelectedHub.name)
    
    -- Determine which classes to level based on mode
    ClassesToLevel = {}
    
    if Mode == "All Crafters" then
        for _, class in ipairs(CrafterClasses) do
            table.insert(ClassesToLevel, class)
        end
    elseif Mode == "All Gatherers" then
        for _, class in ipairs(GathererClasses) do
            table.insert(ClassesToLevel, class)
        end
    elseif Mode == "Single Crafter" or Mode == "Single Gatherer" then
        local class = GetClassByAbbr(SingleClass)
        if class then
            table.insert(ClassesToLevel, class)
        else
            Echo("ERROR: Unknown class: " .. SingleClass)
            return false
        end
    elseif Mode == "Everything" then
        for _, class in ipairs(CrafterClasses) do
            table.insert(ClassesToLevel, class)
        end
        for _, class in ipairs(GathererClasses) do
            table.insert(ClassesToLevel, class)
        end
    end
    
    Echo("Classes to level: " .. #ClassesToLevel)
    for _, class in ipairs(ClassesToLevel) do
        Log("  - " .. class.name)
    end
    
    CurrentClassIndex = 1
    CurrentState = State.IDLE
    StopScript = false
    
    Log("Initialization complete")
    Echo("Mode: " .. tostring(Mode) .. ", Target: Lv" .. tostring(TargetLevel))
    Echo("Classes to level: " .. #ClassesToLevel)
    return true
end

--#endregion Initialization

--#region Main Loop

function GetNextClassToLevel()
    -- Find the class with the LOWEST level that is still under TargetLevel
    local lowestClass = nil
    local lowestLevel = 999
    
    for _, class in ipairs(ClassesToLevel) do
        local level = GetClassLevel(class.id)
        if level < TargetLevel and level < lowestLevel then
            lowestLevel = level
            lowestClass = class
        end
    end
    
    if lowestClass then
        Log("Next class to level: " .. lowestClass.name .. " (Lv" .. lowestLevel .. ")")
    end
    
    return lowestClass -- nil if all classes at target
end

function ProcessState()
    if StopScript then
        CurrentState = State.ERROR
    end
    
    if CurrentState == State.IDLE then
        -- Find next class to level
        local nextClass = GetNextClassToLevel()
        
        if not nextClass then
            Echo("All classes have reached level " .. TargetLevel .. "!")
            CurrentState = State.COMPLETE
            return
        end
        
        -- Switch to the class if needed
        if GetCurrentClassId() ~= nextClass.id then
            Log("Need to switch to " .. nextClass.name)
            CurrentState = State.SWITCHING_CLASS
        else
            -- Already on correct class, check buffs first
            CurrentState = State.BUFFING
        end
        
    elseif CurrentState == State.SWITCHING_CLASS then
        local nextClass = GetNextClassToLevel()
        if nextClass and SwitchToClass(nextClass.id) then
            -- After switching class, check buffs
            CurrentState = State.BUFFING
        else
            Wait(2)
        end
        
    elseif CurrentState == State.BUFFING then
        -- Ensure XP buff is active before crafting/gathering
        local classId = GetCurrentClassId()
        local level = GetCurrentLevel()
        EnsureBuff(classId)
        
        -- Special handling for Fisher (18)
        if classId == 18 then
            DoFisherLevelingCycle()
            -- Fisher cycle handles its own loops, stays in state as needed
            -- Or returns here. The loop will continue.
            return true
        end

        -- Check if gear needs upgrade (only if AutoUpgradeGear enabled)
        if AutoUpgradeGear and level >= 50 and not CheckGearLevel(classId, level) then
            Log("Gear insufficient for level " .. level .. ", upgrading")
            CurrentState = State.UPGRADING_GEAR
            return true
        end
        
        -- Check inventory - dispose of old gear if too full (5 or fewer slots)
        if AutoDesynthGear and GetFreeInventorySlots() <= 5 then
            Log("Inventory nearly full, disposing old gear")
            CurrentState = State.DISPOSING_GEAR
            return true
        end
        
        -- Now proceed to actual work
        if IsCrafter(classId) then
            CurrentState = State.CRAFTING
        else
            CurrentState = State.GATHERING
        end
        
    elseif CurrentState == State.UPGRADING_GEAR then
        -- Buying scrip gear and updating gearsets via Stylist
        DoGearUpgrade()
        
    elseif CurrentState == State.DISPOSING_GEAR then
        -- Desynth and GC turn-in for excess gear
        DisposeOldGear()
        
    elseif CurrentState == State.CRAFTING then
        DoCraftingCycle()
        
    elseif CurrentState == State.GATHERING then
        DoGatheringCycle()
        
    elseif CurrentState == State.GATHERING_MATERIALS then
        -- Gathering materials for crafting
        DoMaterialGatheringCycle()
        
    elseif CurrentState == State.LEVELING_GATHERER then
        -- Leveling a gatherer to unlock required materials
        DoGathererLevelingCycle()
        
    elseif CurrentState == State.TURNING_IN then
        TurnInCollectables()
        -- After turn-in, check if we should continue or switch class
        local currentClass = GetClassById(GetCurrentClassId())
        local level = GetCurrentLevel()
        
        if level >= TargetLevel then
            -- Move to next class
            CurrentClassIndex = CurrentClassIndex + 1
            if CurrentClassIndex > #ClassesToLevel then
                CurrentClassIndex = 1
            end
        end
        
        CurrentState = State.IDLE
        
    elseif CurrentState == State.REPAIRING then
        DoRepair()
        CurrentState = State.IDLE
        
    elseif CurrentState == State.COMPLETE then
        Echo("Leveling complete!")
        return false
        
    elseif CurrentState == State.ERROR then
        Echo("Error occurred: " .. LastError)
        return false
    end
    
    return true
end

function MainLoop()
    Echo("Starting Universal Leveler...")
    
    if not Initialize() then
        Echo("Initialization failed!")
        return
    end
    
    -- Use food if enabled
    if UseFood and FoodName ~= "" then
        yield("/item " .. FoodName)
        Wait(2)
    end
    
    -- Main processing loop
    while ProcessState() do
        -- Periodically save progress (every 60s or on state change)
        if os.clock() % 60 < 0.5 then
            SaveProgress()
        end
        
        Wait(0.5)
        
        -- Safety check
        if not Player.Available then
            Wait(5)
        end
    end
    
    Echo("Universal Leveler stopped.")
end

--#endregion Main Loop

-- Start the script
MainLoop()
