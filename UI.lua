local addonName, addon = ...

local UI = {}
addon.UI = UI

local QUEST_ROW_H = 22
local OBJECTIVE_ROW_H = 15
local ITEM_ROW_H = 24
local ROW_GAP = 1
local SECTION_GAP = 4
local PAD = 6
local TITLE_H = 26
local WIDTH = 300
local GAP_TITLE_TO_BODY = 10
local FRAME_BOTTOM_PAD = 8
--- Body width inside horizontal padding (no scrollbar column).
local CONTENT_W = WIDTH - 2 * PAD

local COLOR_TITLE = { 1, 0.85, 0.35 }
local COLOR_ITEM_NAME = { 0.92, 0.92, 0.96 }

--- Standard Blizzard panel buttons (Pull / Buy); width fits both beside each item row.
local ACTION_BTN_W = 54
local ACTION_BTN_H = 20
local ACTION_BTN_GAP = 4
--- Right margin + Buy + gap + Pull (matches anchors below).
local ITEM_ACTION_BAR_OFFSET = 2 + ACTION_BTN_W + ACTION_BTN_GAP + ACTION_BTN_W

local function colorCount(fs, have, need)
  if have >= need then
    fs:SetTextColor(0.45, 1, 0.55)
  else
    fs:SetTextColor(1, 0.82, 0.28)
  end
end

function UI:ApplySavedPosition()
  local f = self.mainFrame
  if not f then
    return
  end
  local db = addon:GetDB()
  f:ClearAllPoints()
  f:SetPoint(db.point or "CENTER", UIParent, db.point or "CENTER", db.x or 0, db.y or 0)
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

  local f = CreateFrame("Frame", "DownToDarkmoonPanel", UIParent, "BackdropTemplate")
  f:SetWidth(WIDTH)
  f:SetHeight(96)
  f:SetFrameStrata("MEDIUM")
  f:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    tile = false,
    tileSize = 0,
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
  })
  --- Slight panel tint so title, quest lines, and item rows read clearly over the world.
  f:SetBackdropColor(0.06, 0.06, 0.09, 0.62)
  f:SetBackdropBorderColor(0.42, 0.36, 0.22, 0.5)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(s)
    s:StartMoving()
  end)
  f:SetScript("OnDragStop", function(s)
    s:StopMovingOrSizing()
    self:SavePosition()
  end)
  f:SetScript("OnHide", function()
    DownToDarkmoonDB.hidden = true
  end)

  local titleBar = CreateFrame("Frame", nil, f)
  titleBar:SetHeight(TITLE_H)
  titleBar:SetPoint("TOPLEFT", PAD, -PAD)
  titleBar:SetPoint("TOPRIGHT", -PAD, -PAD)

  local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
  title:SetPoint("LEFT", 2, 0)
  title:SetTextColor(COLOR_TITLE[1], COLOR_TITLE[2], COLOR_TITLE[3])
  title:SetText("Down to Darkmoon")

  local closeBtn = CreateFrame("Button", nil, titleBar, "UIPanelCloseButton")
  closeBtn:SetPoint("RIGHT", 2, 0)
  closeBtn:SetScript("OnClick", function()
    f:Hide()
    DownToDarkmoonDB.hidden = true
  end)

  local inactiveBanner = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  inactiveBanner:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", PAD, -GAP_TITLE_TO_BODY)
  inactiveBanner:SetPoint("TOPRIGHT", titleBar, "BOTTOMRIGHT", -PAD, -GAP_TITLE_TO_BODY)
  inactiveBanner:SetJustifyH("CENTER")
  inactiveBanner:SetWordWrap(true)
  inactiveBanner:SetTextColor(1, 0.42, 0.42)
  inactiveBanner:Hide()

  local content = CreateFrame("Frame", nil, f)
  content:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 0, -GAP_TITLE_TO_BODY)
  content:SetPoint("TOPRIGHT", titleBar, "BOTTOMRIGHT", 0, -GAP_TITLE_TO_BODY)
  content:SetHeight(32)

  self.mainFrame = f
  self.inactiveBanner = inactiveBanner
  self.content = content
  self.poolQuest = {}
  self.poolObjective = {}
  self.poolItem = {}
  self.poolEmpty = nil

  local allDoneBanner = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  allDoneBanner:SetWidth(CONTENT_W - 12)
  allDoneBanner:SetJustifyH("CENTER")
  allDoneBanner:SetJustifyV("TOP")
  allDoneBanner:SetTextColor(0.55, 1, 0.65)
  allDoneBanner:SetWordWrap(true)
  allDoneBanner:Hide()
  self.allDoneBanner = allDoneBanner

  self:ApplySavedPosition()
end

function UI:GetQuestRow(i)
  local row = self.poolQuest[i]
  if not row then
    row = CreateFrame("Frame", nil, self.content)
    row:SetSize(CONTENT_W, QUEST_ROW_H)

    local qBtn = CreateFrame("Button", nil, row)
    qBtn:SetAllPoints(row)
    qBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    local hilite = qBtn:CreateTexture(nil, "HIGHLIGHT")
    hilite:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    hilite:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
    hilite:SetColorTexture(1, 1, 1, 0.05)
    qBtn:SetHighlightTexture(hilite)

    local qtext = qBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    qtext:SetPoint("LEFT", 8, 0)
    qtext:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    qtext:SetJustifyH("LEFT")
    qBtn.qtext = qtext
    qBtn:SetScript("OnClick", function(self, button)
      if button == "RightButton" then
        local qid = self.dtdQuestId
        if qid then
          addon:SetProfessionQuestIgnored(qid, not addon:IsProfessionQuestIgnored(qid))
          addon.UI:Refresh()
        end
        return
      end
      local pid = self.dtdPoiId
      if pid then
        addon.Navigation:SetWaypointPOI(pid)
      end
    end)
    qBtn:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(self.qName or "", 1, 1, 1)
      if self.dtdIgnored then
        GameTooltip:AddLine("Ignored: shopping / Pull / Buy hidden for this quest.", 0.55, 0.55, 0.6)
        GameTooltip:AddLine("Right-click: track again.", 0.65, 0.85, 1)
      elseif self.questCompleted then
        GameTooltip:AddLine("Completed for this Darkmoon Faire.", 0.25, 1, 0.35)
        GameTooltip:AddLine("Right-click: ignore (grey out, hide shopping).", 0.65, 0.85, 1)
      else
        GameTooltip:AddLine("Click: waypoint on Darkmoon Island.", 0.7, 0.9, 1)
        GameTooltip:AddLine("Right-click: ignore (grey out, hide Pull/Buy).", 0.65, 0.85, 1)
      end
      GameTooltip:Show()
    end)
    qBtn:SetScript("OnLeave", GameTooltip_Hide)
    row.qBtn = qBtn
    self.poolQuest[i] = row
  end
  return row
end

function UI:GetObjectiveRow(i)
  local row = self.poolObjective[i]
  if not row then
    row = CreateFrame("Frame", nil, self.content)
    row:SetSize(CONTENT_W - 14, OBJECTIVE_ROW_H)
    local fs = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    fs:SetPoint("LEFT", 22, 0)
    fs:SetPoint("RIGHT", row, "RIGHT", -10, 0)
    fs:SetJustifyH("LEFT")
    row.fs = fs
    self.poolObjective[i] = row
  end
  return row
end

function UI:GetItemRow(i)
  local irow = self.poolItem[i]
  if not irow then
    irow = CreateFrame("Frame", nil, self.content)
    irow:SetSize(CONTENT_W - 10, ITEM_ROW_H)

    local strip = irow:CreateTexture(nil, "BACKGROUND")
    strip:SetAllPoints()
    strip:SetColorTexture(0.08, 0.08, 0.1, 0.55)

    local bg = CreateFrame("Button", nil, irow)
    bg:SetPoint("LEFT", irow, "LEFT", 0, 0)
    bg:SetPoint("RIGHT", irow, "RIGHT", -ITEM_ACTION_BAR_OFFSET, 0)
    bg:SetHeight(ITEM_ROW_H)
    bg:RegisterForClicks("LeftButtonUp")
    irow.bg = bg

    local bgHi = bg:CreateTexture(nil, "HIGHLIGHT")
    bgHi:SetAllPoints()
    bgHi:SetColorTexture(1, 1, 1, 0.04)
    bg:SetHighlightTexture(bgHi)

    local icon = bg:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetPoint("LEFT", 4, 0)
    irow.icon = icon

    local nameFs = bg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    nameFs:SetPoint("LEFT", icon, "RIGHT", 5, 0)
    nameFs:SetPoint("RIGHT", bg, "RIGHT", -56, 0)
    nameFs:SetJustifyH("LEFT")
    nameFs:SetTextColor(COLOR_ITEM_NAME[1], COLOR_ITEM_NAME[2], COLOR_ITEM_NAME[3])
    irow.nameFs = nameFs

    local cntFs = bg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cntFs:SetPoint("RIGHT", bg, "RIGHT", -2, 0)
    cntFs:SetJustifyH("RIGHT")
    irow.cntFs = cntFs

    bg:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(self.dtdItemName or "", 1, 1, 1)
      GameTooltip:AddLine("Click: closest vendor waypoint.", 0.7, 0.9, 1)
      GameTooltip:Show()
    end)
    bg:SetScript("OnLeave", GameTooltip_Hide)

    local buy = CreateFrame("Button", nil, irow, "InsecureActionButtonTemplate, UIPanelButtonTemplate")
    buy:SetSize(ACTION_BTN_W, ACTION_BTN_H)
    buy:SetText("Buy")
    buy:SetPoint("RIGHT", irow, "RIGHT", -2, 0)
    buy:SetFrameLevel(20)
    buy:RegisterForClicks("LeftButtonUp")

    local pull = CreateFrame("Button", nil, irow, "InsecureActionButtonTemplate, UIPanelButtonTemplate")
    pull:SetSize(ACTION_BTN_W, ACTION_BTN_H)
    pull:SetText("Pull")
    pull:SetPoint("RIGHT", buy, "LEFT", -ACTION_BTN_GAP, 0)
    pull:SetFrameLevel(20)
    pull:RegisterForClicks("LeftButtonUp")
    pull:SetScript("OnClick", function(self)
      local itemId = self.dtdItemId
      local need = self.dtdNeed
      if itemId and need and need > 0 then
        addon.QuantityAssist:WithdrawFromBank(itemId, need)
      end
    end)
    pull:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_LEFT")
      GameTooltip:AddLine("Pull from bank", 1, 0.95, 0.7)
      if self:IsEnabled() then
        GameTooltip:AddLine("Click to withdraw up to the amount you still need.", 0.85, 0.85, 0.9, true)
      elseif InCombatLockdown() then
        GameTooltip:AddLine("Unavailable in combat.", 1, 0.35, 0.35, true)
      elseif not addon.QuantityAssist:IsBankInventoryAccessible() then
        GameTooltip:AddLine("Open your bank to withdraw (greyed until then).", 0.75, 0.75, 0.8, true)
      elseif (self.dtdNeed or 0) <= 0 then
        GameTooltip:AddLine("Nothing left to withdraw for this line.", 0.55, 0.55, 0.55, true)
      else
        GameTooltip:AddLine("No stacks of this item in your bank.", 0.9, 0.75, 0.55, true)
      end
      GameTooltip:Show()
    end)
    pull:SetScript("OnLeave", GameTooltip_Hide)
    irow.pull = pull

    buy:SetScript("OnClick", function(self)
      local idxm = self.dtdMerchIdx
      local qty = self.dtdBuyQty
      if idxm and qty and qty > 0 then
        addon.QuantityAssist:BuyFromMerchant(idxm, qty)
      end
    end)
    buy:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_LEFT")
      GameTooltip:AddLine("Buy from vendor", 1, 0.95, 0.7)
      if self:IsEnabled() then
        GameTooltip:AddLine("Click to buy up to what you can afford and still need.", 0.85, 0.85, 0.9, true)
      elseif InCombatLockdown() then
        GameTooltip:AddLine("Unavailable in combat.", 1, 0.35, 0.35, true)
      elseif not addon.QuantityAssist:IsMerchantUIOpen() then
        GameTooltip:AddLine("Open a merchant that sells this item (greyed until then).", 0.75, 0.75, 0.8, true)
      elseif (self.dtdNeed or 0) <= 0 then
        GameTooltip:AddLine("Nothing left to buy for this line.", 0.55, 0.55, 0.55, true)
      elseif (self.dtdBuyQty or 0) <= 0 and (self.dtdMerchIdx or 0) > 0 then
        GameTooltip:AddLine("Cannot buy any right now (stock or not enough money).", 0.9, 0.65, 0.45, true)
      else
        GameTooltip:AddLine("This merchant does not sell this item (try another vendor / waypoint).", 0.9, 0.75, 0.55, true)
      end
      GameTooltip:Show()
    end)
    buy:SetScript("OnLeave", GameTooltip_Hide)
    irow.buy = buy

    self.poolItem[i] = irow
  end
  return irow
end

function UI:GetEmptyRow()
  if not self.poolEmpty then
    self.poolEmpty = CreateFrame("Frame", nil, self.content)
    self.poolEmpty:SetSize(CONTENT_W, 44)
    self.poolEmpty.fs = self.poolEmpty:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    self.poolEmpty.fs:SetPoint("LEFT", 8, 0)
    self.poolEmpty.fs:SetWidth(WIDTH - 60)
    self.poolEmpty.fs:SetJustifyH("LEFT")
  end
  return self.poolEmpty
end

function UI:TrimPools(nQuest, nObjective, nItem, usedEmpty)
  for i = nQuest + 1, #self.poolQuest do
    self.poolQuest[i]:Hide()
  end
  for i = nObjective + 1, #self.poolObjective do
    self.poolObjective[i]:Hide()
  end
  for i = nItem + 1, #self.poolItem do
    self.poolItem[i]:Hide()
  end
  if self.poolEmpty then
    self.poolEmpty:SetShown(usedEmpty)
  end
end

function UI:Refresh()
  if not self.mainFrame or not self.mainFrame:IsShown() then
    return
  end

  if not addon:IsDarkmoonActive() then
    --- After calendar has decided "inactive" once, skip repeated full paints from bag/merchant spam on boot.
    if addon.Calendar._hasRefreshedStateOnce and addon._inactiveBootFrozen then
      return
    end
    self:TrimPools(0, 0, 0, false)
    if self.poolEmpty then
      self.poolEmpty:Hide()
    end
    if self.allDoneBanner then
      self.allDoneBanner:Hide()
    end
    self.content:Hide()
    local when = addon:GetNextDarkmoonFaireStartDateString()
    if when then
      self.inactiveBanner:SetText("See you on |cffffffff" .. when .. "|r for the next Faire!")
    else
      self.inactiveBanner:SetText("See you at the next Faire! (Open the calendar once if the date doesn’t show.)")
    end
    self.inactiveBanner:Show()
    local ih = math.max(self.inactiveBanner:GetStringHeight(), 1)
    self.mainFrame:SetHeight(PAD + TITLE_H + GAP_TITLE_TO_BODY + ih + FRAME_BOTTOM_PAD)
    if addon.Calendar._hasRefreshedStateOnce then
      addon._inactiveBootFrozen = true
    end
    return
  end

  addon._inactiveBootFrozen = false
  self.inactiveBanner:Hide()
  self.content:Show()

  local y = 0
  local qi, oi, ii = 0, 0, 0
  local skill = addon:PlayerSkillLineSet()
  local any = false

  for _, q in ipairs(addon.Data.QUESTS) do
    if skill[q.skillLineId] then
      any = true
      qi = qi + 1
      local row = self:GetQuestRow(qi)
      row:ClearAllPoints()
      row:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, -y)
      row:Show()
      row.qBtn.qName = q.name
      row.qBtn.poiId = q.poiId
      row.qBtn.dtdQuestId = q.questId
      row.qBtn.dtdPoiId = q.poiId

      local completed = addon:IsProfessionQuestCompleted(q.questId)
      local ignored = addon:IsProfessionQuestIgnored(q.questId)
      row.qBtn.questCompleted = completed
      row.qBtn.dtdIgnored = ignored
      if ignored then
        if completed then
          row.qBtn.qtext:SetText("|cff888888" .. q.name .. " - completed (ignored)|r")
        else
          row.qBtn.qtext:SetText("|cff888888" .. q.name .. " (ignored)|r")
        end
      elseif completed then
        row.qBtn.qtext:SetText("|cff33ff33" .. q.name .. " - completed|r")
      elseif C_QuestLog.IsOnQuest(q.questId) then
        row.qBtn.qtext:SetText(q.name)
      else
        row.qBtn.qtext:SetText(q.name .. " |cffff5555(not on quest)|r")
      end

      y = y + QUEST_ROW_H + ROW_GAP

      if not completed then
        for _, entry in ipairs(addon:GetQuestObjectiveEntries(q.questId)) do
          oi = oi + 1
          local orow = self:GetObjectiveRow(oi)
          orow:ClearAllPoints()
          orow:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, -y)
          orow.fs:SetText(entry.text)
          if ignored then
            orow.fs:SetTextColor(0.42, 0.42, 0.45)
          elseif entry.finished then
            orow.fs:SetTextColor(0.45, 1, 0.55)
          else
            orow.fs:SetTextColor(1, 0.82, 0.28)
          end
          orow:Show()
          y = y + OBJECTIVE_ROW_H + ROW_GAP
        end
      end

      for _, stack in ipairs(q.requiredStacks) do
        if not completed then
          local def = addon.Data.ITEMS[stack.itemKey]
          if def and addon:ShouldShowShoppingIngredientRow(q.questId, def.itemId, stack.count) then
            ii = ii + 1
            local irow = self:GetItemRow(ii)
            irow:ClearAllPoints()
            irow:SetPoint("TOPLEFT", self.content, "TOPLEFT", 10, -y)
            irow:Show()

            local itemKey = stack.itemKey
            local itemId = def.itemId
            local need = stack.count
            local have = addon:GetItemCountCompat(itemId)
            local still = addon.QuantityAssist:GetStillNeed(itemId, need)

            irow.nameFs:SetText(def.name)
            addon:SetItemIconTexture(irow.icon, itemId)
            irow.cntFs:SetText(("%d/%d"):format(math.min(have, need), need))
            colorCount(irow.cntFs, have, need)

            irow.bg.dtdItemName = def.name
            irow.bg:SetScript("OnClick", function()
              addon.Navigation:SetWaypointForItem(itemKey)
            end)

            irow.pull.dtdItemId = itemId
            irow.pull.dtdNeed = still
            local midx = addon.QuantityAssist:FindMerchantIndex(itemId)
            irow.buy.dtdMerchIdx = midx
            irow.buy.dtdBuyQty = midx and addon.QuantityAssist:GetAffordableBuyQty(midx, still) or 0

            local bankOpen = addon.QuantityAssist:IsBankInventoryAccessible()
            local merchOpen = addon.QuantityAssist:IsMerchantUIOpen()
            local hasBankStacks = bankOpen and #addon.QuantityAssist:ScanBankForItem(itemId) > 0
            local combat = InCombatLockdown()

            if still > 0 then
              irow.pull:Show()
              irow.buy:Show()
              local canPull = bankOpen and hasBankStacks and still > 0 and not combat
              local buyQty = irow.buy.dtdBuyQty or 0
              local canBuy = merchOpen and still > 0 and midx ~= nil and buyQty > 0 and not combat
              irow.pull:SetEnabled(canPull)
              irow.buy:SetEnabled(canBuy)
            else
              irow.pull:Hide()
              irow.buy:Hide()
            end

            y = y + ITEM_ROW_H + ROW_GAP
          end
        end
      end

      y = y + SECTION_GAP
    end
  end

  local usedEmpty = false
  if not any then
    usedEmpty = true
    local er = self:GetEmptyRow()
    er:ClearAllPoints()
    er:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, -4)
    er.fs:SetText("No Darkmoon profession quests to show. Train a profession or use a character with one.")
    er:Show()
    y = 48
    if self.allDoneBanner then
      self.allDoneBanner:Hide()
    end
  else
    local allProfessionDone = true
    for _, q in ipairs(addon.Data.QUESTS) do
      if
        skill[q.skillLineId]
        and not addon:IsProfessionQuestCompleted(q.questId)
        and not addon:IsProfessionQuestIgnored(q.questId)
      then
        allProfessionDone = false
        break
      end
    end
    if allProfessionDone and self.allDoneBanner then
      self.allDoneBanner:ClearAllPoints()
      self.allDoneBanner:SetPoint("TOPLEFT", self.content, "TOPLEFT", 6, -y - 2)
      local when = addon:GetNextDarkmoonFaireStartDateString()
      if when then
        self.allDoneBanner:SetText("See you on |cffffffff" .. when .. "|r for the next Faire!")
      else
        self.allDoneBanner:SetText("See you at the next Faire! (Open the calendar once if the date doesn’t show.)")
      end
      self.allDoneBanner:Show()
      y = y + (when and 36 or 34)
    elseif self.allDoneBanner then
      self.allDoneBanner:Hide()
    end
  end

  self:TrimPools(qi, oi, ii, usedEmpty)
  local bodyH = math.max(y + 16, 1)
  self.content:SetHeight(bodyH)
  self.mainFrame:SetHeight(PAD + TITLE_H + GAP_TITLE_TO_BODY + bodyH + FRAME_BOTTOM_PAD)
end
