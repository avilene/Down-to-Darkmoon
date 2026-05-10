local addonName, addon = ...
local L = addon.L

local MinimapMod = {}
addon.Minimap = MinimapMod

local function showMinimapContextMenu(anchorFrame)
  local function runUpdate()
    addon:InvalidateNextFaireStartCache()
    print("|cfffeaa00Down to Darkmoon:|r " .. L.MSG_NEXT_DATE_UPDATED)
  end

  if MenuUtil and MenuUtil.CreateContextMenu then
    MenuUtil.CreateContextMenu(anchorFrame, function(_, rootDescription)
      rootDescription:CreateButton(L.MINIMAP_UPDATE_NEXT_DATE, function()
        runUpdate()
      end)
    end)
    return
  end

  runUpdate()
end

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
    OnClick = function(anchorFrame, btn)
      if btn == "RightButton" then
        showMinimapContextMenu(anchorFrame)
        return
      end
      addon:TogglePanel()
    end,
    OnTooltipShow = function(tooltip)
      if addon:IsDarkmoonActive() then
        tooltip:AddLine("Down to Darkmoon", 1, 1, 1)
        tooltip:AddLine("Click to toggle the addon.", 0.75, 0.85, 1, true)
        tooltip:AddLine(L.MINIMAP_TOOLTIP_RIGHT_CLICK, 0.55, 0.55, 0.6, true)
        if addon:AreAllDarkmoonProfessionQuestsDoneForCharacter() then
          tooltip:AddLine(" ")
          local when = addon:GetNextDarkmoonFaireStartDateString()
          if when then
            tooltip:AddLine(
              "See you on |cffffffff" .. when .. "|r for the next Faire!",
              0.55,
              1,
              0.65,
              true
            )
          else
            tooltip:AddLine(
              "See you at the next Faire! (Open the calendar once if the date doesn’t show.)",
              0.55,
              1,
              0.65,
              true
            )
          end
        end
      else
        tooltip:AddLine("Darkmoon Not Active", 1, 0.35, 0.35)
        tooltip:AddLine(L.MINIMAP_TOOLTIP_RIGHT_CLICK, 0.55, 0.55, 0.6, true)
      end
    end,
  })

  iconLib:Register("DownToDarkmoon", broker, DownToDarkmoonDB.minimap)

  self._registered = true
  self.iconLib = iconLib
  addon:LogDebug("minimap", "Minimap broker/icon registered.")
end
