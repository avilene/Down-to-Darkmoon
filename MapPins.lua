local addonName, addon = ...

--- RareScanner-style pins for "discoverable" Darkmoon interactables (tonks, loose stones,
--- anvils, herb nodes, scrap piles, staked skins). Shown on the world map AND minimap via
--- HereBeDragons-Pins, but only while you are on that profession's Darkmoon quest.
local MapPins = {}
addon.MapPins = MapPins

local PIN_REF = "DownToDarkmoonInteractables"
local ICON_SIZE = 15
--- Interactables live on the Darkmoon Island overview uiMap (orphan 407); showInParentZone
--- lets HBD also draw them on the playable floor (408) map/minimap.
local DARKMOON_UIMAP = 407

local HBDP

local worldPool, worldActive = {}, {}
local minimapPool, minimapActive = {}, {}
local refreshTimer

local function log(msg)
  if addon.Logger and type(addon.Logger.Debug) == "function" then
    addon.Logger:Debug("pins", tostring(msg))
  end
end

local function pinTooltipShow(self)
  if not self.dtdLabel then
    return
  end
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:AddLine(self.dtdLabel, 1, 0.82, 0.28)
  if self.dtdSubLabel then
    GameTooltip:AddLine(self.dtdSubLabel, 0.75, 0.85, 1, true)
  end
  GameTooltip:Show()
end

local function createIcon()
  local icon = CreateFrame("Button", nil, UIParent, "BackdropTemplate")
  icon:SetSize(ICON_SIZE, ICON_SIZE)
  icon:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 8 })
  icon:SetBackdropBorderColor(1, 0.82, 0.28, 1)
  local tex = icon:CreateTexture(nil, "ARTWORK")
  tex:SetPoint("TOPLEFT", 2, -2)
  tex:SetPoint("BOTTOMRIGHT", -2, 2)
  tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  icon.tex = tex
  icon:EnableMouse(true)
  icon:SetScript("OnEnter", pinTooltipShow)
  icon:SetScript("OnLeave", GameTooltip_Hide)
  icon:Hide()
  return icon
end

local function acquireIcon(pool)
  local icon = table.remove(pool)
  if not icon then
    icon = createIcon()
  end
  return icon
end

local function configureIcon(icon, iconTexture, label, subLabel)
  if iconTexture then
    icon.tex:SetTexture(iconTexture)
  else
    icon.tex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
  end
  icon.dtdLabel = label
  icon.dtdSubLabel = subLabel
  icon:Show()
end

--- Clear every pin we registered and return the frames to their pools.
function MapPins:ClearAll()
  if not HBDP then
    return
  end
  HBDP:RemoveAllMinimapIcons(PIN_REF)
  HBDP:RemoveAllWorldMapIcons(PIN_REF)
  for icon in pairs(worldActive) do
    icon:Hide()
    icon:SetScript("OnUpdate", nil)
    worldPool[#worldPool + 1] = icon
  end
  wipe(worldActive)
  for icon in pairs(minimapActive) do
    icon:Hide()
    minimapPool[#minimapPool + 1] = icon
  end
  wipe(minimapActive)
end

--- Professions whose Darkmoon quest is currently in the quest log (and not done/ignored).
local function professionOnQuest(profession)
  if not addon.Data or not addon.Data.QUESTS then
    return nil
  end
  for _, q in ipairs(addon.Data.QUESTS) do
    if q.profession == profession then
      if addon:IsProfessionQuestCompleted(q.questId) or addon:IsProfessionQuestIgnored(q.questId) then
        return nil
      end
      if C_QuestLog and type(C_QuestLog.IsOnQuest) == "function" then
        local ok, onQuest = pcall(C_QuestLog.IsOnQuest, q.questId)
        if ok and onQuest then
          return q
        end
      end
      return nil
    end
  end
  return nil
end

local function addLocationPins(entry, quest)
  local iconTexture = addon:GetProfessionIconTextureForSkillLine(quest.skillLineId)
  local questName = addon:GetQuestTitleByIDCompat(quest.questId) or quest.name
  for _, loc in ipairs(entry.locations) do
    local mapId = loc.mapId or DARKMOON_UIMAP
    local x, y = loc.x / 100, loc.y / 100
    local label = loc.label or entry.label

    local wIcon = acquireIcon(worldPool)
    configureIcon(wIcon, iconTexture, label, questName)
    if HBDP:AddWorldMapIconMap(PIN_REF, wIcon, mapId, x, y, HBD_PINS_WORLDMAP_SHOW_PARENT) then
      worldActive[wIcon] = true
    else
      wIcon:Hide()
      worldPool[#worldPool + 1] = wIcon
      log(("world pin rejected: %s (%s %.1f,%.1f)"):format(label, tostring(mapId), loc.x, loc.y))
    end

    local mIcon = acquireIcon(minimapPool)
    configureIcon(mIcon, iconTexture, label, questName)
    if HBDP:AddMinimapIconMap(PIN_REF, mIcon, mapId, x, y, true, true) then
      minimapActive[mIcon] = true
    else
      mIcon:Hide()
      minimapPool[#minimapPool + 1] = mIcon
      log(("minimap pin rejected: %s (%s %.1f,%.1f)"):format(label, tostring(mapId), loc.x, loc.y))
    end
  end
end

function MapPins:Refresh()
  if not HBDP then
    return
  end
  self:ClearAll()

  local db = addon:GetDB()
  --- Opt-in feature: only render when explicitly enabled.
  if type(db) ~= "table" or db.showMapPins ~= true then
    return
  end
  if not addon:IsDarkmoonActive() then
    return
  end
  local interactables = addon.Data and addon.Data.INTERACTABLES
  if type(interactables) ~= "table" then
    return
  end

  for profession, entry in pairs(interactables) do
    if type(entry) == "table" and type(entry.locations) == "table" then
      local quest = professionOnQuest(profession)
      if quest then
        addLocationPins(entry, quest)
      end
    end
  end
end

--- Debounced refresh (QUEST_LOG_UPDATE and bag/merchant spam can fire rapidly).
function MapPins:ScheduleRefresh(delay)
  if refreshTimer then
    refreshTimer:Cancel()
    refreshTimer = nil
  end
  refreshTimer = C_Timer.NewTimer(delay or 0.3, function()
    refreshTimer = nil
    MapPins:Refresh()
  end)
end

function MapPins:Init()
  if self._inited then
    return
  end
  HBDP = LibStub and LibStub("HereBeDragons-Pins-2.0", true)
  if not HBDP then
    log("HereBeDragons-Pins-2.0 unavailable; map pins disabled.")
    return
  end
  self._inited = true

  local f = CreateFrame("Frame")
  f:RegisterEvent("PLAYER_ENTERING_WORLD")
  f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
  f:RegisterEvent("QUEST_ACCEPTED")
  f:RegisterEvent("QUEST_TURNED_IN")
  f:RegisterEvent("QUEST_REMOVED")
  f:SetScript("OnEvent", function()
    MapPins:ScheduleRefresh(0.3)
  end)

  self:ScheduleRefresh(0.5)
end
