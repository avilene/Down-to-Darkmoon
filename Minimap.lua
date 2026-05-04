local addonName, addon = ...

local MinimapMod = {}
addon.Minimap = MinimapMod

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
    return
  end

  local broker = ldb:NewDataObject("DownToDarkmoonLDB", {
    type = "data source",
    label = "Down to Darkmoon",
    text = "Down to Darkmoon",
    tocname = "DownToDarkmoon",
    icon = "Interface\\Icons\\INV_Misc_Ticket_Tarot_Elemental_01",
    OnClick = function(_, btn)
      if btn == "RightButton" then
        return
      end
      addon:TogglePanel()
    end,
    OnTooltipShow = function(tooltip)
      if addon:IsDarkmoonActive() then
        tooltip:AddLine("Down to Darkmoon", 1, 1, 1)
        tooltip:AddLine("Click to toggle the addon.", 0.75, 0.85, 1, true)
      else
        tooltip:AddLine("Darkmoon Not Active", 1, 0.35, 0.35)
      end
    end,
  })

  iconLib:Register("DownToDarkmoon", broker, DownToDarkmoonDB.minimap)

  self._registered = true
  self.iconLib = iconLib
end
