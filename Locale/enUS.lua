local ADDON, ns = ...
local L = LibStub("AceLocale-3.0"):NewLocale(ADDON, "enUS", true)
if not L then return end

-- Core
L["ADDON_NAME"] = "Makers Path"
L["BOOT_LOADED"] = "|cff66ccff[MakersPath V2]|r loaded (%s)"
L["CMD_HELP_TITLE"] = "Maker's Path commands:"
L["CMD_TOGGLE"] = "/mp - toggle UI"
L["CMD_SHOW"] = "/mp show - show UI"
L["CMD_HIDE"] = "/mp hide - hide UI"

-- Minimap / Tooltip
L["MINIMAP_LABEL"] = "Makers Path"
L["MINIMAP_RIGHT_CLICK_TODO"] = "|cff66ccff[MP]|r right click (todo: menu)"
L["MINIMAP_TOOLTIP_TITLE"] = "Makers Path (V2)"
L["MINIMAP_TOOLTIP_LEFT"]  = "Left click: open"
L["MINIMAP_TOOLTIP_RIGHT"] = "Right click: menu (todo)"

-- UI
L["UI_TITLE"] = "Maker's Path (V2)"

L["NO_UPGRADE_FOUND"] = "No upgrade found"
L["UNKNOWN_ITEM"] = "Unknown item"
L["PROF_LEATHERWORKING"] = "Leatherworking"
L["PROF_TAILORING"] = "Tailoring"

-- Gear slots
L["SLOT_HEAD"] = "Head"
L["SLOT_NECK"] = "Neck"
L["SLOT_SHOULDER"] = "Shoulder"
L["SLOT_BACK"] = "Back"
L["SLOT_CHEST"] = "Chest"
L["SLOT_WRIST"] = "Wrist"
L["SLOT_HANDS"] = "Hands"
L["SLOT_WAIST"] = "Waist"
L["SLOT_LEGS"] = "Legs"
L["SLOT_FEET"] = "Feet"
L["SLOT_FINGER1"] = "Finger 1"
L["SLOT_FINGER2"] = "Finger 2"
L["SLOT_TRINKET1"] = "Trinket 1"
L["SLOT_TRINKET2"] = "Trinket 2"
L["SLOT_MAINHAND"] = "Main Hand"
L["SLOT_OFFHAND"] = "Off Hand"