local _, addon = ...

local UI = addon.UI
local C = UI.C

local function CreateAddonActionButton(parent, label)
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
    if self:IsMouseButtonDown("LeftButton") then
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

local function UseFirstBagItemById(itemId)
  if not itemId or InCombatLockdown() then
    return false
  end
  if not C_Container or type(C_Container.GetContainerNumSlots) ~= "function" or type(C_Container.GetContainerItemInfo) ~= "function" then
    return false
  end
  local maxBag = type(NUM_BAG_SLOTS) == "number" and NUM_BAG_SLOTS or 4
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
        GameTooltip:AddLine("Ignored on this character: shopping / Pull / Buy hidden.", 0.55, 0.55, 0.6)
        GameTooltip:AddLine("Right-click: track again.", 0.65, 0.85, 1)
      elseif self.questCompleted then
        GameTooltip:AddLine("Completed for this Darkmoon Faire.", 0.25, 1, 0.35)
        GameTooltip:AddLine("Right-click: ignore for this character (grey out, hide shopping).", 0.65, 0.85, 1)
      else
        if addon.Navigation:IsTomTomLoaded() then
          GameTooltip:AddLine("Click: waypoint on Darkmoon Island.", 0.7, 0.9, 1)
        else
          local prof = self.dtdProfession
          local p = prof and addon.Data.POIS and addon.Data.POIS[prof]
          if p and type(p.x) == "number" and type(p.y) == "number" then
            GameTooltip:AddLine(
              ("Darkmoon map pin: |cffffffff%.1f, %.1f|r (install TomTom for arrows)."):format(
                p.x,
                p.y
              ),
              0.7,
              0.9,
              1,
              true
            )
          else
            GameTooltip:AddLine("Install TomTom for in-game waypoints, or use the map % on the quest line.", 0.7, 0.9, 1,
              true)
          end
        end
        GameTooltip:AddLine("Right-click: ignore quest on this character.", 0.65, 0.85, 1)
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
      GameTooltip:AddLine("Click: closest vendor waypoint.", 0.7, 0.9, 1)
      GameTooltip:Show()
    end)
    bg:SetScript("OnLeave", GameTooltip_Hide)

    local buy = CreateAddonActionButton(irow, "Buy")
    buy:SetPoint("RIGHT", irow, "RIGHT", -2, 0)
    buy:SetFrameLevel(irow:GetFrameLevel() + 20)

    local pull = CreateAddonActionButton(irow, "Pull")
    pull:SetPoint("RIGHT", buy, "LEFT", -C.ACTION_BTN_GAP, 0)
    pull:SetFrameLevel(irow:GetFrameLevel() + 20)
    pull:SetScript("OnClick", function(self)
      if InCombatLockdown() then
        print("|cfffeaa00Down to Darkmoon:|r Cannot pull from the bank in combat.")
        return
      end
      if not addon.QuantityAssist:IsBankInventoryAccessible() then
        print("|cfffeaa00Down to Darkmoon:|r Open your bank to pull materials.")
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
      GameTooltip:AddLine("Pull from bank", 1, 0.95, 0.7)
      if InCombatLockdown() then
        GameTooltip:AddLine("Unavailable in combat.", 1, 0.35, 0.35, true)
      elseif not addon.QuantityAssist:IsBankInventoryAccessible() then
        GameTooltip:AddLine("Open your bank, then click to withdraw what you still need.", 0.75, 0.75, 0.8, true)
      elseif (self.dtdNeed or 0) <= 0 then
        GameTooltip:AddLine("Nothing left to withdraw for this line.", 0.55, 0.55, 0.55, true)
      else
        GameTooltip:AddLine("Click to withdraw up to the amount you still need.", 0.85, 0.85, 0.9, true)
        GameTooltip:AddLine("If nothing moves, you have no stacks of this item in the bank.", 0.9, 0.75, 0.55, true)
      end
      GameTooltip:Show()
    end)
    pull:HookScript("OnLeave", GameTooltip_Hide)
    irow.pull = pull

    buy:SetScript("OnClick", function(self)
      if InCombatLockdown() then
        print("|cfffeaa00Down to Darkmoon:|r Cannot buy in combat.")
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
        print("|cfffeaa00Down to Darkmoon:|r Cannot buy any right now (not enough coin or vendor stock).")
      elseif itemKey then
        addon.Navigation:SetWaypointForItem(itemKey)
      end
    end)
    buy:HookScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_LEFT")
      GameTooltip:AddLine("Buy from vendor", 1, 0.95, 0.7)
      if InCombatLockdown() then
        GameTooltip:AddLine("Unavailable in combat.", 1, 0.35, 0.35, true)
      elseif not addon.QuantityAssist:IsMerchantUIOpen() then
        GameTooltip:AddLine("Click to set a waypoint to a vendor that sells this item.", 0.85, 0.85, 0.9, true)
        GameTooltip:AddLine("When a vendor window is open, click buys what you can afford.", 0.75, 0.75, 0.8, true)
      elseif (self.dtdNeed or 0) <= 0 then
        GameTooltip:AddLine("Nothing left to buy for this line.", 0.55, 0.55, 0.55, true)
      elseif (self.dtdBuyQty or 0) <= 0 and (self.dtdMerchIdx or 0) > 0 then
        GameTooltip:AddLine("Cannot buy any right now (not enough coin or vendor stock).", 0.9, 0.65, 0.45, true)
      elseif (self.dtdMerchIdx or 0) <= 0 then
        GameTooltip:AddLine("This merchant does not sell this item — click to route to a vendor that does.", 0.9, 0.75,
          0.55, true)
      else
        GameTooltip:AddLine("Click to buy up to what you can afford and still need.", 0.85, 0.85, 0.9, true)
      end
      GameTooltip:Show()
    end)
    buy:HookScript("OnLeave", GameTooltip_Hide)
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

    local bg = CreateFrame("Frame", nil, urow)
    bg:SetPoint("LEFT", urow, "LEFT", 0, 0)
    bg:SetPoint("RIGHT", urow, "RIGHT", -C.QUEST_USE_ACTION_OFFSET, 0)
    bg:SetHeight(C.ITEM_ROW_H)
    bg:SetFrameLevel(10)
    urow.bg = bg

    local rowTint = bg:CreateTexture(nil, "BACKGROUND")
    rowTint:SetAllPoints()
    rowTint:SetColorTexture(0.07, 0.09, 0.12, 0.45)

    local icon = bg:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetPoint("LEFT", 4, 0)
    urow.icon = icon

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

    local useBtn = CreateFrame("Button", nil, urow)
    useBtn:SetSize(C.QUEST_USE_BTN_SIZE, C.QUEST_USE_BTN_SIZE)
    useBtn:SetPoint("RIGHT", urow, "RIGHT", -2, 0)
    useBtn:SetFrameLevel(20)
    useBtn:RegisterForClicks("LeftButtonUp")

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
    ubLab:SetText("Use")
    ubLab:SetAlpha(0.85)
    useBtn.useLabel = ubLab

    useBtn:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_LEFT")
      GameTooltip:AddLine("Use quest item", 1, 0.95, 0.7)
      if InCombatLockdown() then
        GameTooltip:AddLine("Unavailable in combat (try again out of combat).", 1, 0.35, 0.35, true)
      else
        GameTooltip:AddLine(
          "Uses the item in your bags.",
          0.85,
          0.85,
          0.9,
          true
        )
      end
      GameTooltip:Show()
    end)
    useBtn:SetScript("OnClick", function(self)
      if InCombatLockdown() then
        print("|cfffeaa00Down to Darkmoon:|r Cannot use quest items in combat.")
        return
      end
      local itemId = self.dtdItemId
      if not itemId or not UseFirstBagItemById(itemId) then
        print("|cfffeaa00Down to Darkmoon:|r Could not use that item from your bags.")
      end
    end)
    useBtn:SetScript("OnLeave", GameTooltip_Hide)
    urow.useBtn = useBtn
    useBtn:Raise()

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
