# Maker’s Path

**A profession-driven crafting companion for World of Warcraft: Classic Era, The Burning Crusade Anniversary, and WoW Forever.**  
Plan every crafted upgrade for every slot, see exactly what stands between you and each one, and follow the Path from where you are to where your crafts can take you.

---

## Overview

**Maker’s Path** was designed with the *Crafted-Locked Challenge* in mind, but it’s equally useful for anyone who enjoys self-sufficient play.  
It reads your professions, recipes, gear, level and bags, compares every craftable item against what you’re wearing, and lays out your upgrades as a roadmap.  
No dungeon drops, no world loot clutter — just pure craftsmanship.

**2.0** is a full overhaul: a new interface built around **The Path**, recipe and material tracking for every character on your account, and a rebuilt Profession Book and Options window.

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

### The Path
- **A progression roadmap** of your crafted upgrades, rebuilt whenever your gear, level, professions or settings change.
- **Trails** for your level and each profession you’ve learned. **Milestones** (coins) mark the skill or level an upgrade needs; a bar joining two coins means both are needed.
- **Craft now** — upgrades you can make right now, materials included.
- **Gather materials** — you have the skill and the recipe, but not enough materials in your bags.
- **Every profession counts** — upgrades from professions you haven’t learned stay on the Path, along with who on your account can make them.
- **No forced order** — milestones are listed by the level you can wear them, and you can work toward any of them first.

### Four Checks on Every Upgrade
Each upgrade shows four checks, always in the same order:

| Check | Meaning |
|----------|-------------|
| Skill | You have the profession skill it needs |
| Recipe | You know the recipe |
| Materials | The materials are in your bags |
| Equip | You’re high enough level to wear it |

A check is **outlined** when met, **amber** when not met, and **dashed** when it isn’t known yet (for example, before you’ve opened that profession window).

### Equipment Rails
- Your gear laid out like the character pane, with the best crafted upgrade for each slot.
- **Slot badges:** ◆ ready, ◇ can be made, ◇ (amber) needs training, 🔒 needs level. Hover the legend in the footer for details.
- Slots without an upgrade show what you’re wearing.

### Inspection View
Click any upgrade to see:
- What you’re wearing vs what you’d craft, with item levels and stat changes
- What’s needed **to craft** (skill, recipe and where it comes from) and **to equip** (level), kept separate
- Materials in your bags
- Crafters on your account who could make it
- Other options for the slot

### Recipes & Materials
- **Recipe tracking** — opening a profession window records which recipes that character knows.
- **Bag counts** — materials are counted against each recipe, and the materials you need for everything you’ve learned are totalled at the bottom of the Path.
- Works on Classic Era, TBC Anniversary and Forever.

### Profession Book
- Every character on your account, with level and class.
- Primary professions with recipe counts; secondary professions on their own line.
- Collapse or expand each character; Shift + Right-Click to remove one.

### Options & Stat Weights
- **General:** Prefer my class’s armor type, Trainer recipes only, Ignore class and weapon checks, Score weapons on stats only, Look ahead (levels), Hide minimap button, Scale.
- **Stat Weights editor** — adjust how much each stat counts, save presets, and import or export a setup as a single string.

### Smart Suggestions
- **Upgrade scoring** compares crafted gear to what you’re wearing, using stat weights tuned per class and spec.
- **Gear-aware** — respects your armor type, known weapon skills, and the ammo your ranged weapon uses.
- **Paired slots done right** — rings and trinkets are compared against the weaker of your two, and a 2H weapon is weighed against main hand + off hand together.
- **Saved per character** and shown instantly, even after a `/reload`. Only recalculated when something that affects them changes.

### Languages
English, German, Spanish and French.

---

## Commands

| Command | Description |
|----------|-------------|
| `/mp` or `/makerspath` | Open or close the main Maker’s Path window |
| `/mpbook` | Open the Profession Book |
| `/mpoptions` or `/mpsettings` | Open the Options window |
| `/mpweights` | Open the Stat Weights editor |
| `/mpcap <levels>` or `/mpcap max` | Set how many future levels to look ahead (also in Options) |
| `/mptrainer [on\|off]` | Only suggest trainer-taught recipes |
| `/mpignorefilters [on\|off]` | Skip the class, weapon, and ammo restriction checks |
| `/mpreset` | Reset the window position and size |
| `/mpscale <value>` | Set the window scale (or use Ctrl + ScrollWheel) |
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

## Tips

- **Open each profession window once per character.** That’s how Maker’s Path learns which recipes the character knows; until then the recipe check shows as not known yet.
- **After updating, restart the game fully.** Some textures changed in 2.0, and `/reload` won’t pick them up.
- **Hover anything** — items, trails, milestones, group titles, the **?** next to The Path, and the footer legend all explain themselves.
- **Characters menu** in the header lets you view the Path for your other characters.

### Known Limitations
- **Bags** can only be read on the character you’re playing, so materials for other characters show as not known.

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
