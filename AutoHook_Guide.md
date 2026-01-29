# 🎣 AutoHook Configuration Guide

To maximize your leveling and scrip farming efficiency with **AutoHook**, please configure the plugin as follows.

## 1. Global Settings (General Tab)
- **Enable AutoHook**: ✅ Checked
- **Auto Switch Bait**: ❌ Unchecked (The script handles bait switching, or use GatherBuddy)
- **Use Cordials**: ✅ Checked
  - Priority: `Hi-Cordial` > `Cordial` > `Watered Cordial`
  - Threshold: `HP < 90%` (prevents waste)
- **Use Thaliak's Favor**: ✅ Checked
  - Threshold: `5 Stacks` (restore GP)

## 2. Default Hooking (Default Tab)
This applies to all fishing unless a specific bait override is set.

### 🪝 Standard Hooking
- **Hook**: `Hook` (or `Double Hook` if you have GP and want to burn it)
- **Check**: `Hook Weak (!)`, `Hook Strong (!!)`, `Hook Legendary (!!!)`

### ⏱️ Patience / Patience II (Critical!)
When Patience is active, you **MUST** use the correct hookset to catch fish.
- **Weak Tug (!)**: `Precision Hookset`
- **Strong Tug (!!)**: `Powerful Hookset`
- **Legendary Tug (!!!)**: `Powerful Hookset`

## 3. Ocean Fishing Leveling Preset
For Ocean Fishing, you want to catch **everything** to build stacks and trigger spectral currents.

### 🦐 Baits to Configure
1. **Ragworm** (Green)
   - *Target*: Spectrals & High Point Fish
   - *Hook*: Standard presets above work fine.
2. **Krill** (Red)
   - *Target*: Large Fish
   - *Hook*: Standard presets work.
3. **Plump Worm** (Blue)
   - *Target*: Large Fish
   - *Hook*: Standard presets work.

### 🌊 Spectral Current Strategy
When a Spectral Current occurs (Rainbow water), catch speed is key!
- **Enable "Double Hook"** on:
  - `!!!` Tugs (Legendary) - Usually high value.
  - `!!` Tugs (Strong) - If you know it's a high-value fish.
- **Enable "Prize Catch"** or **"Identical Cast"** if you are targeting specific scrip fish (Level 90+).

## 4. General Leveling (1-100)
For general leveling outside Ocean Fishing:
- **Enable "Auto Cast Line"**: ✅ Checked
- **Enable "Auto Mooch"**: ✅ Checked (Free large fish!)
- **Enable "Patience II"**: ✅ Checked (Significantly boosts HQ/Large catch rate = More XP)

---
*Note: The Universal Leveler script will automatically detect if AutoHook is installed and turn it on using `/autohook on`. You just need to maximize the settings in the plugin window!*
