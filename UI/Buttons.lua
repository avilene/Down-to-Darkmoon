local _, addon = ...

local UI = addon.UI
local C = UI.C

function UI:CreateAddonActionButton(parent, label)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(C.ACTION_BTN_W, C.ACTION_BTN_H)
  b:RegisterForClicks("LeftButtonUp")

  local bg = b:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetTexture("Interface\\Buttons\\WHITE8x8")
  bg:SetVertexColor(0.11, 0.09, 0.12, 0.96)

  local border = CreateFrame("Frame", nil, b, "BackdropTemplate")
  border:SetPoint("TOPLEFT", b, "TOPLEFT", -1, 1)
  border:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 1, -1)
  border:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = false,
    tileSize = 0,
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  border:SetBackdropColor(0, 0, 0, 0)
  border:SetBackdropBorderColor(0.2, 0.18, 0.14, 0.72)

  local fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  fs:SetPoint("CENTER", 0, 0)
  fs:SetText(label)
  fs:SetTextColor(0.94, 0.82, 0.32)

  b:SetScript("OnEnter", function(self)
    bg:SetVertexColor(0.15, 0.12, 0.16, 0.98)
    border:SetBackdropBorderColor(0.8, 0.68, 0.38, 0.9)
    fs:SetTextColor(1, 0.9, 0.42)
    local leftDown = false
    if type(self.IsMouseButtonDown) == "function" then
      leftDown = self:IsMouseButtonDown("LeftButton")
    elseif type(IsMouseButtonDown) == "function" then
      leftDown = IsMouseButtonDown("LeftButton")
    end
    if leftDown then
      fs:SetPoint("CENTER", 1, -1)
    end
  end)
  b:SetScript("OnLeave", function()
    bg:SetVertexColor(0.11, 0.09, 0.12, 0.96)
    border:SetBackdropBorderColor(0.2, 0.18, 0.14, 0.72)
    fs:SetTextColor(0.94, 0.82, 0.32)
    fs:SetPoint("CENTER", 0, 0)
  end)
  b:SetScript("OnMouseDown", function(_, button)
    if button == "LeftButton" then
      bg:SetVertexColor(0.09, 0.07, 0.1, 0.98)
      fs:SetPoint("CENTER", 1, -1)
    end
  end)
  b:SetScript("OnMouseUp", function(_, button)
    if button == "LeftButton" then
      bg:SetVertexColor(0.15, 0.12, 0.16, 0.98)
      fs:SetPoint("CENTER", 0, 0)
    end
  end)
  b:SetScript("OnDisable", function()
    bg:SetVertexColor(0.08, 0.08, 0.1, 0.78)
    border:SetBackdropBorderColor(0.16, 0.16, 0.18, 0.55)
    fs:SetTextColor(0.42, 0.42, 0.46)
    fs:SetPoint("CENTER", 0, 0)
  end)
  b:SetScript("OnEnable", function()
    bg:SetVertexColor(0.11, 0.09, 0.12, 0.96)
    border:SetBackdropBorderColor(0.2, 0.18, 0.14, 0.72)
    fs:SetTextColor(0.94, 0.82, 0.32)
  end)

  b.label = fs
  return b
end
