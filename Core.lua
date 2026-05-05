local addonName, addon = ...

DownToDarkmoon = addon

local defaults = {
  point = "CENTER",
  x = 0,
  y = 100,
  --- Main panel scale (0.5–1.5); see /dtdm scale
  scale = 1,
  hidden = true,
  --- When true, waypoint/pin attempts log to chat (/dtdm navdebug).
  debugNavigation = false,
  --- LibDBIcon saved placement (see LibDBIcon-1.0 docs)
  minimap = {
    hide = false,
    minimapPos = 225,
  },
}

--- Ignores live in DownToDarkmoonCharDB (SavedVariablesPerCharacter).
local charDefaults = {
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

function addon:GetCharDB()
  return DownToDarkmoonCharDB
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

--- Localized item name for secure `item` actions (best effort; may be nil until the client caches the item).
function addon:GetItemNameByIDCompat(itemId)
  if not itemId then
    return nil
  end
  if C_Item and type(C_Item.GetItemNameByID) == "function" then
    local n = C_Item.GetItemNameByID(itemId)
    if type(n) == "string" and n ~= "" then
      return n
    end
  end
  if type(GetItemInfo) == "function" then
    local name = select(1, GetItemInfo(itemId))
    if type(name) == "string" and name ~= "" then
      return name
    end
  end
  return nil
end

--- Item id from an item hyperlink (quest log / merchant links).
function addon:GetItemIdFromHyperlink(link)
  if type(link) ~= "string" then
    return nil
  end
  return tonumber(link:match("Hitem:(%d+)") or link:match("item:(%d+)"))
end

--- Item id for the quest's tracker special-item slot (same as the icon beside the objective tracker entry).
function addon:GetQuestLogSpecialItemIdForQuest(questId)
  if not questId or not C_QuestLog or type(C_QuestLog.GetLogIndexForQuestID) ~= "function" then
    return nil
  end
  if type(GetQuestLogSpecialItemInfo) ~= "function" then
    return nil
  end
  local logIndex = C_QuestLog.GetLogIndexForQuestID(questId)
  if not logIndex then
    return nil
  end
  local ok, link = pcall(function()
    return (select(1, GetQuestLogSpecialItemInfo(logIndex)))
  end)
  if not ok or type(link) ~= "string" or link == "" then
    return nil
  end
  return self:GetItemIdFromHyperlink(link)
end

--- Whether this row's item matches what the tracker would use (when the API reports it).
function addon:QuestLogSpecialItemMatchesItemId(questId, itemId)
  if not itemId then
    return false
  end
  local sid = self:GetQuestLogSpecialItemIdForQuest(questId)
  if not sid then
    return true
  end
  return sid == itemId
end

--- Localized name (+ optional icon) from a real bag stack.
--- Lucky's Grab-bag UseItems.lua uses `SetAttribute("item", item.itemName)` from `C_Container.GetContainerItemInfo` — same requirement for SecureActionButton `type=item`.
function addon:GetBagSlotDisplayForItemId(itemId)
  if not itemId or not C_Container or type(C_Container.GetContainerNumSlots) ~= "function" or type(C_Container.GetContainerItemInfo) ~= "function" then
    return nil, nil
  end
  local maxBag = type(NUM_BAG_SLOTS) == "number" and NUM_BAG_SLOTS or 4
  for bag = 0, maxBag do
    local numSlots = C_Container.GetContainerNumSlots(bag)
    if type(numSlots) == "number" and numSlots > 0 then
      for slot = 1, numSlots do
        local info = C_Container.GetContainerItemInfo(bag, slot)
        if info and info.itemID == itemId then
          local name = info.itemName
          if type(name) ~= "string" or name == "" then
            if C_Item and type(C_Item.GetItemNameByID) == "function" then
              local ok, n = pcall(C_Item.GetItemNameByID, itemId)
              if ok and type(n) == "string" and n ~= "" then
                name = n
              end
            end
          end
          local icon = info.iconFileID
          if type(name) == "string" and name ~= "" then
            return name, icon
          end
          return nil, icon
        end
      end
    end
  end
  if C_Item and type(C_Item.RequestLoadItemDataByID) == "function" then
    pcall(C_Item.RequestLoadItemDataByID, itemId)
  end
  return nil, nil
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
  local db = DownToDarkmoonCharDB
  if type(db) ~= "table" then
    return false
  end
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
  local db = DownToDarkmoonCharDB
  if type(db) ~= "table" then
    return
  end
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

--- True when this character has at least one tracked profession and every matching Darkmoon quest is completed or ignored (same rule as the panel “See you…” banner).
function addon:AreAllDarkmoonProfessionQuestsDoneForCharacter()
  if not self.Data or not self.Data.QUESTS then
    return false
  end
  local skill = self:PlayerSkillLineSet()
  local any = false
  for _, q in ipairs(self.Data.QUESTS) do
    if skill[q.skillLineId] then
      any = true
      local completed = self:IsProfessionQuestCompleted(q.questId)
      local ignored = self:IsProfessionQuestIgnored(q.questId)
      if not completed and not ignored then
        return false
      end
    end
  end
  return any
end

function addon:GetProfessionQuestDef(questId)
  if not questId or not self.Data or not self.Data.QUESTS then
    return nil
  end
  for _, q in ipairs(self.Data.QUESTS) do
    if q.questId == questId then
      return q
    end
  end
  return nil
end

--- Panel rows for `useQuestItems`: only while on the quest (not merely unlocked), not ignored, not completed.
function addon:ShouldShowQuestUseItemRows(questId, ignored, completed)
  if not questId or completed or ignored then
    return false
  end
  if not C_QuestLog or type(C_QuestLog.IsOnQuest) ~= "function" then
    return false
  end
  local ok, onQuest = pcall(C_QuestLog.IsOnQuest, questId)
  return ok and onQuest == true
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

--- Hide vendor/shopping rows when mats are satisfied, the quest has moved on (e.g. crafted Crunchy Frogs),
--- or the player already holds a later-stage item from `Data/Retail.lua` `hideRequiredStacksWhenHaveItemIds`.
function addon:ShouldShowShoppingIngredientRow(questId, itemId, need)
  if not questId or not itemId or not need then
    return true
  end
  if self:IsProfessionQuestIgnored(questId) then
    return false
  end
  local qdef = self:GetProfessionQuestDef(questId)
  if qdef and type(qdef.hideRequiredStacksWhenHaveItemIds) == "table" then
    for _, uid in ipairs(qdef.hideRequiredStacksWhenHaveItemIds) do
      if type(uid) == "number" and self:GetItemCountCompat(uid) > 0 then
        return false
      end
    end
  end
  local still = self.QuantityAssist:GetStillNeed(itemId, need)
  if still <= 0 then
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
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")

eventFrame:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == addonName then
    DownToDarkmoonDB = mergeDefaults(DownToDarkmoonDB, defaults)
    DownToDarkmoonCharDB = mergeDefaults(DownToDarkmoonCharDB, charDefaults)
    --- One-time: copy legacy account-wide ignores into this character’s table (pre–per-char storage).
    if DownToDarkmoonCharDB._legacyIgnoresImported ~= true then
      local legacy = DownToDarkmoonDB.ignoredProfessionQuestIds
      if type(legacy) == "table" then
        for questId, v in pairs(legacy) do
          if v == true then
            local id = type(questId) == "number" and questId or tonumber(questId)
            if id then
              DownToDarkmoonCharDB.ignoredProfessionQuestIds[id] = true
            end
          end
        end
      end
      DownToDarkmoonCharDB._legacyIgnoresImported = true
    end
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
      local raw = strtrim(msg or "")
      local cmd = raw:lower()
      if cmd == "navdebug" or cmd == "pins" or cmd == "waypoints" then
        DownToDarkmoonDB.debugNavigation = not DownToDarkmoonDB.debugNavigation
        print(
          "|cfffeaa00Down to Darkmoon:|r Waypoint / map pin debug:",
          DownToDarkmoonDB.debugNavigation and "|cff33ff33ON|r" or "|cffff5555OFF|r",
          "(logs pin attempts to chat; toggle with /dtdm navdebug)"
        )
        return
      end
      if cmd:sub(1, 5) == "scale" then
        local numStr = raw:lower():match("^scale%s+([%d%.]+)")
        if cmd == "scale" or numStr == nil or numStr == "" then
          print("|cfffeaa00Down to Darkmoon:|r Usage: |cffffffff/dtdm scale 0.85|r  (window scale, range |cffffffff0.5–1.5|r)")
          return
        end
        local v = tonumber(numStr)
        if not v then
          print("|cfffeaa00Down to Darkmoon:|r Could not parse scale; example: |cffffffff/dtdm scale 1|r")
          return
        end
        v = math.max(0.5, math.min(1.5, v))
        DownToDarkmoonDB.scale = v
        addon.UI:ApplySavedScale()
        print(
          ("|cfffeaa00Down to Darkmoon:|r Panel scale set to |cffffffff%.2f|r (saved)."):format(v)
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
    addon.UI:ApplySavedScale()
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
