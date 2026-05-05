local _, addon = ...

local UI = addon.UI
local C = UI.C

function UI:ApplySavedPosition()
  local f = self.mainFrame
  if not f then
    return
  end
  local db = addon:GetDB()
  f:ClearAllPoints()
  f:SetPoint(db.point or "CENTER", UIParent, db.point or "CENTER", db.x or 0, db.y or 0)
end

--- Clamp saved UI scale (WeeklyKnowledge / Myu-style window scaling).
function UI:ApplySavedScale()
  local f = self.mainFrame
  if not f then
    return
  end
  local db = addon:GetDB()
  local s = db.scale
  if type(s) ~= "number" or s < 0.5 or s > 1.5 then
    s = 1
  end
  f:SetScale(s)
end

function UI:SavePosition()
  local f = self.mainFrame
  if not f then
    return
  end
  local db = addon:GetDB()
  local point, _, _, x, y = f:GetPoint(1)
  db.point = point
  db.x = x
  db.y = y
end

function UI:CreateMainFrame()
  if self.mainFrame then
    return
  end

  --- Root panel (WeeklyKnowledge-style: flat fill + separate tooltip border frame).
  local f = CreateFrame("Frame", "DownToDarkmoonPanel", UIParent)
  f:SetWidth(C.WIDTH)
  f:SetHeight(96)
  f:SetFrameStrata("MEDIUM")
  f:SetFrameLevel(100)
  f:SetClampedToScreen(true)

  local fill = f:CreateTexture(nil, "BACKGROUND")
  fill:SetAllPoints()
  fill:SetTexture("Interface\\Buttons\\WHITE8x8")
  fill:SetVertexColor(0.08, 0.08, 0.11, 0.78)

  local border = CreateFrame("Frame", nil, f, "BackdropTemplate")
  border:SetFrameLevel(f:GetFrameLevel() - 1)
  border:SetPoint("TOPLEFT", f, "TOPLEFT", -3, 3)
  border:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 3, -3)
  border:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = false,
    tileSize = 0,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })
  border:SetBackdropColor(0, 0, 0, 0)
  border:SetBackdropBorderColor(0.2, 0.18, 0.14, 0.72)

  f:SetMovable(true)
  f:EnableMouse(true)
  f:SetScript("OnHide", function()
    DownToDarkmoonDB.hidden = true
  end)

  local titleBar = CreateFrame("Frame", nil, f)
  titleBar:SetHeight(C.TITLE_H)
  titleBar:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
  titleBar:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
  titleBar:EnableMouse(true)
  titleBar:RegisterForDrag("LeftButton")
  titleBar:SetScript("OnDragStart", function()
    f:StartMoving()
  end)
  titleBar:SetScript("OnDragStop", function()
    f:StopMovingOrSizing()
    self:SavePosition()
  end)

  local titleBarBg = titleBar:CreateTexture(nil, "BACKGROUND")
  titleBarBg:SetAllPoints()
  titleBarBg:SetTexture("Interface\\Buttons\\WHITE8x8")
  titleBarBg:SetVertexColor(0, 0, 0, 0.52)

  local titleIcon = titleBar:CreateTexture(nil, "ARTWORK")
  titleIcon:SetSize(20, 20)
  titleIcon:SetPoint("LEFT", titleBar, "LEFT", 8, 0)
  titleIcon:SetTexture("Interface\\Icons\\INV_Misc_Ticket_Tarot_Elemental_01")
  titleIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

  local title = titleBar:CreateFontString(nil, "OVERLAY", "SystemFont_Med2")
  title:SetPoint("LEFT", titleIcon, "RIGHT", 8, 0)
  title:SetPoint("RIGHT", titleBar, "RIGHT", -40, 0)
  title:SetJustifyH("LEFT")
  title:SetTextColor(C.COLOR_TITLE[1], C.COLOR_TITLE[2], C.COLOR_TITLE[3])
  title:SetText("Down to Darkmoon")

  --- Lowercase “x” only — ASCII, no OUTLINE flag (outline + large size stretched the glyph vertically).
  local closeBtn = CreateFrame("Button", nil, titleBar)
  closeBtn:SetFrameLevel(220)
  closeBtn:SetSize(26, 26)
  closeBtn:SetPoint("RIGHT", titleBar, "RIGHT", -2, 0)
  local closeBtnBg = closeBtn:CreateTexture(nil, "BACKGROUND")
  closeBtnBg:SetAllPoints()
  closeBtnBg:SetTexture("Interface\\Buttons\\WHITE8x8")
  closeBtnBg:SetVertexColor(1, 1, 1, 0)
  local closeLbl = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  closeLbl:SetPoint("CENTER", 0, 0)
  local fp, fh = closeLbl:GetFont()
  closeLbl:SetFont(fp or "Fonts\\FRIZQT__.TTF", math.max((fh or 11) + 8, 18), "")
  closeLbl:SetText("x")
  closeLbl:SetTextColor(0.88, 0.88, 0.92)
  closeBtn:SetScript("OnClick", function()
    f:Hide()
    DownToDarkmoonDB.hidden = true
  end)
  closeBtn:SetScript("OnEnter", function()
    closeBtnBg:SetVertexColor(1, 1, 1, 0.14)
    closeLbl:SetTextColor(1, 1, 1)
  end)
  closeBtn:SetScript("OnLeave", function()
    closeBtnBg:SetVertexColor(1, 1, 1, 0)
    closeLbl:SetTextColor(0.88, 0.88, 0.92)
  end)

  local inactiveBanner = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  inactiveBanner:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", C.PAD, -C.GAP_TITLE_TO_BODY)
  inactiveBanner:SetPoint("TOPRIGHT", titleBar, "BOTTOMRIGHT", -C.PAD, -C.GAP_TITLE_TO_BODY)
  inactiveBanner:SetJustifyH("CENTER")
  inactiveBanner:SetWordWrap(true)
  inactiveBanner:SetTextColor(1, 0.42, 0.42)
  inactiveBanner:Hide()

  local content = CreateFrame("Frame", nil, f)
  content:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", C.PAD, -C.GAP_TITLE_TO_BODY)
  content:SetPoint("TOPRIGHT", titleBar, "BOTTOMRIGHT", -C.PAD, -C.GAP_TITLE_TO_BODY)
  content:SetHeight(32)

  self.mainFrame = f
  self.inactiveBanner = inactiveBanner
  self.content = content
  self.poolQuest = {}
  self.poolObjective = {}
  self.poolItem = {}
  self.poolQuestUseItem = {}
  self.poolEmpty = nil

  local allDoneBanner = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  allDoneBanner:SetWidth(C.CONTENT_W - 12)
  allDoneBanner:SetJustifyH("CENTER")
  allDoneBanner:SetJustifyV("TOP")
  allDoneBanner:SetTextColor(0.55, 1, 0.65)
  allDoneBanner:SetWordWrap(true)
  allDoneBanner:Hide()
  self.allDoneBanner = allDoneBanner

  self:ApplySavedPosition()
  self:ApplySavedScale()
end
