local ADDON, MakersPath = ...
MakersPath = MakersPath or {}
MakersPath.Const = MakersPath.Const or {}

local C = MakersPath.Const

C.CLASS_ARMOR = LE_ITEM_CLASS_ARMOR or 4
C.CLASS_WEAPON = LE_ITEM_CLASS_WEAPON or 2

C.ARMOR_SUB = {
  CLOTH   = LE_ITEM_ARMOR_CLOTH   or 1,
  LEATHER = LE_ITEM_ARMOR_LEATHER or 2,
  MAIL    = LE_ITEM_ARMOR_MAIL    or 3,
  PLATE   = LE_ITEM_ARMOR_PLATE   or 4,
}
C.WEAPON_SUB = {
    ONE_HAND_AXES   = 0,
    TWO_HAND_AXES   = 1,
    BOWS            = 2,
    GUNS            = 3,
    ONE_HAND_MACES  = 4,
    TWO_HAND_MACES  = 5,
    POLEARMS        = 6,
    ONE_HAND_SWORDS = 7,
    TWO_HAND_SWORDS = 8,
    STAVES          = 10,
    FIST_WEAPONS    = 13,
    DAGGERS         = 15,
    THROWN          = 16,
    SPEARS          = 17,
    CROSSBOWS       = 18,
    WANDS           = 19,
}
C.SUBCLASS_TO_LINE ={
    [C.WEAPON_SUB.ONE_HAND_AXES]    = "One-Handed Axes",
    [C.WEAPON_SUB.TWO_HAND_AXES]    = "Two-Handed Axes",
    [C.WEAPON_SUB.BOWS]             = "Bows",
    [C.WEAPON_SUB.GUNS]             = "Guns",
    [C.WEAPON_SUB.ONE_HAND_MACES]   = "One-Handed Maces",
    [C.WEAPON_SUB.TWO_HAND_MACES]   = "Two-Handed Maces",
    [C.WEAPON_SUB.POLEARMS]         = "Polearms",
    [C.WEAPON_SUB.ONE_HAND_SWORDS]  = "One-Handed Swords",
    [C.WEAPON_SUB.TWO_HAND_SWORDS]  = "Two-Handed Swords",
    [C.WEAPON_SUB.STAVES]           = "Staves",
    [C.WEAPON_SUB.FIST_WEAPONS]     = "Fist Weapons",
    [C.WEAPON_SUB.DAGGERS]          = "Daggers",
    [C.WEAPON_SUB.THROWN]           = "Thrown",
    [C.WEAPON_SUB.CROSSBOWS]        = "Crossbows",
    [C.WEAPON_SUB.WANDS]            = "Wands",
}
C.SKILLLINE_TO_SPELL = {
  [164] = 2018,  -- Blacksmithing
  [165] = 2108,  -- Leatherworking
  [171] = 2259,  -- Alchemy
  [197] = 3908,  -- Tailoring
  [202] = 4036,  -- Engineering
  [333] = 7411,  -- Enchanting
  [186] = 2575,  -- Mining
  [182] = 2366,  -- Herbalism
  [393] = 8613,  -- Skinning
  [185] = 2550,  -- Cooking
  [356] = 7620,  -- Fishing
  [129] = 3273,  -- First Aid
}