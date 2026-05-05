local _, addon = ...

local UI = addon.UI
local C = UI.C

local function colorCount(fs, have, need)
  if have >= need then
    fs:SetTextColor(0.45, 1, 0.55)
  else
    fs:SetTextColor(1, 0.82, 0.28)
  end
end

--- Darkmoon Island POI map % (Retail uiMap 408); shown when TomTom is absent so players can place pins manually.
local function appendPoiCoordHint(text, profession)
  if not text or not profession or addon.Navigation:IsTomTomLoaded() then
    return text
  end
  local p = addon.Data.POIS and addon.Data.POIS[profession]
  if not p or type(p.x) ~= "number" or type(p.y) ~= "number" then
    return text
  end
  return text .. (" |cff9d9d9d(%.1f, %.1f)|r"):format(p.x, p.y)
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
    self:TrimPools(0, 0, 0, 0, false)
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
    self.mainFrame:SetHeight(C.TITLE_H + C.GAP_TITLE_TO_BODY + ih + C.FRAME_BOTTOM_PAD)
    if addon.Calendar._hasRefreshedStateOnce then
      addon._inactiveBootFrozen = true
    end
    return
  end

  addon._inactiveBootFrozen = false
  self.inactiveBanner:Hide()
  self.content:Show()

  local y = 0
  local qi, oi, ii, ui = 0, 0, 0, 0
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
      if row.stripe then
        if qi % 2 == 1 then
          row.stripe:SetColorTexture(1, 1, 1, 0.03)
        else
          row.stripe:SetColorTexture(1, 1, 1, 0)
        end
      end
      row.qBtn.qName = q.name
      row.qBtn.dtdQuestId = q.questId
      row.qBtn.dtdProfession = q.profession
      row.qBtn.dtdSkillLineId = q.skillLineId
      addon:SetProfessionIconTexture(row.qBtn.profIcon, q.skillLineId)

      local completed = addon:IsProfessionQuestCompleted(q.questId)
      local ignored = addon:IsProfessionQuestIgnored(q.questId)
      row.qBtn.questCompleted = completed
      row.qBtn.dtdIgnored = ignored
      if row.qBtn.profIcon then
        if ignored then
          row.qBtn.profIcon:SetVertexColor(0.55, 0.55, 0.58)
        else
          row.qBtn.profIcon:SetVertexColor(1, 1, 1)
        end
      end
      if ignored then
        if completed then
          row.qBtn.qtext:SetText(appendPoiCoordHint("|cff888888" .. q.name .. " - completed (ignored)|r", q.profession))
        else
          row.qBtn.qtext:SetText(appendPoiCoordHint("|cff888888" .. q.name .. " (ignored)|r", q.profession))
        end
      elseif completed then
        row.qBtn.qtext:SetText(appendPoiCoordHint("|cff33ff33" .. q.name .. " - completed|r", q.profession))
      elseif C_QuestLog.IsOnQuest(q.questId) then
        row.qBtn.qtext:SetText(appendPoiCoordHint(q.name, q.profession))
      else
        row.qBtn.qtext:SetText(appendPoiCoordHint(q.name .. " |cffff5555(not on quest)|r", q.profession))
      end

      y = y + C.QUEST_ROW_H + C.ROW_GAP

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
          y = y + C.OBJECTIVE_ROW_H + C.ROW_GAP
        end
      end

      if q.useQuestItems and addon:ShouldShowQuestUseItemRows(q.questId, ignored, completed) then
        for _, udef in ipairs(q.useQuestItems) do
          local itemId = udef.itemId
          if itemId then
            local have = addon:GetItemCountCompat(itemId)
            local matches = addon:QuestLogSpecialItemMatchesItemId(q.questId, itemId)
            local bagName, bagIcon = addon:GetBagSlotDisplayForItemId(itemId)
            if have > 0 and matches and bagName then
              ui = ui + 1
              local urow = self:GetQuestUseItemRow(ui)
              urow:ClearAllPoints()
              urow:SetPoint("TOPLEFT", self.content, "TOPLEFT", 10, -y)
              urow:Show()

              local name = addon:GetItemNameByIDCompat(itemId) or ("Item " .. tostring(itemId))
              urow.nameFs:SetText(name)
              addon:SetItemIconTexture(urow.icon, itemId)
              if urow.bg then
                urow.bg.dtdItemId = itemId
                urow.bg.dtdItemName = name
              end
              if urow.iconHit then
                urow.iconHit.dtdItemId = itemId
                urow.iconHit.dtdItemName = name
              end
              urow.cntFs:SetText(("%d in bags"):format(have))
              urow.cntFs:SetTextColor(0.65, 0.85, 1)

              local combat = InCombatLockdown()
              local ub = urow.useBtn
              ub.dtdQuestId = q.questId
              ub.dtdItemId = itemId
              ub:Enable()
              --- Secure item setup: use localized bag item name (same requirement as Blizzard-style secure item buttons).
              ub:SetAttribute("type", nil)
              ub:SetAttribute("item", nil)
              if not combat then
                ub:SetAttribute("type", "item")
                ub:SetAttribute("item", bagName)
              end
              if bagIcon and type(bagIcon) == "number" then
                ub.iconTex:SetTexture(bagIcon)
              else
                addon:SetItemIconTexture(ub.iconTex, itemId)
              end
              ub.iconTex:SetAlpha(1)
              if ub.useLabel then
                ub.useLabel:SetAlpha(0.85)
              end

              y = y + C.ITEM_ROW_H + C.ROW_GAP
            end
          end
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
            if irow.iconHit then
              irow.iconHit.dtdItemId = itemId
              irow.iconHit.dtdItemName = def.name
            end
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
            irow.buy.dtdItemKey = itemKey
            irow.buy.dtdNeed = still

            --- Pooled frames can keep disabled state from earlier paints; always restore clickability.
            irow.bg:Enable()
            irow.pull:Enable()
            irow.buy:Enable()
            if still > 0 then
              irow.pull:Show()
              irow.buy:Show()
            else
              irow.pull:Hide()
              irow.buy:Hide()
            end

            y = y + C.ITEM_ROW_H + C.ROW_GAP
          end
        end
      end

      y = y + C.SECTION_GAP
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
    local allProfessionDone = addon:AreAllDarkmoonProfessionQuestsDoneForCharacter()
    if allProfessionDone and self.allDoneBanner then
      self.allDoneBanner:ClearAllPoints()
      self.allDoneBanner:SetPoint("TOPLEFT", self.content, "TOPLEFT", 6, -y - C.ALL_DONE_GAP_TOP)
      local when = addon:GetNextDarkmoonFaireStartDateString()
      if when then
        self.allDoneBanner:SetText("See you on |cffffffff" .. when .. "|r for the next Faire!")
      else
        self.allDoneBanner:SetText("See you at the next Faire! (Open the calendar once if the date doesn’t show.)")
      end
      self.allDoneBanner:Show()
      --- Reserve only the measured footer height (fixed 34–36px left a large empty gap).
      local bannerH = math.max(self.allDoneBanner:GetStringHeight(), 1)
      y = y + C.ALL_DONE_GAP_TOP + bannerH + 4
    elseif self.allDoneBanner then
      self.allDoneBanner:Hide()
    end
  end

  self:TrimPools(qi, oi, ii, ui, usedEmpty)
  --- Small inset below last row (was +16 and overstretched the panel).
  local bodyH = math.max(y + 4, 1)
  self.content:SetHeight(bodyH)
  self.mainFrame:SetHeight(C.TITLE_H + C.GAP_TITLE_TO_BODY + bodyH + C.FRAME_BOTTOM_PAD)
end
