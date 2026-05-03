-- Profession quest IDs/names: Wowhead retail (e.g. /quest=29506 for A Fizzy Fusion). Shopping/vendor coords may need patch updates.
-- uiMapID: Elwynn Forest=37, Stormwind City=84, Orgrimmar=85. Darkmoon floor ids come from live map data (408 + GetMapChildrenInfo(407)). Orphan overview=407. x,y are 0-100 map percentages on that uiMap.

local _, addon = ...

---@class ProfessionQuest
---@field questId number
---@field name string
---@field profession string
---@field skillLineId number
---@field poiId string
---@field requiredStacks { itemKey: string, count: number }[]

---@class ItemDef
---@field key string
---@field itemId number
---@field name string
---@field vendors { mapId: number, x: number, y: number, label: string, faction: string? }[]

local PROFESSION_SKILL_LINE = {
  alchemy = 171,
  blacksmithing = 164,
  leatherworking = 165,
  tailoring = 197,
  engineering = 202,
  herbalism = 182,
  mining = 186,
  skinning = 393,
  jewelcrafting = 755,
  enchanting = 333,
  inscription = 773,
  cooking = 185,
  fishing = 356,
  archaeology = 394,
}

-- Alchemy DMF quest uses both capital goods and island vendor; profession row uses alchemy key.
local ITEMS = {
  moonberry_juice = {
    key = "moonberry_juice",
    itemId = 1645,
    name = "Moonberry Juice",
    vendors = {
      --- Innkeeper Farley sells Moonberry Juice; coords Wowpedia npc 295 (Lion's Pride Inn, Goldshire).
      { mapId = 37, x = 43.8, y = 65.9, label = "Innkeeper Farley — Lion's Pride Inn (Goldshire)", faction = "Alliance" },
      { mapId = 85, x = 39.0, y = 48.2, label = "Valley of Strength inn & general goods", faction = "Horde" },
    },
  },
  fizzy_faire_drink = {
    key = "fizzy_faire_drink",
    itemId = 19299,
    name = "Fizzy Faire Drink",
    vendors = {
      { mapId = 408, x = 50.5, y = 69.8, label = "Sylannia (Darkmoon Island)", faction = "Any" },
    },
  },
  simple_flour = {
    key = "simple_flour",
    itemId = 30817,
    name = "Simple Flour",
    vendors = {
      --- Quest text: Elwynn/Mulgore vendors; Tharynn Bouden trade supplies — Wowpedia npc 66 [41.9, 67.1] on Elwynn map.
      { mapId = 37, x = 41.9, y = 67.1, label = "Tharynn Bouden — Trade Supplies (Goldshire)", faction = "Alliance" },
      { mapId = 85, x = 47.2, y = 46.6, label = "Cooking / trade goods (Orgrimmar)", faction = "Horde" },
    },
  },
  light_parchment = {
    key = "light_parchment",
    itemId = 39354,
    name = "Light Parchment",
    vendors = {
      { mapId = 37, x = 41.9, y = 67.1, label = "Tharynn Bouden — Trade Supplies (Goldshire)", faction = "Alliance" },
      { mapId = 85, x = 47.0, y = 47.2, label = "Trade goods (Orgrimmar)", faction = "Horde" },
    },
  },
  shiny_bauble = {
    key = "shiny_bauble",
    itemId = 6529,
    name = "Shiny Bauble",
    vendors = {
      { mapId = 37, x = 41.9, y = 67.1, label = "Tharynn Bouden — Trade Supplies (Goldshire)", faction = "Alliance" },
      { mapId = 85, x = 69.6, y = 41.0, label = "Fishing supplier (Orgrimmar)", faction = "Horde" },
    },
  },
  coarse_thread = {
    key = "coarse_thread",
    itemId = 2320,
    name = "Coarse Thread",
    vendors = {
      { mapId = 37, x = 41.9, y = 67.1, label = "Tharynn Bouden — Trade Supplies (Goldshire)", faction = "Alliance" },
      { mapId = 85, x = 46.8, y = 46.8, label = "Tailoring / trade goods (Orgrimmar)", faction = "Horde" },
    },
  },
  blue_dye = {
    key = "blue_dye",
    itemId = 6260,
    name = "Blue Dye",
    vendors = {
      { mapId = 37, x = 41.9, y = 67.1, label = "Tharynn Bouden — Trade Supplies (Goldshire)", faction = "Alliance" },
      { mapId = 85, x = 46.8, y = 46.8, label = "Tailoring / trade goods (Orgrimmar)", faction = "Horde" },
    },
  },
  red_dye = {
    key = "red_dye",
    itemId = 2604,
    name = "Red Dye",
    vendors = {
      { mapId = 37, x = 41.9, y = 67.1, label = "Tharynn Bouden — Trade Supplies (Goldshire)", faction = "Alliance" },
      { mapId = 85, x = 46.8, y = 46.8, label = "Tailoring / trade goods (Orgrimmar)", faction = "Horde" },
    },
  },
}

local QUESTS = {
  {
    questId = 29506,
    name = "A Fizzy Fusion",
    profession = "alchemy",
    skillLineId = PROFESSION_SKILL_LINE.alchemy,
    poiId = "dm_sylannia",
    requiredStacks = {
      { itemKey = "moonberry_juice", count = 5 },
      { itemKey = "fizzy_faire_drink", count = 5 },
    },
  },
  {
    questId = 29507,
    name = "Fun for the Little Ones",
    profession = "archaeology",
    skillLineId = PROFESSION_SKILL_LINE.archaeology,
    poiId = "dm_archaeology",
    requiredStacks = {},
  },
  {
    questId = 29508,
    name = "Baby Needs Two Pair of Shoes",
    profession = "blacksmithing",
    skillLineId = PROFESSION_SKILL_LINE.blacksmithing,
    poiId = "dm_yebb",
    requiredStacks = {},
  },
  {
    questId = 29509,
    name = "Putting the Crunch in the Frog",
    profession = "cooking",
    skillLineId = PROFESSION_SKILL_LINE.cooking,
    poiId = "dm_stamp",
    requiredStacks = { { itemKey = "simple_flour", count = 5 } },
  },
  {
    questId = 29510,
    name = "Putting Trash to Good Use",
    profession = "enchanting",
    skillLineId = PROFESSION_SKILL_LINE.enchanting,
    poiId = "dm_enchanting",
    requiredStacks = {},
  },
  {
    questId = 29511,
    name = "Talkin' Tonks",
    profession = "engineering",
    skillLineId = PROFESSION_SKILL_LINE.engineering,
    poiId = "dm_tonks",
    requiredStacks = {},
  },
  {
    questId = 29513,
    name = "Spoilin' for Salty Sea Dogs",
    profession = "fishing",
    skillLineId = PROFESSION_SKILL_LINE.fishing,
    poiId = "dm_fishing",
    requiredStacks = {},
  },
  {
    questId = 29514,
    name = "Herbs for Healing",
    profession = "herbalism",
    skillLineId = PROFESSION_SKILL_LINE.herbalism,
    poiId = "dm_herbalism",
    requiredStacks = {},
  },
  {
    questId = 29515,
    name = "Writing the Future",
    profession = "inscription",
    skillLineId = PROFESSION_SKILL_LINE.inscription,
    poiId = "dm_inscription",
    requiredStacks = { { itemKey = "light_parchment", count = 5 } },
  },
  {
    questId = 29516,
    name = "Keeping the Faire Sparkling",
    profession = "jewelcrafting",
    skillLineId = PROFESSION_SKILL_LINE.jewelcrafting,
    poiId = "dm_jc",
    requiredStacks = {},
  },
  {
    questId = 29517,
    name = "Eyes on the Prizes",
    profession = "leatherworking",
    skillLineId = PROFESSION_SKILL_LINE.leatherworking,
    poiId = "dm_lw",
    requiredStacks = {
      { itemKey = "shiny_bauble", count = 10 },
      { itemKey = "coarse_thread", count = 5 },
      { itemKey = "blue_dye", count = 5 },
    },
  },
  {
    questId = 29518,
    name = "Rearm, Reuse, Recycle",
    profession = "mining",
    skillLineId = PROFESSION_SKILL_LINE.mining,
    poiId = "dm_mining",
    requiredStacks = {},
  },
  {
    questId = 29519,
    name = "Tan My Hide",
    profession = "skinning",
    skillLineId = PROFESSION_SKILL_LINE.skinning,
    poiId = "dm_skinning",
    requiredStacks = {},
  },
  {
    questId = 29520,
    name = "Banners, Banners Everywhere!",
    profession = "tailoring",
    skillLineId = PROFESSION_SKILL_LINE.tailoring,
    poiId = "dm_tailor",
    requiredStacks = {
      { itemKey = "coarse_thread", count = 1 },
      { itemKey = "red_dye", count = 1 },
      { itemKey = "blue_dye", count = 1 },
    },
  },
}

local POIS = {
  dm_sylannia = { mapId = 408, x = 50.5, y = 69.8, label = "Sylannia (drinks / alchemy)" },
  dm_stamp = { mapId = 408, x = 52.9, y = 68.0, label = "Stamp Thunderhorn (cooking)" },
  dm_yebb = { mapId = 408, x = 51.3, y = 28.0, label = "Yebb Neblegear (blacksmithing)" },
  dm_archaeology = { mapId = 408, x = 51.8, y = 60.8, label = "Professor Paleo (archaeology)" },
  dm_enchanting = { mapId = 408, x = 53.0, y = 75.5, label = "Sayge (enchanting quest)" },
  dm_tonks = { mapId = 408, x = 56.2, y = 53.8, label = "Tonk arena (engineering)" },
  dm_fishing = { mapId = 408, x = 52.6, y = 88.4, label = "Shipwreck fishing pool" },
  dm_herbalism = { mapId = 408, x = 49.5, y = 56.5, label = "Herbalism (sparkling herbs)" },
  dm_inscription = { mapId = 408, x = 53.0, y = 75.5, label = "Inscription (near Sayge)" },
  dm_jc = { mapId = 408, x = 55.0, y = 70.8, label = "Jewelcrafting tent" },
  dm_lw = { mapId = 408, x = 55.6, y = 56.4, label = "Leatherworking tent" },
  dm_mining = { mapId = 408, x = 49.0, y = 50.0, label = "Tonk scrap (mining)" },
  dm_skinning = { mapId = 408, x = 55.2, y = 70.4, label = "Skinning area" },
  dm_tailor = { mapId = 408, x = 55.8, y = 55.8, label = "Tailoring tent" },
}

addon.Data = {
  PROFESSION_SKILL_LINE = PROFESSION_SKILL_LINE,
  ITEMS = ITEMS,
  QUESTS = QUESTS,
  POIS = POIS,
}
