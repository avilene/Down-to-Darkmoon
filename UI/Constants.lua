local _, addon = ...

--- Root table for all UI modules; loaded first.
addon.UI = addon.UI or {}

local WIDTH = 300
local PAD = 6
local ITEM_ROW_H = 24
local ACTION_BTN_W = 54
local ACTION_BTN_H = 20
local ACTION_BTN_GAP = 4

--- Single source of truth for layout (used by MainFrame, Rows, Refresh).
addon.UI.C = {
  QUEST_ROW_H = 22,
  OBJECTIVE_ROW_H = 15,
  ITEM_ROW_H = ITEM_ROW_H,
  ROW_GAP = 1,
  SECTION_GAP = 4,
  PAD = PAD,
  TITLE_H = 26,
  WIDTH = WIDTH,
  GAP_TITLE_TO_BODY = 10,
  FRAME_BOTTOM_PAD = 4,
  --- Space between the quest list and the “See you…” line when everything is done/ignored.
  ALL_DONE_GAP_TOP = 12,
  CONTENT_W = WIDTH - 2 * PAD,
  COLOR_TITLE = { 1, 0.85, 0.35 },
  COLOR_ITEM_NAME = { 0.92, 0.92, 0.96 },
  ACTION_BTN_W = ACTION_BTN_W,
  ACTION_BTN_H = ACTION_BTN_H,
  ACTION_BTN_GAP = ACTION_BTN_GAP,
  --- Right margin + Buy + gap + Pull (matches item row anchors).
  ITEM_ACTION_BAR_OFFSET = 2 + ACTION_BTN_W + ACTION_BTN_GAP + ACTION_BTN_W,
  QUEST_USE_BTN_SIZE = ITEM_ROW_H - 2,
}

addon.UI.C.QUEST_USE_ACTION_OFFSET = 2 + addon.UI.C.QUEST_USE_BTN_SIZE
