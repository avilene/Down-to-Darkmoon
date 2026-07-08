local _, addon = ...

local UI = addon.UI
local L = addon.L
local C = UI.C

local function applyMinimapVisibility()
  local iconLib = LibStub and LibStub("LibDBIcon-1.0", true)
  if not iconLib or not addon.Minimap or not addon.Minimap._registered then
    return
  end
  local db = addon:GetDB()
  if db.minimap and db.minimap.hide then
    iconLib:Hide("DownToDarkmoon")
  else
    iconLib:Show("DownToDarkmoon")
  end
end

local function createCheckbox(parent, label, y, getValue, setValue)
  local cb = CreateFrame("CheckButton", nil, parent, "ChatConfigCheckButtonTemplate")
  cb:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, y)
  cb.Text:SetText(label)
  cb:SetScript("OnClick", function(self)
    setValue(self:GetChecked() and true or false)
  end)
  cb:SetChecked(getValue())
  return cb
end

function UI:OpenSettings()
  if not self.settingsFrame then
    self:CreateSettingsFrame()
  end
  self:RefreshSettingsFrame()
  self.settingsFrame:Show()
end

function UI:RefreshSettingsFrame()
  local f = self.settingsFrame
  if not f then
    return
  end
  local db = addon:GetDB()
  local charDb = addon:GetCharDB()
  f.scaleSlider:SetValue(db.scale or 1)
  f.scaleValue:SetText(("%.2f"):format(db.scale or 1))
  f.showOnLogin:SetChecked(charDb.showOnLogin == true)
  f.hideMinimap:SetChecked(db.minimap and db.minimap.hide == true)
  f.notifyFaireOpen:SetChecked(db.notifyFaireOpen ~= false)
  f.notifyAllDone:SetChecked(db.notifyAllDone ~= false)
  f.showMapPins:SetChecked(db.showMapPins == true)
  f.debug:SetChecked(db.debug == true)
end

function UI:CreateSettingsFrame()
  if self.settingsFrame then
    return
  end

  local f = CreateFrame("Frame", "DownToDarkmoonSettings", UIParent, "BackdropTemplate")
  f:SetSize(340, 310)
  f:SetPoint("CENTER")
  f:SetFrameStrata("DIALOG")
  f:SetMovable(true)
  f:EnableMouse(true)
  f:SetClampedToScreen(true)
  f:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = false,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })
  f:SetBackdropColor(0.08, 0.08, 0.11, 0.95)
  f:SetBackdropBorderColor(0.2, 0.18, 0.14, 0.85)
  f:Hide()

  local titleBar = CreateFrame("Frame", nil, f)
  titleBar:SetHeight(28)
  titleBar:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
  titleBar:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
  titleBar:EnableMouse(true)
  titleBar:RegisterForDrag("LeftButton")
  titleBar:SetScript("OnDragStart", function()
    f:StartMoving()
  end)
  titleBar:SetScript("OnDragStop", function()
    f:StopMovingOrSizing()
  end)

  local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("LEFT", titleBar, "LEFT", 12, 0)
  title:SetTextColor(C.COLOR_TITLE[1], C.COLOR_TITLE[2], C.COLOR_TITLE[3])
  title:SetText(L.SETTINGS_TITLE)

  local closeBtn = CreateFrame("Button", nil, titleBar, "UIPanelCloseButton")
  closeBtn:SetPoint("TOPRIGHT", titleBar, "TOPRIGHT", -2, -2)
  closeBtn:SetScript("OnClick", function()
    f:Hide()
  end)

  local content = CreateFrame("Frame", nil, f)
  content:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 0, -8)
  content:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, 12)

  local scaleLabel = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  scaleLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 12, -4)
  scaleLabel:SetText(L.SETTINGS_SCALE)

  local scaleValue = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  scaleValue:SetPoint("TOPRIGHT", content, "TOPRIGHT", -12, -4)
  scaleValue:SetText("1.00")

  local scaleSlider = CreateFrame("Slider", nil, content, "OptionsSliderTemplate")
  scaleSlider:SetPoint("TOPLEFT", scaleLabel, "BOTTOMLEFT", 0, -8)
  scaleSlider:SetPoint("TOPRIGHT", content, "TOPRIGHT", -12, -24)
  scaleSlider:SetMinMaxValues(0.5, 1.5)
  scaleSlider:SetValueStep(0.05)
  scaleSlider:SetObeyStepOnDrag(true)
  scaleSlider:SetScript("OnValueChanged", function(self, value)
    value = math.max(0.5, math.min(1.5, value))
    addon:GetDB().scale = value
    addon.UI:ApplySavedScale()
    scaleValue:SetText(("%.2f"):format(value))
  end)

  local y = -58
  local showOnLogin = createCheckbox(content, L.SETTINGS_SHOW_ON_LOGIN, y, function()
    return addon:GetCharDB().showOnLogin == true
  end, function(v)
    addon:GetCharDB().showOnLogin = v
  end)

  y = y - 28
  local hideMinimap = createCheckbox(content, L.SETTINGS_HIDE_MINIMAP, y, function()
    local db = addon:GetDB()
    return db.minimap and db.minimap.hide == true
  end, function(v)
    local db = addon:GetDB()
    if type(db.minimap) ~= "table" then
      db.minimap = { hide = false, minimapPos = 225 }
    end
    db.minimap.hide = v
    applyMinimapVisibility()
  end)

  y = y - 28
  local notifyFaireOpen = createCheckbox(content, L.SETTINGS_NOTIFY_FAIRE_OPEN, y, function()
    return addon:GetDB().notifyFaireOpen ~= false
  end, function(v)
    addon:GetDB().notifyFaireOpen = v
  end)

  y = y - 28
  local notifyAllDone = createCheckbox(content, L.SETTINGS_NOTIFY_ALL_DONE, y, function()
    return addon:GetDB().notifyAllDone ~= false
  end, function(v)
    addon:GetDB().notifyAllDone = v
  end)

  y = y - 28
  local showMapPins = createCheckbox(content, L.SETTINGS_SHOW_MAP_PINS, y, function()
    return addon:GetDB().showMapPins == true
  end, function(v)
    addon:GetDB().showMapPins = v
    if addon.MapPins and addon.MapPins.Refresh then
      addon.MapPins:Refresh()
    end
  end)

  y = y - 28
  local debug = createCheckbox(content, L.SETTINGS_DEBUG, y, function()
    return addon:GetDB().debug == true
  end, function(v)
    addon:GetDB().debug = v
  end)

  f.scaleSlider = scaleSlider
  f.scaleValue = scaleValue
  f.showOnLogin = showOnLogin
  f.hideMinimap = hideMinimap
  f.notifyFaireOpen = notifyFaireOpen
  f.notifyAllDone = notifyAllDone
  f.showMapPins = showMapPins
  f.debug = debug
  self.settingsFrame = f
end

addon.UI.ApplyMinimapVisibility = applyMinimapVisibility
