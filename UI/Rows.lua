local _, addon = ...

local UI = addon.UI
local C = UI.C
local L = addon.L

local function ShowBlizzardItemTooltip(owner, itemId, fallbackName)
  if not owner then
    return
  end
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  if itemId and GameTooltip.SetItemByID then
    local ok = pcall(GameTooltip.SetItemByID, GameTooltip, itemId)
    if ok then
      GameTooltip:Show()
      return
    end
  end
  if itemId and GameTooltip.SetHyperlink then
    local ok = pcall(GameTooltip.SetHyperlink, GameTooltip, ("item:%d"):format(itemId))
    if ok then
      GameTooltip:Show()
      return
    end
  end
  GameTooltip:AddLine(fallbackName or L.ITEM_FALLBACK:format(tostring(itemId or "?")), 1, 1, 1)
  GameTooltip:Show()
end

local function UseFirstBagItemById(itemId)
  if not itemId or InCombatLockdown() then
    return false
  end
  if not C_Container or type(C_Container.GetContainerNumSlots) ~= "function" or type(C_Container.GetContainerItemInfo) ~= "function" then
    return false
  end
  --- Retail may place these items in reagent bag; scan all equipped bag IDs, not just 0-4.
  local maxBag = type(NUM_TOTAL_EQUIPPED_BAG_SLOTS) == "number" and NUM_TOTAL_EQUIPPED_BAG_SLOTS
    or (type(NUM_BAG_SLOTS) == "number" and NUM_BAG_SLOTS or 4)
  for bag = 0, maxBag do
    local slots = C_Container.GetContainerNumSlots(bag)
    if type(slots) == "number" and slots > 0 then
      for slot = 1, slots do
        local info = C_Container.GetContainerItemInfo(bag, slot)
        if info and info.itemID == itemId then
          if type(C_Container.UseContainerItem) == "function" then
            C_Container.UseContainerItem(bag, slot)
          elseif type(UseContainerItem) == "function" then
            UseContainerItem(bag, slot)
          else
            return false
          end
          return true
        end
      end
    end
  end
  return false
end

local function TryUseQuestRowItem(self)
  if InCombatLockdown() then
    print(L.MSG_CANNOT_USE_COMBAT)
    return
  end
  local itemId = self and self.dtdItemId
  if not itemId or not UseFirstBagItemById(itemId) then
    print(L.MSG_CANNOT_USE_BAGS)
  end
end

function UI:GetQuestRow(i)
  local row = self.poolQuest[i]
  if not row then
    row = CreateFrame("Frame", nil, self.content)
    row:SetSize(C.CONTENT_W, C.QUEST_ROW_H)

    local stripe = row:CreateTexture(nil, "BACKGROUND")
    stripe:SetAllPoints()
    stripe:SetColorTexture(1, 1, 1, 0)
    row.stripe = stripe

    local qBtn = CreateFrame("Button", nil, row)
    qBtn:SetAllPoints(row)
    qBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    local hilite = qBtn:CreateTexture(nil, "HIGHLIGHT")
    hilite:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    hilite:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
    hilite:SetColorTexture(1, 1, 1, 0.05)
    qBtn:SetHighlightTexture(hilite)

    local profIcon = qBtn:CreateTexture(nil, "ARTWORK")
    profIcon:SetSize(16, 16)
    profIcon:SetPoint("LEFT", qBtn, "LEFT", 6, 0)
    qBtn.profIcon = profIcon

    local qtext = qBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    qtext:SetPoint("LEFT", profIcon, "RIGHT", 4, 0)
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
      local prof = self.dtdProfession
      if prof then
        addon.Navigation:SetWaypointPOI(prof)
      end
    end)
    qBtn:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(
        addon:FormatTooltipLineWithProfessionIcon(self.dtdSkillLineId, self.qName or ""),
        1,
        1,
        1
      )
      if self.dtdIgnored then
        GameTooltip:AddLine(L.TIP_IGNORED_HIDDEN, 0.55, 0.55, 0.6)
        GameTooltip:AddLine(L.TIP_RIGHT_CLICK_TRACK, 0.65, 0.85, 1)
      elseif self.questCompleted then
        GameTooltip:AddLine(L.TIP_COMPLETED_THIS_FAIRE, 0.25, 1, 0.35)
        GameTooltip:AddLine(L.TIP_RIGHT_CLICK_IGNORE, 0.65, 0.85, 1)
      else
        if addon.Navigation:IsTomTomLoaded() then
          GameTooltip:AddLine(L.TIP_CLICK_WAYPOINT_ISLAND, 0.7, 0.9, 1)
        else
          local prof = self.dtdProfession
          local p = prof and addon.Data.POIS and addon.Data.POIS[prof]
          if p and type(p.x) == "number" and type(p.y) == "number" then
            GameTooltip:AddLine(
              L.TIP_MAP_PIN:format(
                p.x,
                p.y
              ),
              0.7,
              0.9,
              1,
              true
            )
          else
            GameTooltip:AddLine(L.TIP_INSTALL_TOMTOM, 0.7, 0.9, 1,
              true)
          end
        end
        GameTooltip:AddLine(L.TIP_RIGHT_CLICK_IGNORE_QUEST, 0.65, 0.85, 1)
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
    row:SetSize(C.CONTENT_W - 14, C.OBJECTIVE_ROW_H)
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
    irow:SetSize(C.CONTENT_W - 10, C.ITEM_ROW_H)
    local actionW = C.ITEM_ACTION_BAR_OFFSET
    local actionBackdrop = irow:CreateTexture(nil, "BACKGROUND")
    actionBackdrop:SetPoint("TOPRIGHT", irow, "TOPRIGHT", 0, 0)
    actionBackdrop:SetPoint("BOTTOMRIGHT", irow, "BOTTOMRIGHT", 0, 0)
    actionBackdrop:SetWidth(actionW)
    actionBackdrop:SetColorTexture(0.12, 0.12, 0.14, 1)

    local bg = CreateFrame("Button", nil, irow)
    bg:SetPoint("TOPLEFT", irow, "TOPLEFT", 0, 0)
    bg:SetPoint("BOTTOMRIGHT", irow, "BOTTOMRIGHT", -actionW, 0)
    bg:RegisterForClicks("LeftButtonUp")
    bg:SetFrameLevel(irow:GetFrameLevel() + 5)
    irow.bg = bg

    local rowTint = bg:CreateTexture(nil, "BACKGROUND")
    rowTint:SetAllPoints()
    rowTint:SetColorTexture(0.08, 0.08, 0.1, 0.55)

    local bgHi = bg:CreateTexture(nil, "HIGHLIGHT")
    bgHi:SetAllPoints()
    bgHi:SetColorTexture(1, 1, 1, 0.04)
    bg:SetHighlightTexture(bgHi)

    local icon = bg:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetPoint("LEFT", 4, 0)
    irow.icon = icon
    local iconHit = CreateFrame("Button", nil, bg)
    iconHit:SetSize(18, 18)
    iconHit:SetPoint("LEFT", 4, 0)
    iconHit:SetScript("OnEnter", function(self)
      ShowBlizzardItemTooltip(self, self.dtdItemId, self.dtdItemName)
    end)
    iconHit:SetScript("OnLeave", GameTooltip_Hide)
    irow.iconHit = iconHit

    local nameFs = bg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    nameFs:SetPoint("LEFT", icon, "RIGHT", 5, 0)
    nameFs:SetPoint("RIGHT", bg, "RIGHT", -56, 0)
    nameFs:SetJustifyH("LEFT")
    nameFs:SetTextColor(C.COLOR_ITEM_NAME[1], C.COLOR_ITEM_NAME[2], C.COLOR_ITEM_NAME[3])
    irow.nameFs = nameFs

    local cntFs = bg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cntFs:SetPoint("RIGHT", bg, "RIGHT", -2, 0)
    cntFs:SetJustifyH("RIGHT")
    irow.cntFs = cntFs

    bg:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(self.dtdItemName or "", 1, 1, 1)
      GameTooltip:AddLine(L.TIP_VENDOR_WAYPOINT, 0.7, 0.9, 1)
      GameTooltip:Show()
    end)
    bg:SetScript("OnLeave", GameTooltip_Hide)

    local buy = self:CreateAddonActionButton(irow, L.BTN_BUY)
    buy:SetPoint("RIGHT", irow, "RIGHT", -2, 0)
    buy:SetFrameLevel(irow:GetFrameLevel() + 20)
    buy:SetScript("OnClick", function(self)
      if InCombatLockdown() then
        print(L.MSG_CANNOT_BUY_COMBAT)
        return
      end
      local idxm = self.dtdMerchIdx
      local qty = self.dtdBuyQty
      if idxm and qty and qty > 0 then
        addon.QuantityAssist:BuyFromMerchant(idxm, qty)
        return
      end
      local itemKey = self.dtdItemKey
      local merchOpen = addon.QuantityAssist:IsMerchantUIOpen()
      if merchOpen and idxm then
        print(L.MSG_CANNOT_BUY_NOW)
      elseif itemKey then
        addon.Navigation:SetWaypointForItem(itemKey)
      end
    end)
    buy:HookScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_LEFT")
      GameTooltip:AddLine(L.TIP_BUY_HEADER, 1, 0.95, 0.7)
      if InCombatLockdown() then
        GameTooltip:AddLine(L.TIP_UNAVAILABLE_COMBAT, 1, 0.35, 0.35, true)
      elseif not addon.QuantityAssist:IsMerchantUIOpen() then
        GameTooltip:AddLine(L.TIP_BUY_SET_WAYPOINT, 0.85, 0.85, 0.9, true)
        GameTooltip:AddLine(L.TIP_BUY_WHEN_VENDOR_OPEN, 0.75, 0.75, 0.8, true)
      elseif (self.dtdNeed or 0) <= 0 then
        GameTooltip:AddLine(L.TIP_BUY_NOTHING_LEFT, 0.55, 0.55, 0.55, true)
      elseif (self.dtdBuyQty or 0) <= 0 and (self.dtdMerchIdx or 0) > 0 then
        GameTooltip:AddLine(L.TIP_BUY_CANNOT, 0.9, 0.65, 0.45, true)
      elseif (self.dtdMerchIdx or 0) <= 0 then
        GameTooltip:AddLine(L.TIP_BUY_VENDOR_NO_SELL, 0.9, 0.75,
          0.55, true)
      else
        GameTooltip:AddLine(L.TIP_BUY_CAN, 0.85, 0.85, 0.9, true)
      end
      GameTooltip:Show()
    end)
    buy:HookScript("OnLeave", GameTooltip_Hide)

    local pull = self:CreateAddonActionButton(irow, L.BTN_PULL)
    pull:SetPoint("RIGHT", buy, "LEFT", -C.ACTION_BTN_GAP, 0)
    pull:SetFrameLevel(irow:GetFrameLevel() + 20)
    pull:SetScript("OnClick", function(self)
      if InCombatLockdown() then
        print(L.MSG_CANNOT_PULL_COMBAT)
        return
      end
      if not addon.QuantityAssist:IsBankInventoryAccessible() then
        print(L.MSG_OPEN_BANK_PULL)
        return
      end
      local itemId = self.dtdItemId
      local need = self.dtdNeed
      if itemId and need and need > 0 then
        addon.QuantityAssist:WithdrawFromBank(itemId, need)
      end
    end)
    pull:HookScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_LEFT")
      GameTooltip:AddLine(L.TIP_PULL_HEADER, 1, 0.95, 0.7)
      if InCombatLockdown() then
        GameTooltip:AddLine(L.TIP_UNAVAILABLE_COMBAT, 1, 0.35, 0.35, true)
      elseif not addon.QuantityAssist:IsBankInventoryAccessible() then
        GameTooltip:AddLine(L.TIP_PULL_OPEN_BANK, 0.75, 0.75, 0.8, true)
      elseif (self.dtdNeed or 0) <= 0 then
        GameTooltip:AddLine(L.TIP_PULL_NOTHING_LEFT, 0.55, 0.55, 0.55, true)
      else
        GameTooltip:AddLine(L.TIP_PULL_WITHDRAW, 0.85, 0.85, 0.9, true)
        GameTooltip:AddLine(L.TIP_PULL_NONE_IN_BANK, 0.9, 0.75, 0.55, true)
      end
      GameTooltip:Show()
    end)
    pull:HookScript("OnLeave", GameTooltip_Hide)
    irow.pull = pull
    irow.buy = buy

    self.poolItem[i] = irow
  end
  return irow
end

function UI:GetQuestUseItemRow(i)
  local urow = self.poolQuestUseItem[i]
  if not urow then
    urow = CreateFrame("Frame", nil, self.content)
    urow:SetSize(C.CONTENT_W - 10, C.ITEM_ROW_H)

    local actionW = C.QUEST_USE_ACTION_OFFSET
    local actionBackdrop = urow:CreateTexture(nil, "BACKGROUND")
    actionBackdrop:SetPoint("TOPRIGHT", urow, "TOPRIGHT", 0, 0)
    actionBackdrop:SetPoint("BOTTOMRIGHT", urow, "BOTTOMRIGHT", 0, 0)
    actionBackdrop:SetWidth(actionW)
    actionBackdrop:SetColorTexture(0.12, 0.12, 0.14, 1)

    local bg = CreateFrame("Button", nil, urow)
    bg:SetPoint("TOPLEFT", urow, "TOPLEFT", 0, 0)
    bg:SetPoint("BOTTOMRIGHT", urow, "BOTTOMRIGHT", -actionW, 0)
    bg:RegisterForClicks("LeftButtonUp")
    bg:SetFrameLevel(urow:GetFrameLevel() + 5)
    urow.bg = bg

    local rowTint = bg:CreateTexture(nil, "BACKGROUND")
    rowTint:SetAllPoints()
    rowTint:SetColorTexture(0.07, 0.09, 0.12, 0.45)

    local bgHi = bg:CreateTexture(nil, "HIGHLIGHT")
    bgHi:SetAllPoints()
    bgHi:SetColorTexture(1, 1, 1, 0.04)
    bg:SetHighlightTexture(bgHi)

    local icon = bg:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetPoint("LEFT", 4, 0)
    urow.icon = icon
    local iconHit = CreateFrame("Button", nil, bg)
    iconHit:SetSize(18, 18)
    iconHit:SetPoint("LEFT", 4, 0)
    iconHit:RegisterForClicks("LeftButtonUp")
    iconHit:SetScript("OnEnter", function(self)
      ShowBlizzardItemTooltip(self, self.dtdItemId, self.dtdItemName)
    end)
    iconHit:SetScript("OnClick", TryUseQuestRowItem)
    iconHit:SetScript("OnLeave", GameTooltip_Hide)
    urow.iconHit = iconHit

    local nameFs = bg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    nameFs:SetPoint("LEFT", icon, "RIGHT", 5, 0)
    nameFs:SetPoint("RIGHT", bg, "RIGHT", -52, 0)
    nameFs:SetJustifyH("LEFT")
    nameFs:SetTextColor(C.COLOR_ITEM_NAME[1], C.COLOR_ITEM_NAME[2], C.COLOR_ITEM_NAME[3])
    urow.nameFs = nameFs

    local cntFs = bg:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    cntFs:SetPoint("RIGHT", bg, "RIGHT", -2, 0)
    cntFs:SetJustifyH("RIGHT")
    urow.cntFs = cntFs
    bg:SetScript("OnClick", TryUseQuestRowItem)
    bg:SetScript("OnEnter", function(self)
      ShowBlizzardItemTooltip(self, self.dtdItemId, self.dtdItemName)
    end)
    bg:SetScript("OnLeave", GameTooltip_Hide)

    --- Secure item action (Blizzard-compliant): item use must be a secure item button.
    local useBtn = CreateFrame("Button", nil, urow, "InsecureActionButtonTemplate")
    useBtn:SetSize(C.QUEST_USE_BTN_SIZE, C.QUEST_USE_BTN_SIZE)
    useBtn:SetPoint("RIGHT", urow, "RIGHT", -2, 0)
    useBtn:SetFrameLevel(urow:GetFrameLevel() + 20)
    useBtn:RegisterForClicks("AnyDown", "AnyUp")
    useBtn:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_LEFT")
      GameTooltip:AddLine(L.TIP_USE_HEADER, 1, 0.95, 0.7)
      if InCombatLockdown() then
        GameTooltip:AddLine(L.TIP_USE_COMBAT, 1, 0.35, 0.35, true)
      else
        GameTooltip:AddLine(
          L.TIP_USE_BAGS,
          0.85,
          0.85,
          0.9,
          true
        )
      end
      GameTooltip:Show()
    end)
    useBtn:SetScript("OnLeave", GameTooltip_Hide)

    local ubIcon = useBtn:CreateTexture(nil, "ARTWORK")
    ubIcon:SetAllPoints()
    ubIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    useBtn.iconTex = ubIcon

    local ubHi = useBtn:CreateTexture(nil, "HIGHLIGHT")
    ubHi:SetAllPoints()
    ubHi:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    ubHi:SetBlendMode("ADD")

    local ubLab = useBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ubLab:SetPoint("BOTTOM", 0, 1)
    ubLab:SetText(L.BTN_USE)
    ubLab:SetAlpha(0.85)
    useBtn.useLabel = ubLab
    urow.useBtn = useBtn

    self.poolQuestUseItem[i] = urow
  end
  return urow
end

function UI:GetEmptyRow()
  if not self.poolEmpty then
    self.poolEmpty = CreateFrame("Frame", nil, self.content)
    self.poolEmpty:SetSize(C.CONTENT_W, 44)
    self.poolEmpty.fs = self.poolEmpty:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    self.poolEmpty.fs:SetPoint("LEFT", 8, 0)
    self.poolEmpty.fs:SetWidth(C.WIDTH - 60)
    self.poolEmpty.fs:SetJustifyH("LEFT")
  end
  return self.poolEmpty
end

function UI:TrimPools(nQuest, nObjective, nItem, nQuestUse, usedEmpty)
  for i = nQuest + 1, #self.poolQuest do
    self.poolQuest[i]:Hide()
  end
  for i = nObjective + 1, #self.poolObjective do
    self.poolObjective[i]:Hide()
  end
  for i = nItem + 1, #self.poolItem do
    self.poolItem[i]:Hide()
  end
  for i = nQuestUse + 1, #self.poolQuestUseItem do
    self.poolQuestUseItem[i]:Hide()
  end
  if self.poolEmpty then
    self.poolEmpty:SetShown(usedEmpty)
  end
end
