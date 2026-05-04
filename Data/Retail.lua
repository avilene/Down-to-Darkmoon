-- Profession quest IDs/names: Wowhead retail. Shopping/vendor coords may need patch updates.
-- uiMapID: Elwynn Forest=37, Stormwind City=84, Orgrimmar=85, Darkmoon Island=407 (orphan overview). x,y are 0-100 map % on that uiMap.
--
-- Quest → hand-in NPC → POIS[profession] (keys match `profession` on each quest; island % on uiMap 407):
--  questId  quest name                        NPC (Wowhead)                    profession   407 x, y   notes
--  29506    A Fizzy Fusion                    Sylannia (npc=14844)            alchemy      50.5, 69.8
--  29507    Fun for the Little Ones         Professor Paleo (npc=14847)     archaeology  51.8, 60.8
--  29508    Baby Needs Two Pair of Shoes    Yebb Neblegear (npc=14829)      blacksmithing 51.3, 28.0  zoo / horseshoe area
--  29509    Putting the Crunch in the Frog   Stamp Thunderhorn (npc=14845)   cooking      52.9, 68.0  food pavilion
--  29510    Putting Trash to Good Use       Sayge (npc=14822)               enchanting   53.0, 75.5  fortune booth / enchanting
--  29511    Talkin' Tonks                     Rinling (npc=14841)             engineering  55.6, 56.4  same stall cluster as LW/mining
--  29513    Spoilin' for Salty Sea Dogs     Stamp Thunderhorn (npc=14845)   fishing      52.9, 68.0  same coords as cooking (one NPC)
--  29514    Herbs for Healing                Chronos (npc=14833)             herbalism    55.0, 70.6
--  29515    Writing the Future               Sayge (npc=14822)               inscription  53.0, 75.5  same NPC as enchanting daily
--  29516    Keeping the Faire Sparkling       Chronos (npc=14833)             jewelcrafting 55.0, 70.6
--  29517    Eyes on the Prizes                Rinling (npc=14841)             leatherworking 55.6, 56.4
--  29518    Rearm, Reuse, Recycle            Rinling (npc=14841)             mining       55.6, 56.4
--  29519    Tan My Hide                       Chronos (npc=14833)             skinning     55.0, 70.6
--  29520    Banners, Banners Everywhere!     Selina Dourman (npc=10445)      tailoring    55.8, 55.8
-- See: https://www.wowhead.com/quest=29506 (…replace id) for each quest.

local _, addon = ...

---@class ProfessionQuest
---@field questId number
---@field name string
---@field profession string
---@field skillLineId number
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
      --- Innkeeper Gryshka — The Broken Tusk; Valley of Strength near main gate (Moonberry from inn, not general goods).
      { mapId = 85, x = 53.6, y = 78.8, label = "Innkeeper Gryshka — The Broken Tusk (Valley of Strength)", faction = "Horde" },
    },
  },
  fizzy_faire_drink = {
    key = "fizzy_faire_drink",
    itemId = 19299,
    name = "Fizzy Faire Drink",
    vendors = {
      { mapId = 407, x = 50.5, y = 69.8, label = "Sylannia (alchemy)", faction = "Any" },
    },
  },
  simple_flour = {
    key = "simple_flour",
    itemId = 30817,
    name = "Simple Flour",
    vendors = {
      --- Quest text: Elwynn/Mulgore vendors; Tharynn Bouden trade supplies — Wowpedia npc 66 [41.9, 67.1] on Elwynn map.
      { mapId = 37, x = 41.9, y = 67.1, label = "Tharynn Bouden — Trade Supplies (Goldshire)", faction = "Alliance" },
      { mapId = 85, x = 53.8, y = 82.0, label = "Shimra (trade) & Trak'Gen (general goods) — Orgrimmar General Store, Valley of Strength", faction = "Horde" },
    },
  },
  light_parchment = {
    key = "light_parchment",
    itemId = 39354,
    name = "Light Parchment",
    vendors = {
      { mapId = 37, x = 41.9, y = 67.1, label = "Tharynn Bouden — Trade Supplies (Goldshire)", faction = "Alliance" },
      { mapId = 85, x = 53.8, y = 82.0, label = "Shimra (trade) & Trak'Gen (general goods) — Orgrimmar General Store, Valley of Strength", faction = "Horde" },
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
      { mapId = 85, x = 53.8, y = 82.0, label = "Shimra (trade) & Trak'Gen (general goods) — Orgrimmar General Store, Valley of Strength", faction = "Horde" },
    },
  },
  blue_dye = {
    key = "blue_dye",
    itemId = 6260,
    name = "Blue Dye",
    vendors = {
      { mapId = 37, x = 41.9, y = 67.1, label = "Tharynn Bouden — Trade Supplies (Goldshire)", faction = "Alliance" },
      { mapId = 85, x = 53.8, y = 82.0, label = "Shimra (trade) & Trak'Gen (general goods) — Orgrimmar General Store, Valley of Strength", faction = "Horde" },
    },
  },
  red_dye = {
    key = "red_dye",
    itemId = 2604,
    name = "Red Dye",
    vendors = {
      { mapId = 37, x = 41.9, y = 67.1, label = "Tharynn Bouden — Trade Supplies (Goldshire)", faction = "Alliance" },
      { mapId = 85, x = 53.8, y = 82.0, label = "Shimra (trade) & Trak'Gen (general goods) — Orgrimmar General Store, Valley of Strength", faction = "Horde" },
    },
  },
}

local QUESTS = {
  {
    questId = 29506,
    name = "A Fizzy Fusion",
    profession = "alchemy",
    skillLineId = PROFESSION_SKILL_LINE.alchemy,
    requiredStacks = {
      { itemKey = "moonberry_juice",   count = 5 },
      { itemKey = "fizzy_faire_drink", count = 5 },
    },
  },
  {
    questId = 29507,
    name = "Fun for the Little Ones",
    profession = "archaeology",
    skillLineId = PROFESSION_SKILL_LINE.archaeology,
    requiredStacks = {},
  },
  {
    questId = 29508,
    name = "Baby Needs Two Pair of Shoes",
    profession = "blacksmithing",
    skillLineId = PROFESSION_SKILL_LINE.blacksmithing,
    requiredStacks = {},
  },
  {
    questId = 29509,
    name = "Putting the Crunch in the Frog",
    profession = "cooking",
    skillLineId = PROFESSION_SKILL_LINE.cooking,
    requiredStacks = { { itemKey = "simple_flour", count = 5 } },
  },
  {
    questId = 29510,
    name = "Putting Trash to Good Use",
    profession = "enchanting",
    skillLineId = PROFESSION_SKILL_LINE.enchanting,
    requiredStacks = {},
  },
  {
    questId = 29511,
    name = "Talkin' Tonks",
    profession = "engineering",
    skillLineId = PROFESSION_SKILL_LINE.engineering,
    requiredStacks = {},
  },
  {
    questId = 29513,
    name = "Spoilin' for Salty Sea Dogs",
    profession = "fishing",
    skillLineId = PROFESSION_SKILL_LINE.fishing,
    requiredStacks = {},
  },
  {
    questId = 29514,
    name = "Herbs for Healing",
    profession = "herbalism",
    skillLineId = PROFESSION_SKILL_LINE.herbalism,
    requiredStacks = {},
  },
  {
    questId = 29515,
    name = "Writing the Future",
    profession = "inscription",
    skillLineId = PROFESSION_SKILL_LINE.inscription,
    requiredStacks = { { itemKey = "light_parchment", count = 5 } },
  },
  {
    questId = 29516,
    name = "Keeping the Faire Sparkling",
    profession = "jewelcrafting",
    skillLineId = PROFESSION_SKILL_LINE.jewelcrafting,
    requiredStacks = {},
  },
  {
    questId = 29517,
    name = "Eyes on the Prizes",
    profession = "leatherworking",
    skillLineId = PROFESSION_SKILL_LINE.leatherworking,
    requiredStacks = {
      { itemKey = "shiny_bauble",  count = 10 },
      { itemKey = "coarse_thread", count = 5 },
      { itemKey = "blue_dye",      count = 5 },
    },
  },
  {
    questId = 29518,
    name = "Rearm, Reuse, Recycle",
    profession = "mining",
    skillLineId = PROFESSION_SKILL_LINE.mining,
    requiredStacks = {},
  },
  {
    questId = 29519,
    name = "Tan My Hide",
    profession = "skinning",
    skillLineId = PROFESSION_SKILL_LINE.skinning,
    requiredStacks = {},
  },
  {
    questId = 29520,
    name = "Banners, Banners Everywhere!",
    profession = "tailoring",
    skillLineId = PROFESSION_SKILL_LINE.tailoring,
    requiredStacks = {
      { itemKey = "coarse_thread", count = 1 },
      { itemKey = "red_dye",       count = 1 },
      { itemKey = "blue_dye",      count = 1 },
    },
  },
}

--- Keys match each quest's `profession` string (PROFESSION_SKILL_LINE names).
local POIS = {
  alchemy = { mapId = 407, x = 50.5, y = 69.8, label = "Sylannia (alchemy)" },
  archaeology = { mapId = 407, x = 51.8, y = 60.8, label = "Professor Paleo (archaeology)" },
  blacksmithing = { mapId = 407, x = 51.3, y = 28.0, label = "Yebb Neblegear (blacksmithing)" },
  cooking = { mapId = 407, x = 52.9, y = 68.0, label = "Stamp Thunderhorn (cooking)" },
  enchanting = { mapId = 407, x = 53.0, y = 75.5, label = "Sayge (enchanting)" },
  engineering = { mapId = 407, x = 55.6, y = 56.4, label = "Rinling (engineering)" },
  --- Same world NPC as `cooking` (quests 29513 / 29509); coords must match.
  fishing = { mapId = 407, x = 52.9, y = 68.0, label = "Stamp Thunderhorn (fishing)" },
  herbalism = { mapId = 407, x = 55.0, y = 70.6, label = "Chronos (herbalism)" },
  inscription = { mapId = 407, x = 53.0, y = 75.5, label = "Sayge (inscription)" },
  jewelcrafting = { mapId = 407, x = 55.0, y = 70.6, label = "Chronos (jewelcrafting)" },
  leatherworking = { mapId = 407, x = 55.6, y = 56.4, label = "Rinling (leatherworking)" },
  mining = { mapId = 407, x = 55.6, y = 56.4, label = "Rinling (mining)" },
  skinning = { mapId = 407, x = 55.0, y = 70.6, label = "Chronos (skinning)" },
  tailoring = { mapId = 407, x = 55.8, y = 55.8, label = "Selina Dourman (tailoring)" },
}

addon.Data = {
  PROFESSION_SKILL_LINE = PROFESSION_SKILL_LINE,
  ITEMS = ITEMS,
  QUESTS = QUESTS,
  POIS = POIS,
}
