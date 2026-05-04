local addonName, addon = ...

DownToDarkmoon = addon

local defaults = {
  point = "CENTER",
  x = 0,
  y = 100,
  hidden = true,
  --- When true, waypoint/pin attempts log to chat (/dtdm navdebug).
  debugNavigation = false,
  --- LibDBIcon saved placement (see LibDBIcon-1.0 docs)
  minimap = {
    hide = false,
    minimapPos = 225,
  },
  --- Per-character: profession quest IDs excluded from Pull/Buy hints (right-click quest row).
  ignoredProfessionQuestIds = {},
}

local function strtrim(s)
  return (s or ""):match("^%s*(.-)%s*$") or ""
end

local eventFrame = CreateFrame("Frame")

local function mergeDefaults(dst, src)
  if type(dst) ~= "table" then
    dst = {}
  end
  for k, v in pairs(src) do
    if dst[k] == nil then
      dst[k] = v
    end
  end
  return dst
end

function addon:GetDB()
  return DownToDarkmoonDB
end

function addon:PlayerSkillLineSet()
  local set = {}
  local profs = { GetProfessions() }
  for _, profIndex in ipairs(profs) do
    if profIndex then
      local _, _, _, _, _, _, skillLineID = GetProfessionInfo(profIndex)
      if skillLineID then
        set[skillLineID] = true
      end
    end
  end
  return set
end

function addon:PlayerHasProfession(skillLineId)
  return self:PlayerSkillLineSet()[skillLineId]
end

--- Item API compatibility: some game builds expose C_Item only partially.
--- Bags only (no bank / reagent bank / warband) — quest prep is “on your character,” Pull handles moving from bank.
function addon:GetItemCountCompat(itemId)
  if not itemId then
    return 0
  end
  if C_Item and type(C_Item.GetItemCount) == "function" then
    return C_Item.GetItemCount(itemId, false, false, false, false) or 0
  end
  if type(GetItemCount) == "function" then
    return GetItemCount(itemId) or 0
  end
  return 0
end

function addon:GetItemIconByIDCompat(itemId)
  if not itemId then
    return nil
  end
  if C_Item and type(C_Item.GetItemIconByID) == "function" then
    local icon = C_Item.GetItemIconByID(itemId)
    if icon and icon ~= "" then
      return icon
    end
  end
  if type(GetItemIcon) == "function" then
    local icon = GetItemIcon(itemId)
    if icon and icon ~= "" then
      return icon
    end
  end
  if type(GetItemInfoInstant) == "function" then
    local ok, a1, a2, a3, a4, a5, a6, a7, a8, a9, tex = pcall(GetItemInfoInstant, itemId)
    if ok then
      if type(a1) == "table" and a1.iconFileID then
        return a1.iconFileID
      end
      if tex and tex ~= "" then
        return tex
      end
    end
  end
  return nil
end

function addon:SetItemIconTexture(texture, itemId)
  local icon = self:GetItemIconByIDCompat(itemId) or "Interface\\Icons\\INV_Misc_QuestionMark"
  if type(SetPortraitToTexture) == "function" then
    SetPortraitToTexture(texture, icon)
  else
    texture:SetTexture(icon)
  end
end

--- Fallback trade-skill icons by TradeSkillLineID (matches Data/Retail.lua) when C_TradeSkillUI / GetProfessionInfo fail.
local FALLBACK_PROFESSION_TEXTURE = {
  [171] = "Interface\\Icons\\Trade_Alchemy",
  [164] = "Interface\\Icons\\Trade_BlackSmithing",
  [165] = "Interface\\Icons\\Trade_Leatherworking",
  [197] = "Interface\\Icons\\Trade_Tailoring",
  [202] = "Interface\\Icons\\Trade_Engineering",
  [182] = "Interface\\Icons\\Trade_Herbalism",
  [186] = "Interface\\Icons\\Trade_Mining",
  [393] = "Interface\\Icons\\Trade_Skinning",
  [755] = "Interface\\Icons\\INV_Misc_Gem_02",
  [333] = "Interface\\Icons\\Trade_Engraving",
  [773] = "Interface\\Icons\\INV_Inscription_TradeskillBook",
  [185] = "Interface\\Icons\\INV_Misc_Food_15",
  [356] = "Interface\\Icons\\Trade_Fishing",
  [394] = "Interface\\Icons\\Trade_Archaeology",
}

function addon:GetProfessionIconTextureForSkillLine(skillLineId)
  if not skillLineId then
    return nil
  end
  if C_TradeSkillUI and type(C_TradeSkillUI.GetTradeSkillTexture) == "function" then
    local ok, tex = pcall(C_TradeSkillUI.GetTradeSkillTexture, skillLineId)
    if ok and tex and tex ~= "" then
      return tex
    end
  end
  local profs = { GetProfessions() }
  for _, profIndex in ipairs(profs) do
    if profIndex then
      local _, icon, _, _, _, _, sl = GetProfessionInfo(profIndex)
      if sl == skillLineId and icon then
        return icon
      end
    end
  end
  return FALLBACK_PROFESSION_TEXTURE[skillLineId]
end

function addon:SetProfessionIconTexture(texture, skillLineId)
  local icon = self:GetProfessionIconTextureForSkillLine(skillLineId)
  if not icon then
    texture:Hide()
    return
  end
  texture:Show()
  if type(SetPortraitToTexture) == "function" then
    SetPortraitToTexture(texture, icon)
  else
    texture:SetTexture(icon)
  end
end

--- Prefix for GameTooltip:AddLine; uses inline |T…|t when a texture exists.
function addon:FormatTooltipLineWithProfessionIcon(skillLineId, text)
  if not text or text == "" then
    return text or ""
  end
  local icon = self:GetProfessionIconTextureForSkillLine(skillLineId)
  if not icon then
    return text
  end
  if type(icon) == "number" then
    return ("|T%d:20:20:0:0|t %s"):format(icon, text)
  end
  return ("|T%s:20:20:0:0|t %s"):format(icon, text)
end

--- Green row uses Blizzard's per-character quest completion flag for this questId (same as minimap quest icons).
function addon:IsProfessionQuestIgnored(questId)
  if not questId then
    return false
  end
  local db = self:GetDB()
  local t = db.ignoredProfessionQuestIds
  if type(t) ~= "table" then
    return false
  end
  return t[questId] == true
end

function addon:SetProfessionQuestIgnored(questId, ignored)
  if not questId then
    return
  end
  local db = self:GetDB()
  if type(db.ignoredProfessionQuestIds) ~= "table" then
    db.ignoredProfessionQuestIds = {}
  end
  if ignored then
    db.ignoredProfessionQuestIds[questId] = true
  else
    db.ignoredProfessionQuestIds[questId] = nil
  end
end

function addon:IsProfessionQuestCompleted(questId)
  if not questId then
    return false
  end
  if C_QuestLog and type(C_QuestLog.IsQuestFlaggedCompleted) == "function" then
    return C_QuestLog.IsQuestFlaggedCompleted(questId)
  end
  if type(IsQuestFlaggedCompleted) == "function" then
    return IsQuestFlaggedCompleted(questId)
  end
  return false
end

--- Objective lines from the quest log API (same text/progress as the default tracker).
function addon:GetQuestObjectiveEntries(questId)
  if not questId or not C_QuestLog or type(C_QuestLog.IsOnQuest) ~= "function" or not C_QuestLog.IsOnQuest(questId) then
    return {}
  end
  if type(C_QuestLog.GetQuestObjectives) ~= "function" then
    return {}
  end
  local ok, objs = pcall(C_QuestLog.GetQuestObjectives, questId)
  if not ok or type(objs) ~= "table" then
    return {}
  end
  local out = {}
  for _, o in ipairs(objs) do
    local text
    if type(o.text) == "string" and o.text ~= "" then
      text = o.text
    elseif type(o.numRequired) == "number" and o.numRequired > 0 then
      text = ("%d/%d"):format(o.numFulfilled or 0, o.numRequired)
    end
    if text then
      out[#out + 1] = {
        text = text,
        finished = o.finished and true or false,
      }
    end
  end
  return out
end

--- Hide vendor/shopping rows when mats are satisfied or the quest has moved on (e.g. crafted Crunchy Frogs).
function addon:ShouldShowShoppingIngredientRow(questId, itemId, need)
  if not questId or not itemId or not need then
    return true
  end
  if self:IsProfessionQuestIgnored(questId) then
    return false
  end
  local still = self.QuantityAssist:GetStillNeed(itemId, need)
  if still <= 0 then
    return false
  end
  if not C_QuestLog or type(C_QuestLog.IsOnQuest) ~= "function" or not C_QuestLog.IsOnQuest(questId) then
    return true
  end
  local ok, objs = pcall(C_QuestLog.GetQuestObjectives, questId)
  if not ok or type(objs) ~= "table" then
    return true
  end
  local have = self:GetItemCountCompat(itemId)
  local anyQtyProgress = false
  local hasQtyObjective = false
  local allQtyDone = true
  for _, o in ipairs(objs) do
    local nr = o.numRequired
    if type(nr) == "number" and nr > 0 then
      hasQtyObjective = true
      local nf = o.numFulfilled or 0
      if nf > 0 or o.finished then
        anyQtyProgress = true
      end
      if not o.finished and nf < nr then
        allQtyDone = false
      end
    end
  end
  if hasQtyObjective and allQtyDone then
    return false
  end
  if anyQtyProgress and have == 0 then
    return false
  end
  return true
end

function addon:TogglePanel()
  if not self.UI or not self.UI.mainFrame then
    return
  end
  local f = self.UI.mainFrame
  if f:IsShown() then
    f:Hide()
    DownToDarkmoonDB.hidden = true
  else
    f:Show()
    DownToDarkmoonDB.hidden = false
    addon._inactiveBootFrozen = false
    addon.Calendar:RefreshActiveState()
    self.UI:Refresh()
    addon.Calendar:ScheduleRefresh(0)
  end
end

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("BAG_UPDATE")
eventFrame:RegisterEvent("UNIT_INVENTORY_CHANGED")
eventFrame:RegisterEvent("QUEST_LOG_UPDATE")
eventFrame:RegisterEvent("BANKFRAME_OPENED")
eventFrame:RegisterEvent("BANKFRAME_CLOSED")
eventFrame:RegisterEvent("MERCHANT_SHOW")
eventFrame:RegisterEvent("MERCHANT_CLOSED")
eventFrame:RegisterEvent("MERCHANT_UPDATE")
eventFrame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
eventFrame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE")

eventFrame:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == addonName then
    DownToDarkmoonDB = mergeDefaults(DownToDarkmoonDB, defaults)
    if type(DownToDarkmoonDB.minimapAngle) == "number" and type(DownToDarkmoonDB.minimap) == "table" then
      DownToDarkmoonDB.minimap.minimapPos = DownToDarkmoonDB.minimap.minimapPos or DownToDarkmoonDB.minimapAngle
    end
    addon.UI:CreateMainFrame()
    addon.Calendar:Init()
    addon.Minimap:Init()
    if not DownToDarkmoonDB.hidden then
      addon.UI.mainFrame:Show()
      addon.UI:Refresh()
    end
    SLASH_DOWNTO_DARKMOON1 = "/dtdm"
    SLASH_DOWNTO_DARKMOON2 = "/downtodarkmoon"
    SlashCmdList["DOWNTO_DARKMOON"] = function(msg)
      local cmd = strtrim(msg or ""):lower()
      if cmd == "navdebug" or cmd == "pins" or cmd == "waypoints" then
        DownToDarkmoonDB.debugNavigation = not DownToDarkmoonDB.debugNavigation
        print(
          "|cfffeaa00Down to Darkmoon:|r Waypoint / map pin debug:",
          DownToDarkmoonDB.debugNavigation and "|cff33ff33ON|r" or "|cffff5555OFF|r",
          "(logs pin attempts to chat; toggle with /dtdm navdebug)"
        )
        return
      end
      addon:TogglePanel()
    end
    return
  end
  if event == "PLAYER_LOGIN" then
    addon.Calendar:ScheduleRefresh(0)
    addon.UI:ApplySavedPosition()
    if addon.UI.mainFrame and addon.UI.mainFrame:IsShown() then
      addon.UI:Refresh()
    end
    return
  end
  if event == "UNIT_INVENTORY_CHANGED" and arg1 ~= "player" then
    return
  end
  --- Merchant listing refresh (pages/stock); vendor UI often uses interaction manager instead of MERCHANT_SHOW alone.
  if event == "MERCHANT_UPDATE" then
    if addon.UI and addon.UI.mainFrame and addon.UI.mainFrame:IsShown() then
      addon.UI:Refresh()
    end
    return
  end
  local Pit = Enum.PlayerInteractionType
  if Pit and event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
    if arg1 == Pit.Merchant or arg1 == Pit.Vendor then
      if addon.UI and addon.UI.mainFrame and addon.UI.mainFrame:IsShown() then
        addon.UI:Refresh()
      end
      return
    end
  end
  if Pit and event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
    if arg1 == Pit.Merchant or arg1 == Pit.Vendor then
      if addon.UI and addon.UI.mainFrame and addon.UI.mainFrame:IsShown() then
        addon.UI:Refresh()
      end
      return
    end
  end
  if addon.UI and addon.UI.mainFrame and addon.UI.mainFrame:IsShown() then
    addon.UI:Refresh()
  end
end)
