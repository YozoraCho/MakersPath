local L = LibStub("AceLocale-3.0"):NewLocale("MakersPath", "esES")
if not L then return end

-- Panel / Frame
L["ADDON_NAME"]             = "Maker's Path"
L["LEFTCLICK_OPEN"]         = "Clic izquierdo: Abrir panel principal"
L["RIGHTCLICK_BOOK"]        = "Clic derecho: Abrir libro de profesiones"
L["INDEXED_CRAFTABLES_FMT"] = "Fabricables indexados: %d"
L["EMPTY_HINT"]             = "Consejo: Abre una ventana de profesión para indexar y luego pulsa Actualizar."
L["BTN_REFRESH"]            = "Actualizar"
L["BTN_REFRESHING"]         = "Actualizando..."
L["BTN_PROF_BOOK"]          = "Libro"
L["MAIN_SCALE_FMT"]         = "Escala de Maker's Path: %.2f"
L["ITEM_ID_FMT"]            = "Objeto %d"
L["NO_CRAFT_UPGRADE"]       = "(sin mejora fabricable)"
L["RESCANNED_PROFS"]        = "Profesiones actualizadas."
L["ALT_SUGGESTIONS_HEADER"] = "Otras sugerencias"
L["ALT_USE_BEST"]           = "Usar mejor sugerencia"
L["PROFILE_LABEL"]          = "Perfil:"
L["PROFILE_ACTIVE"]         = "Personaje activo"
L["PROFILE_ALT"]            = "Otros personajes:"


-- Book
L["PROFBOOK_TITLE"]      = "Maker's Path — Libro de Profesiones"
L["LEVEL_PREFIX"]        = "Nv"
L["NO_PROFS"]            = "(sin profesiones registradas)"
L["ROW_HINT_FORGET"]     = "Mayús + Clic derecho para eliminar este personaje"
L["ROW_HINT_FORGET_ERR"] = "Mantén |cffffd200MAYÚS|r y haz clic derecho para eliminar."
L["REMOVED_FROM_ROSTER"] = "%s eliminado de la lista."
L["BTN_RESCAN"]          = "Actualizar"
L["BTN_CLOSE"]           = "Cerrar"
L["BOOK_SCALE_CHANGED"]  = "Escala del Libro: %.2f"
L["BOOK_SCALE_USAGE"]    = "|cff00ccff[Maker's Path]|r uso: |cffffcc00/mpbookscale <%.2f–%.2f>|r  (actual: %.2f)"
L["BOOK_SCALE_SET"]      = "Escala del Libro ajustada a |cffffcc00%.2f|r"

-- CharacterPanel button tooltip
L["OPEN_MAKERS_PATH"] = "Abrir Maker's Path"

-- Commands
L["CMD_MAX"]                = "max"
L["USAGE_MPCAP"]            = "Uso: /mpcap <niveles> o /mpcap max"
L["FUTUREWINDOW_SET"]       = "FutureWindow ajustado a %d"
L["IGNORE_FILTERS_STATUS"]  = "IGNORE_FILTERS = %s"
L["DEBUG_GF_STATUS"]        = "DEBUG_GF = %s"

-- Options
L["OPTIONS_DESC"]       = "Personalizar apariencia y comportamiento de Maker's Path."
L["OPT_HIDE_MINIMAP"]   = "Ocultar icono del minimapa"

-- Minimap
L["LDB_TT_TITLE"]   = "|cff00ccffMaker's Path|r"
L["LDB_TT_LEFT"]    = "Clic izquierdo: Abrir panel principal"
L["LDB_TT_RIGHT"]   = "Clic derecho: Abrir libro de profesiones"

-- Slot Fallback
L["HEAD"]       = "Cabeza"
L["NECK"]       = "Cuello"
L["SHOULDER"]   = "Hombros"
L["BACK"]       = "Espalda"
L["CHEST"]      = "Pecho"
L["WRIST"]      = "Muñeca"
L["HANDS"]      = "Manos"
L["WAIST"]      = "Cintura"
L["LEGS"]       = "Piernas"
L["FEET"]       = "Pies"
L["RING"]       = "Anillo"
L["TRINKET"]    = "Abalorio"
L["MAIN_HAND"]  = "Mano principal"
L["OFF_HAND"]   = "Mano izquierda"
L["RANGED"]     = "A distancia"
L["AMMO"]       = "Munición"

-- Professions
L["BS"]     = "HS"  -- Herrero
L["LW"]     = "CD"  -- Curtidor / Leatherworking
L["Tailor"] = "Sastre"
L["Eng"]    = "Ing"
L["Ench"]   = "Enc"
L["Alc"]    = "Alq"
L["Herb"]   = "Her"
L["Mine"]   = "Min"
L["Skin"]   = "Des"
L["Cook"]   = "Coc"
L["Fish"]   = "Pes"
L["FA"]     = "AC"

-- Specs
L["SPEC_AUTO_KEYWORD"]      = "AUTO"
L["SPEC_CURRENT_STATUS"]    = "Clase = %s"
L["SPEC_AUTO_NO_OVERRIDE"]  = "Auto (sin cambio)"
L["DRUID_BALANCE"]          = "Equilibrio"
L["DRUID_FERAL_DPS"]        = "Feral (DPS)"
L["DRUID_FERAL_TANK"]       = "Feral (Tank)"
L["DRUID_RESTORATION"]      = "Restauración"
L["SHAMAN_ELEMENTAL"]       = "Elemental"
L["SHAMAN_ENHANCEMENT"]     = "Mejora"
L["SHAMAN_RESTORATION"]     = "Restauración"
L["WARRIOR_ARMS"]           = "Armas"
L["WARRIOR_FURY"]           = "Furia"
L["WARRIOR_PROTECTION"]     = "Protección (60)"
L["WARRIOR_FURYPROT"]       = "FurProt (60)"
L["PALADIN_HOLY"]           = "Sagrado"
L["PALADIN_PROTECTION"]     = "Protección"
L["PALADIN_RETRIBUTION"]    = "Reprensión"
L["PRIEST_DISCIPLINE"]      = "Disciplina"
L["PRIEST_HOLY"]            = "Sagrado"
L["PRIEST_SHADOW"]          = "Sombra"
L["MAGE_ARCANE"]            = "Arcano"
L["MAGE_FIRE"]              = "Fuego"
L["MAGE_FROST"]             = "Escarcha"
L["MAGE_AOE"]               = "AoE"
L["WARLOCK_AFFLICTION"]     = "Aflicción"
L["WARLOCK_DEMONOLOGY"]     = "Demonología"
L["WARLOCK_DESTRUCTION"]    = "Destrucción"
L["HUNTER_BEAST_MASTERY"]   = "Dominio de Bestias"
L["HUNTER_MARKSMANSHIP"]    = "Puntería"
L["HUNTER_SURVIVAL"]        = "Supervivencia"
L["ROGUE_ASSASSINATION"]    = "Asesinato"
L["ROGUE_COMBAT"]           = "Combate"
L["ROGUE_SUBTLETY"]         = "Sutileza"

-- Meta Formatting
L["META_PREFIX_FMT"]   = "[%s %d"
L["META_DELTA_FMT"]    = " (+%d)"
L["META_CLOSE"]        = "]"
L["META_REQ_LVL_FMT"]  = " (requier nv %d)"
L["SIGNED_FLOAT_FMT"]  = "%+.2f"