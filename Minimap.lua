local addonName, addon = ...

local MinimapMod = {}
addon.Minimap = MinimapMod

local L = addon.L

function MinimapMod:RefreshTooltip()
  local iconLib = LibStub and LibStub("LibDBIcon-1.0", true)
  if not iconLib then
    return
  end
  local btn = iconLib:GetMinimapButton("DownToDarkmoon")
  if not btn or not GameTooltip:IsShown() or GameTooltip:GetOwner() ~= btn then
    return
  end
  local obj = btn.dataObject
  if obj and obj.OnTooltipShow then
    GameTooltip:ClearLines()
    GameTooltip:SetOwner(btn, "ANCHOR_LEFT")
    obj.OnTooltipShow(GameTooltip)
    GameTooltip:Show()
  end
end

local function addInactiveTooltipLines(tooltip)
  tooltip:AddLine(L.MINIMAP_NOT_ACTIVE, 1, 0.35, 0.35)
  local when = addon:GetNextDarkmoonFaireStartDateString()
  if when then
    tooltip:AddLine(L.MINIMAP_NEXT_FAIRE:format(when), 0.75, 0.85, 1, true)
  else
    tooltip:AddLine(L.MINIMAP_NEXT_FAIRE_UNKNOWN, 0.75, 0.85, 1, true)
  end
  tooltip:AddLine(" ")
  tooltip:AddLine(L.MINIMAP_CLICK_TOGGLE, 0.55, 0.55, 0.55, true)
  tooltip:AddLine(L.MINIMAP_RIGHT_CLICK_SETTINGS, 0.55, 0.55, 0.55, true)
end

function MinimapMod:Init()
  if self._registered then
    return
  end

  local ldb = LibStub and LibStub("LibDataBroker-1.1", true)
  local iconLib = LibStub and LibStub("LibDBIcon-1.0", true)
  if not ldb or not iconLib then
    print("|cfffeaa00Down to Darkmoon:|r LibDataBroker / LibDBIcon failed to load (check embeds.xml).")
    addon:LogDebug("minimap", "LibDataBroker/LibDBIcon missing; minimap icon unavailable.")
    return
  end

  local broker = ldb:NewDataObject("DownToDarkmoonLDB", {
    type = "data source",
    label = "Down to Darkmoon",
    text = "Down to Darkmoon",
    tocname = "DownToDarkmoon",
    icon = "Interface\\Icons\\INV_Misc_Ticket_Tarot_Elemental_01",
    OnClick = function(_, button)
      if button == "RightButton" then
        if addon.UI and addon.UI.OpenSettings then
          addon.UI:OpenSettings()
        end
        return
      end
      addon:TogglePanel()
    end,
    OnTooltipShow = function(tooltip)
      if addon:IsDarkmoonActive() then
        tooltip:AddLine(L.MINIMAP_TITLE, 1, 1, 1)
        tooltip:AddLine(L.MINIMAP_CLICK_TOGGLE, 0.75, 0.85, 1, true)
        tooltip:AddLine(L.MINIMAP_RIGHT_CLICK_SETTINGS, 0.55, 0.55, 0.55, true)
        if addon:AreAllDarkmoonProfessionQuestsDoneForCharacter() then
          tooltip:AddLine(" ")
          local when = addon:GetNextDarkmoonFaireStartDateString()
          if when then
            tooltip:AddLine(L.PANEL_SEE_YOU_ON:format(when), 0.55, 1, 0.65, true)
          else
            tooltip:AddLine(L.PANEL_SEE_YOU_NEXT, 0.55, 1, 0.65, true)
          end
        end
      else
        addInactiveTooltipLines(tooltip)
      end
    end,
  })

  iconLib:Register("DownToDarkmoon", broker, DownToDarkmoonDB.minimap)

  self._registered = true
  self.iconLib = iconLib
  addon:LogDebug("minimap", "Minimap broker/icon registered.")
end
