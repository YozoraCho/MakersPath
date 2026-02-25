local ADDON, ns = ...
ns.Systems = ns.Systems or {}
ns.Systems.GearFinder = ns.Systems.GearFinder or {}
local S = ns.Systems.GearFinder

S.SLOT_ORDER = {
  "HEAD","NECK","SHOULDER","BACK","CHEST","WRIST","HANDS","WAIST",
  "LEGS","FEET","FINGER1","FINGER2","TRINKET1","TRINKET2","MAINHAND","OFFHAND",
}

S.SLOT_TO_INVSLOT = {
  HEAD = 1, NECK = 2, SHOULDER = 3, BACK = 15, CHEST = 5, WRIST = 9,
  HANDS = 10, WAIST = 6, LEGS = 7, FEET = 8,
  FINGER1 = 11, FINGER2 = 12, TRINKET1 = 13, TRINKET2 = 14,
  MAINHAND = 16, OFFHAND = 17,
}