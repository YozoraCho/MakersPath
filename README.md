# Maker’s Path

**A profession-driven crafting companion for World of Warcraft: Classic Era, The Burning Crusade Anniversary, and WoW Forever.**  
Track, compare, and plan your craftable gear upgrades. Maker’s Path helps you master your professions with tailored upgrade suggestions and a built-in profession book.

---

## Overview

**Maker’s Path** was designed with the *Crafted-Locked Challenge* in mind, but it’s equally useful for anyone who enjoys self-sufficient play.  
It scans your learned professions, indexes all craftable gear, and builds a personalized list of items you can make yourself.  
No dungeon drops, no world loot clutter — just pure craftsmanship.

---

## Supported Versions

| Game | Interface |
|----------|-------------|
| Classic Era | 11509 |
| The Burning Crusade Anniversary | 20506 |
| WoW Forever | 16001 |

> **WoW Forever:** recipes currently come from the Classic list. Forever’s new recipes will be added as data for them becomes available.

---

## Features

### Core Functionality
- **Craftable-only gear filtering** — shows only what your professions can produce.  
- **Smart upgrade scoring** — compares crafted gear to what you’re currently wearing, using stat weights tuned per class and spec.  
- **Gear-aware suggestions** — respects your armor type, known weapon skills, and the ammo your ranged weapon uses.  
- **Paired slots done right** — rings and trinkets are compared against the weaker of your two, and a 2H weapon is weighed against main hand + off hand together.  
- **Alternatives** — see other craftable options for each slot.  
- **Automatic profession scanning** — tracks your ranks across all characters.  
- **Profession Book** — view all characters, levels, classes, and professions at a glance.  
- **Optional minimap button** — quick access to both panels.   

### Stat Weights & Options
- **Stat Weights editor** — adjust how much each stat counts toward upgrade scoring.  
- **Presets** — save, load, and delete your own weight setups.  
- **Import / Export** — share a setup as a single string.  
- **Options window** — Prefer Native Armor, Ignore Filters, Trainer Only, and Only Score Weapon Stats.  

### Dynamic Updates
- Suggestions are saved per character and show instantly, even after a `/reload`.  
- They’re only recalculated when something that affects them changes:
  - You level up or change gear  
  - Your profession ranks change, or you learn a new weapon type  
  - You learn new recipes or open a tradeskill window with new craftables  
  - You change a setting or your stat weights  

---

## Commands

| Command | Description |
|----------|-------------|
| `/mp` or `/makerspath` | Open or close the main Maker’s Path panel |
| `/mpbook` | Open the Profession Book |
| `/mpoptions` or `/mpsettings` | Open the Options window |
| `/mpweights` | Open the Stat Weights editor |
| `/mpcap <levels>` or `/mpcap max` | Set how many future levels to preview upgrades |
| `/mptrainer [on\|off]` | Only suggest trainer-taught recipes |
| `/mpignorefilters [on\|off]` | Skip the class, weapon, and ammo restriction checks |
| `/mpreset` | Reset the panel position |
| `/mpscale <value>` | Set custom UI scale (or use Ctrl + ScrollWheel) |
| `/mpbookscale <value>` | Set the Profession Book scale (0.70–1.40) |

### Troubleshooting

| Command | Description |
|----------|-------------|
| `/mpskills` | List your skill lines (professions, weapon skills) as the addon sees them |
| `/mpprofmap` | Show the professions and ranks used for suggestions |
| `/mpcount` | Show how many craftables are indexed per slot |
| `/mptiming` | Print how long each suggestion rebuild takes |
| `/mpdebug [on\|off]` | Toggle detailed debug output |

---

## Panels

### Maker’s Path Panel
Displays your craftable upgrades, sorted by slot.  
Each entry shows:
- Best craftable item you can make for that slot
- Required profession and rank  
- Required player level  
- Upgrade score difference  
- Other options for the slot, when there are any

### Profession Book
A secondary window listing all characters on your account.  
- Shift + Right-Click any entry to remove it  
- Color-coded by class   

### Options
General settings and the Stat Weights editor, in two tabs.

---

## Credits

**Author:** [YozoraCho](https://github.com/YozoraCho)  
**Inspiration:** The Crafted-Only community. Players who forge their own path.  

Crafted with love for those who build rather than buy, and who find joy in progress measured by hammer strikes and thread counts.

---

## License

**All Rights Reserved**  
© 2025–2026 YozoraCho.  
This repository is provided for transparency and version tracking only.  
You may not redistribute, modify, or reuse any part of this project without explicit permission from the author.  
See [`LICENSE.txt`](./LICENSE.txt) for details.

---

## Links

- 🔗 [CurseForge Addon Page](https://www.curseforge.com/wow/addons/makers-path)
- 💡 [Issue Tracker](../../issues)
- 📦 [Releases](../../releases)

---

> *“The Maker’s Path is not just a road you walk . It’s the craft you leave behind.”*
