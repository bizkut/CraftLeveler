# Universal 1-100 Crafter & Gatherer Leveler

One-button SND script to level all crafters and gatherers from 1 to 100 in FFXIV.

## Required Plugins

Install these via XIVLauncher / Dalamud:

| Plugin | Repository | Purpose |
|--------|------------|---------|
| **SND (Something Need Doing)** | `https://puni.sh/api/repository/croizat` | Script engine |
| **Artisan** | `https://puni.sh/api/repository/croizat` | Dynamic crafting rotations |
| **vnavmesh** | `https://puni.sh/api/repository/croizat` | Pathfinding |
| **Lifestream** | `https://puni.sh/api/repository/croizat` | Teleportation |
| **GatherBuddyReborn** | `https://puni.sh/api/repository/croizat` | Gathering automation |

## Installation

1. Open XIVLauncher and ensure Dalamud is enabled
2. Add the Puni.sh repository: `https://puni.sh/api/repository/croizat`
3. Install the required plugins listed above
4. Copy `UniversalLeveler.lua` to your SND scripts folder
5. In-game, type `/pcraft` to open SND
6. Import or paste the script

## Configuration

When you load the script in SND, you'll see these options:

| Option | Description |
|--------|-------------|
| **Mode** | All Crafters, All Gatherers, Single Class, or Everything |
| **SingleClass** | If Single mode, specify class (CRP, BSM, ARM, GSM, LTW, WVR, ALC, CUL, BTN, MIN, FSH) |
| **TargetLevel** | Level to stop at (default: 100) |
| **HubCity** | Base of operations (default: Limsa) |
| **AutoRepair** | Automatically repair gear (default: true) |
| **UseFood** | Use XP food buff (default: false) |
| **UseManual** | Use GC XP Manuals for +150% bonus (default: true) |
| **ManualSource** | Where to get manuals: Grand Company, Marketboard, or Inventory Only |
| **GrandCompany** | Your GC: Maelstrom, Twin Adder, or Immortal Flames |
| **AutoUpgradeGear** | Opens scrip shop for manual purchase when stats low (default: true) |
| **AutoDesynthGear** | Desynth/GC turn-in excess gear when ≤5 slots (default: true) |
| **UseLeves** | Use leve allowances for bonus XP (levels 10-80) |
| **DoGCDailies** | Complete GC supply/provisioning daily turn-ins |
| **DoStudium** | Complete Studium weekly deliveries (Endwalker, 80+) |
| **UseFirmament** | Use Ishgard Restoration for leveling 20-80 |
| **UseOceanFishing** | Use Ocean Fishing for Fisher (every 2 hours) |
| **AutoRetrieverMaterials** | Check retainers for materials (requires AutoRetainer) |

### Advanced Features

| Feature | Description |
|---------|-------------|
| **Fisher Support** | Ocean Fishing (Level 1-100) > Leves > Native Loop |
| **Scrip Cap Warning** | Auto-spends scrips on Materia >3500 cap |
| **Spiritbond Extraction** | Auto-extracts materia at 100% |
| **Progress Persistence** | Saves progress to `progress.json` for resume |
| **Retainer Integration** | Retrieves materials via AutoRetainer |
| **Leve Usage** | Accepts/crafts/turns-in levequests automatically |
| **GC Dailies** | Completes supply/provisioning missions |
| **Studium Deliveries** | Weekly Endwalker turn-ins (level 80+) |
| **Ishgard Restoration** | Diadem gathering + Firmament crafting (20-80) |

### Automatic Gear Management

The script handles gear upgrades and disposal:

**Gear Upgrade Flow:**
1. Detects when craftsmanship/gathering is too low for current level
2. **Navigates to Scrip Exchange and opens the shop**
3. **Pauses for 30s** for you to buy the recommended set manually
4. Runs `/stylist all` to update all gearsets with your new items

**Gear Disposal (≤5 inventory slots):**
1. Opening desynthesis window (game protects gearset items)
2. Desynth excess gear for skill-ups and materials
3. GC Expert Delivery for remaining items → seals

| Level | Scrip Gear Set | Scrip Type |
|-------|---------------|------------|
| 50-60 | Forager's | White |
| 60-70 | Augmented Fieldkeep's | White |
| 70-80 | Handsaint's | White |
| 80-90 | Perfectionist's | White |
| 90-100 | Indagator's | Orange |

### XP Manual Buffs

The script uses **different manuals** for crafting vs gathering:

| Class Type | Manual | Effect | GC Cost |
|------------|--------|--------|---------|
| **Crafters** | Company-issue Engineering Manual | +150% XP | 1,400 seals |
| **Gatherers** | Company-issue Survival Manual | +150% XP | 1,400 seals |

The script will:
1. Check if you have the buff active
2. If not, check inventory for manuals
3. If none, travel to your GC and purchase 5 manuals
4. Use a manual to apply the buff
5. Begin crafting/gathering

### Automated Material Sourcing

When crafting collectables, the script automatically handles missing materials:

```
Detect Missing Materials → Check Gatherer Level → Level Up if Needed → Gather → Return to Crafter
```

**How it works:**
1. Before crafting, checks if you have required base materials
2. If missing, identifies which gatherer is needed (MIN for ores, BTN for logs/plants)
3. **Checks if gatherer level is high enough** to gather the material
4. If gatherer is too low, **switches to leveling that gatherer first**
5. Uses GatherBuddy collectables to level up quickly
6. Once gatherer reaches required level, **returns to material gathering**
7. Gathers the materials, then switches back to crafter

### Gatherer Level Queue

The script remembers what crafter was waiting:
```
CRP Level 95 → Needs Claro Walnut → BTN too low (Lv30)
    ↓ Save: "Return to CRP after BTN reaches Lv90"
    ↓ Level BTN via collectables...
    ↓ BTN hits 90 → "Return to CRP"
    ↓ Gather materials → Continue CRP crafting
```

> **Note:** Requires **GatherBuddyReborn** plugin for automatic gathering and leveling

## Usage

1. Make sure you have gearsets saved for each class you want to level
2. Open SND with `/pcraft`
3. Select the script and configure options
4. Click **Run**
5. The script will automatically:
   - Switch between classes
   - Craft collectables appropriate for your level
   - Turn in for scrips/XP
   - Repair gear when needed
   - Continue until target level reached

## Leveling Strategy

The script uses the most efficient method for each level range:

| Level | Method |
|-------|--------|
| 1-50 | Quick Synthesis + Artisan automation |
| 50-60 | Collectables (Rarefied items) |
| 60-70 | Collectables + XP bonus items |
| 70-80 | Collectables |
| 80-90 | Collectables |
| 90-100 | Orange Scrip Collectables (most efficient) |

> **Note:** Firmament/Diadem is NOT required. The script uses collectables which are universally available.

## Troubleshooting

**Script won't start:**
- Ensure all required plugins are installed and loaded
- Check that you have gearsets for target classes

**Navigation issues:**
- Make sure vnavmesh is installed and navmesh data is downloaded
- Try `/vnav rebuild` if pathing fails

**Crafting not working:**
- Verify Artisan is installed
- Check that you have materials for recipes

## Files

- `UniversalLeveler.lua` - Main script

## Credits

Built for the SND (Something Need Doing) plugin ecosystem.
