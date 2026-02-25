local ADDON, ns = ...
ns.Systems = ns.Systems or {}
ns.Systems.GearFinder = ns.Systems.GearFinder or {}
local S = ns.Systems.GearFinder

S.SLOT_ORDER = {
  "HEAD","NECK","SHOULDER","BACK","CHEST","WRIST","HANDS","WAIST",
  "LEGS","FEET","FINGER1","FINGER2","TRINKET1","TRINKET2","MAINHAND","OFFHAND",
}

S.SLOT_TO_V1 = {
  HEAD="HeadSlot",
  NECK="NeckSlot",
  SHOULDER="ShoulderSlot",
  BACK="BackSlot",
  CHEST="ChestSlot",
  WRIST="WristSlot",
  HANDS="HandsSlot",
  WAIST="WaistSlot",
  LEGS="LegsSlot",
  FEET="FeetSlot",
  FINGER1="Finger0Slot",
  FINGER2="Finger1Slot",
  TRINKET1="Trinket0Slot",
  TRINKET2="Trinket1Slot",
  MAINHAND="MainHandSlot",
  OFFHAND="SecondaryHandSlot",
}