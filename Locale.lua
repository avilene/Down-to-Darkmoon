local _, addon = ...

local locale = GetLocale and GetLocale() or "enUS"

local enUS = {
  PANEL_TITLE = "Down to Darkmoon",
  PANEL_NOT_ON_QUEST = "not on quest",
  PANEL_COMPLETED = "completed",
  PANEL_COMPLETED_IGNORED = "completed (ignored)",
  PANEL_IGNORED = "ignored",
  PANEL_SEE_YOU_ON = "See you on |cffffffff%s|r for the next Faire!",
  PANEL_SEE_YOU_NEXT = "See you at the next Faire! (Open the calendar once if the date doesn't show.)",
  PANEL_NO_QUESTS = "No Darkmoon profession quests to show. Train a profession or use a character with one.",

  BTN_BUY = "Buy",
  BTN_PULL = "Pull",
  BTN_USE = "Use",

  TIP_IGNORED_HIDDEN = "Ignored on this character: shopping / Pull / Buy hidden.",
  TIP_RIGHT_CLICK_TRACK = "Right-click: track again.",
  TIP_COMPLETED_THIS_FAIRE = "Completed for this Darkmoon Faire.",
  TIP_RIGHT_CLICK_IGNORE = "Right-click: ignore for this character (grey out, hide shopping).",
  TIP_CLICK_WAYPOINT_ISLAND = "Click: waypoint on Darkmoon Island.",
  TIP_MAP_PIN = "Darkmoon map pin: |cffffffff%.1f, %.1f|r (install TomTom for arrows).",
  TIP_INSTALL_TOMTOM = "Install TomTom for in-game waypoints, or use the map %% on the quest line.",
  TIP_RIGHT_CLICK_IGNORE_QUEST = "Right-click: ignore quest on this character.",

  TIP_VENDOR_WAYPOINT = "Click: closest vendor waypoint.",
  TIP_PULL_HEADER = "Pull from bank",
  TIP_UNAVAILABLE_COMBAT = "Unavailable in combat.",
  TIP_PULL_OPEN_BANK = "Open your bank, then click to withdraw what you still need.",
  TIP_PULL_NOTHING_LEFT = "Nothing left to withdraw for this line.",
  TIP_PULL_WITHDRAW = "Click to withdraw up to the amount you still need.",
  TIP_PULL_NONE_IN_BANK = "If nothing moves, you have no stacks of this item in the bank.",

  TIP_BUY_HEADER = "Buy from vendor",
  TIP_BUY_SET_WAYPOINT = "Click to set a waypoint to a vendor that sells this item.",
  TIP_BUY_WHEN_VENDOR_OPEN = "When a vendor window is open, click buys what you can afford.",
  TIP_BUY_NOTHING_LEFT = "Nothing left to buy for this line.",
  TIP_BUY_CANNOT = "Cannot buy any right now (not enough coin or vendor stock).",
  TIP_BUY_VENDOR_NO_SELL = "This merchant does not sell this item — click to route to a vendor that does.",
  TIP_BUY_CAN = "Click to buy up to what you can afford and still need.",

  TIP_USE_HEADER = "Use quest item",
  TIP_USE_COMBAT = "Unavailable in combat (try again out of combat).",
  TIP_USE_BAGS = "Uses the item in your bags.",

  COUNT_IN_BAGS = "%d in bags",
  ITEM_FALLBACK = "Item %s",

  MSG_CANNOT_PULL_COMBAT = "|cfffeaa00Down to Darkmoon:|r Cannot pull from the bank in combat.",
  MSG_OPEN_BANK_PULL = "|cfffeaa00Down to Darkmoon:|r Open your bank to pull materials.",
  MSG_CANNOT_BUY_COMBAT = "|cfffeaa00Down to Darkmoon:|r Cannot buy in combat.",
  MSG_CANNOT_BUY_NOW = "|cfffeaa00Down to Darkmoon:|r Cannot buy any right now (not enough coin or vendor stock).",
  MSG_CANNOT_USE_COMBAT = "|cfffeaa00Down to Darkmoon:|r Cannot use quest items in combat.",
  MSG_CANNOT_USE_BAGS = "|cfffeaa00Down to Darkmoon:|r Could not use that item from your bags.",
  MSG_CANNOT_WITHDRAW_COMBAT = "|cfffeaa00Down to Darkmoon:|r Cannot withdraw in combat.",
  MSG_NO_BANK_STACKS = "|cfffeaa00Down to Darkmoon:|r No matching stacks in bank.",
  MSG_NO_BAG_SPACE = "|cfffeaa00Down to Darkmoon:|r No empty bag space.",

  SLASH_DEBUG = "|cfffeaa00Down to Darkmoon:|r Debug logging:",
  SLASH_ON = "|cff33ff33ON|r",
  SLASH_OFF = "|cffff5555OFF|r",
  SLASH_DEBUG_HINT = "|cfffeaa00Down to Darkmoon:|r /dtdm debug (toggle debug logging)",
  SLASH_SCALE_USAGE = "|cfffeaa00Down to Darkmoon:|r /dtdm scale 0.85 (window scale, range |cffffffff0.5–1.5|r)",
  SLASH_SCALE_PARSE = "|cfffeaa00Down to Darkmoon:|r Could not parse scale; example: |cffffffff/dtdm scale 1|r",
  SLASH_SCALE_SET = "|cfffeaa00Down to Darkmoon:|r Panel scale set to |cffffffff%.2f|r (saved).",
}

local locales = {
  enUS = enUS,
}

local active = locales[locale] or enUS
setmetatable(active, { __index = enUS })
addon.L = active

