local L = LibStub("AceLocale-3.0"):NewLocale("MakersPath", "enUS", true)
if not L then return end

-- Panel / Frame
L["ADDON_NAME"]      = "Maker's Path"
L["LEFTCLICK_OPEN"]  = "Left-click: Open Main Panel"
L["RIGHTCLICK_BOOK"] = "Right-click: Open Profession Book"
L["INDEXED_CRAFTABLES_FMT"] = "Indexed craftables: %d"
L["EMPTY_HINT"]             = "Tip: Open a profession window to index craftables, then click Refresh."
L["BTN_REFRESH"]            = "Refresh"
L["BTN_REFRESHING"]         = "Refreshing..."
L["BTN_PROF_BOOK"]          = "Prof Book"
L["MAIN_SCALE_FMT"]         = "Maker's Path scale: %.2f"
L["ITEM_ID_FMT"]            = "Item %d"
L["NO_CRAFT_UPGRADE"]       = "(no craftable upgrade)"
L["RESCANNED_PROFS"]        = "Rescanned current professions."

-- Book
L["PROFBOOK_TITLE"]      = "Maker's Path — Profession Book"
L["LEVEL_PREFIX"]        = "Lv"
L["NO_PROFS"]            = "(no professions recorded)"
L["ROW_HINT_FORGET"]     = "Shift + Right-click to remove this character from the list"
L["ROW_HINT_FORGET_ERR"] = "Hold |cffffd200SHIFT|r and right-click to forget."
L["REMOVED_FROM_ROSTER"] = "removed %s from roster."
L["BTN_RESCAN"]          = "Rescan Current"
L["BTN_CLOSE"]           = "Close"
L["BOOK_SCALE_CHANGED"]  = "Maker's Path Book scale: %.2f"
L["BOOK_SCALE_USAGE"]    = "|cff00ccff[Maker's Path]|r usage: |cffffcc00/mpbookscale <%.2f–%.2f>|r  (current: %.2f)"
L["BOOK_SCALE_SET"]      = "|cff00ccff[Maker's Path]|r Book scale set to |cffffcc00%.2f|r"

-- CharacterPanel button tooltip
L["OPEN_MAKERS_PATH"] = "Open Maker's Path"

-- Commands
L["CMD_MAX"]         = "max"
L["USAGE_MPCAP"]     = "Usage: /mpcap <levels> or /mpcap max"
L["FUTUREWINDOW_SET"] = "FutureWindow set to %d"

--Options
L["OPTIONS_DESC"]       = "Customize Maker's Path appearance and behavior."
L["OPT_HIDE_MINIMAP"]   = "Hide minimap icon"

-- Minimap
L["LDB_TT_TITLE"]   = "|cff00ccffMaker's Path|r"
L["LDB_TT_LEFT"]    = "Left-click: Open Main Panel"
L["LDB_TT_RIGHT"]   = "Right-click: Open Profession Book"

-- Slot Fallback (Used only if _G.* is missing)
L["HEAD"]       = "Head"
L["NECK"]       = "Neck"
L["SHOULDER"]   = "Shoulder"
L["BACK"]       = "Back"
L["CHEST"]      = "Chest"
L["WRIST"]      = "Wrist"
L["HANDS"]      = "Hands"
L["WAIST"]      = "Waist"
L["LEGS"]       = "Legs"
L["FEET"]       = "Feet"
L["RING"]       = "Ring"
L["TRINKET"]    = "Trinket"
L["MAIN_HAND"]  = "Main Hand"
L["OFF_HAND"]   = "Off Hand"
L["RANGED"]     = "Ranged"
L["AMMO"]       = "Ammo"

-- Professions
L["BS"]     = "BS"
L["LW"]     = "LW"
L["Tailor"] = "Tailor"
L["Eng"]    = "Eng"
L["Ench"]   = "Ench"

-- Meta Formatting
L["META_PREFIX_FMT"]   = "[%s %d"
L["META_DELTA_FMT"]    = " (+%d)"
L["META_CLOSE"]        = "]"
L["META_REQ_LVL_FMT"]  = " (req lvl %d)"
L["SIGNED_FLOAT_FMT"]  = "%+.2f"