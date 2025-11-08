local L = LibStub("AceLocale-3.0"):NewLocale("MakersPath", "deDE")
if not L then return end

-- Panel / Frame
L["ADDON_NAME"]              = "Maker's Path"
L["LEFTCLICK_OPEN"]          = "Linksklick: Hauptfenster öffnen"
L["RIGHTCLICK_BOOK"]         = "Rechtsklick: Berufsbuch öffnen"
L["INDEXED_CRAFTABLES_FMT"]  = "Herstellbare Gegenstände: %d"
L["EMPTY_HINT"]              = "Tipp: Öffne ein Berufsfenster, um herstellbare Gegenstände zu erfassen, und klicke anschließend auf „Aktualisieren“."
L["BTN_REFRESH"]             = "Aktualisieren"
L["BTN_REFRESHING"]          = "Aktualisiere ..."
L["BTN_PROF_BOOK"]           = "Berufsbuch"
L["MAIN_SCALE_FMT"]          = "Maker's Path Skalierung: %.2f"
L["ITEM_ID_FMT"]             = "Gegenstand %d"
L["NO_CRAFT_UPGRADE"]        = "(kein herstellbares Upgrade)"
L["RESCANNED_PROFS"]         = "Aktuelle Berufe erneut gescannt."

-- Book
L["PROFBOOK_TITLE"]      = "Maker's Path — Berufsbuch"
L["LEVEL_PREFIX"]        = "Lv"
L["NO_PROFS"]            = "(keine Berufe aufgezeichnet)"
L["ROW_HINT_FORGET"]     = "Umschalt + Rechtsklick, um diesen Charakter aus der Liste zu entfernen"
L["ROW_HINT_FORGET_ERR"] = "Halte |cffffd200Umschalt|r gedrückt und klicke mit Rechts, um zu entfernen."
L["REMOVED_FROM_ROSTER"] = "entfernte %s aus der Liste."
L["BTN_RESCAN"]          = "Erneut scannen"
L["BTN_CLOSE"]           = "Schließen"
L["BOOK_SCALE_CHANGED"]  = "Maker's Path Buch-Skalierung: %.2f"
L["BOOK_SCALE_USAGE"]    = "|cff00ccff[Maker's Path]|r Verwendung: |cffffcc00/mpbookscale <%.2f–%.2f>|r  (aktuell: %.2f)"
L["BOOK_SCALE_SET"]      = "|cff00ccff[Maker's Path]|r Buch-Skalierung gesetzt auf |cffffcc00%.2f|r"

-- CharacterPanel button tooltip
L["OPEN_MAKERS_PATH"] = "Maker's Path öffnen"

-- Commands
L["CMD_MAX"]         = "max"
L["USAGE_MPCAP"]      = "Verwendung: /mpcap <Stufen> oder /mpcap max"
L["FUTUREWINDOW_SET"] = "FutureWindow auf %d gesetzt"

-- Options
L["OPTIONS_DESC"]       = "Passe das Aussehen und Verhalten von Maker's Path an."
L["OPT_HIDE_MINIMAP"]   = "Minikartensymbol ausblenden"

-- Minimap
L["LDB_TT_TITLE"]   = "|cff00ccffMaker's Path|r"
L["LDB_TT_LEFT"]    = "Linksklick: Hauptfenster öffnen"
L["LDB_TT_RIGHT"]   = "Rechtsklick: Berufsbuch öffnen"

-- Slot Fallback (Used only if _G.* is missing)
L["HEAD"]       = "Kopf"
L["NECK"]       = "Hals"
L["SHOULDER"]   = "Schulter"
L["BACK"]       = "Rücken"
L["CHEST"]      = "Brust"
L["WRIST"]      = "Handgelenke"
L["HANDS"]      = "Hände"
L["WAIST"]      = "Taille"
L["LEGS"]       = "Beine"
L["FEET"]       = "Füße"
L["RING"]       = "Ring"
L["TRINKET"]    = "Schmuckstück"
L["MAIN_HAND"]  = "Haupthand"
L["OFF_HAND"]   = "Nebenhand"
L["RANGED"]     = "Distanz"
L["AMMO"]       = "Munition"

-- Professions
L["BS"]     = "Schm"        -- Schmiedekunst (common short)
L["LW"]     = "LW"          -- Lederverarbeitung
L["Tailor"] = "Schneider"
L["Eng"]    = "Ing"         -- Ingenieurskunst
L["Ench"]   = "Verz"        -- Verzauberkunst

-- Meta Formatting
L["META_PREFIX_FMT"]   = "[%s %d"
L["META_DELTA_FMT"]    = " (+%d)"
L["META_CLOSE"]        = "]"
L["META_REQ_LVL_FMT"]  = " (erf. lvl %d)"
L["SIGNED_FLOAT_FMT"]  = "%+.2f"