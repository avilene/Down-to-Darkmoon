local _, addon = ...

local UI = addon.UI
local C = UI.C
local L = addon.L

local function colorCount(fs, have, need)
  if have >= need then
    fs:SetTextColor(0.45, 1, 0.55)
  else
    fs:SetTextColor(1, 0.82, 0.28)
  end
end

function UI:UpdateBulkActionButtons()
  if not self.mainFrame or not self.mainFrame:IsShown() then
    return
  end
  if not self.buyAllBtn or not self.pullAllBtn then
    return
  end
  addon.QuantityAssist:UpdateBulkButtonState({ { buy = self.buyAllBtn, pull = self.pullAllBtn } })
end

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

function UI:StopProximityPoll()
  if self.mainFrame then
    self.mainFrame:SetScript("OnUpdate", nil)
  end
  self._proximityNearOk = nil
end

function UI:UpdateProximityPoll()
  if not self.mainFrame or not self.mainFrame:IsShown() then
    return
  end
  local udef = addon:GetActiveRequireNearUseQuestItem()
  if not udef then
    self:StopProximityPoll()
    return
  end
  local nearOk = addon:IsUseQuestItemNearRequirementMet(udef)
  self._proximityNearOk = nearOk
  if self.mainFrame:GetScript("OnUpdate") then
    return
  end
  local elapsedAcc = 0
  self.mainFrame:SetScript("OnUpdate", function(frame, elapsed)
    if not frame:IsShown() then
      addon.UI:StopProximityPoll()
      return
    end
    elapsedAcc = elapsedAcc + elapsed
    if elapsedAcc < 0.5 then
      return
    end
    elapsedAcc = 0
    local active = addon:GetActiveRequireNearUseQuestItem()
    if not active then
      addon.UI:StopProximityPoll()
      return
    end
    local nowNear = addon:IsUseQuestItemNearRequirementMet(active)
    if nowNear ~= addon.UI._proximityNearOk then
      addon.UI._proximityNearOk = nowNear
      if addon.UI.mainFrame and addon.UI.mainFrame:IsShown() then
        addon.UI:Refresh()
      end
    end
  end)
end

--- Full panel paint; no-op when the window is hidden.
function UI:RefreshIfShown()
  if self.mainFrame and self.mainFrame:IsShown() then
    self:Refresh()
  end
end

--- Panel open: paint once, then start proximity polling if needed.
function UI:OnPanelShown()
  self:Refresh()
  self:UpdateProximityPoll()
end

function UI:Refresh()
  if not self.mainFrame or not self.mainFrame:IsShown() then
    return
  end
  self:UpdateBulkActionButtons()

  if not addon:IsDarkmoonActive() then
    --- After schedule has decided “inactive” once, skip repeated full paints from bag/merchant spam on boot.
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
      self.inactiveBanner:SetText(L.PANEL_SEE_YOU_ON:format(when))
    else
      self.inactiveBanner:SetText(L.PANEL_SEE_YOU_NEXT)
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
      local questLabel = addon:GetQuestTitleByIDCompat(q.questId) or q.name
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
      row.qBtn.qName = questLabel
      row.qBtn.dtdQuestId = q.questId
      row.qBtn.dtdProfession = q.profession
      row.qBtn.dtdSkillLineId = q.skillLineId
      addon:SetProfessionIconTexture(row.qBtn.profIcon, q.skillLineId)

      local completed = addon:IsProfessionQuestCompleted(q.questId)
      local ignored = addon:IsProfessionQuestIgnored(q.questId)
      local objectiveCompleted = addon:IsQuestObjectivePhaseComplete(q.questId)
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
          row.qBtn.qtext:SetText(
            appendPoiCoordHint("|cff888888" .. questLabel .. " - " .. L.PANEL_COMPLETED_IGNORED .. "|r", q.profession))
        else
          row.qBtn.qtext:SetText(appendPoiCoordHint("|cff888888" .. questLabel .. " (" .. L.PANEL_IGNORED .. ")|r", q.profession))
        end
      elseif completed then
        row.qBtn.qtext:SetText(appendPoiCoordHint("|cff33ff33" .. questLabel .. " - " .. L.PANEL_COMPLETED .. "|r", q.profession))
      elseif C_QuestLog.IsOnQuest(q.questId) then
        row.qBtn.qtext:SetText(appendPoiCoordHint(questLabel, q.profession))
      else
        row.qBtn.qtext:SetText(
          appendPoiCoordHint(questLabel .. " |cffff5555(" .. L.PANEL_NOT_ON_QUEST .. ")|r", q.profession))
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

      if q.useQuestItems and not objectiveCompleted and addon:ShouldShowQuestUseItemRows(q.questId, ignored, completed) then
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

              local name = addon:GetItemNameByIDCompat(itemId) or L.ITEM_FALLBACK:format(tostring(itemId))
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

              local requireNear = udef.requireNear
              local nearOk = not requireNear or addon:IsUseQuestItemNearRequirementMet(udef)
              local nearUdef = requireNear and udef or nil
              if urow.bg then
                urow.bg.dtdNearOk = nearOk
                urow.bg.dtdRequireNearUdef = nearUdef
              end
              if urow.iconHit then
                urow.iconHit.dtdNearOk = nearOk
                urow.iconHit.dtdRequireNearUdef = nearUdef
              end

              if nearOk then
                urow.cntFs:SetText(L.COUNT_IN_BAGS:format(have))
                urow.cntFs:SetTextColor(0.65, 0.85, 1)
              else
                urow.cntFs:SetText(L.COUNT_NEED_ANVIL)
                urow.cntFs:SetTextColor(1, 0.55, 0.25)
              end

              local combat = InCombatLockdown()
              local ub = urow.useBtn
              ub.dtdQuestId = q.questId
              ub.dtdItemId = itemId
              ub.dtdNearOk = nearOk
              ub.dtdRequireNearUdef = nearUdef
              ub:Enable()
              --- Secure item setup: use localized bag item name (same requirement as Blizzard-style secure item buttons).
              ub:SetAttribute("type", nil)
              ub:SetAttribute("item", nil)
              if not combat and nearOk then
                ub:SetAttribute("type", "item")
                ub:SetAttribute("item", bagName)
              end
              if bagIcon and type(bagIcon) == "number" then
                ub.iconTex:SetTexture(bagIcon)
              else
                addon:SetItemIconTexture(ub.iconTex, itemId)
              end
              if nearOk then
                ub.iconTex:SetAlpha(1)
                if ub.useLabel then
                  ub.useLabel:SetAlpha(0.85)
                end
              else
                ub.iconTex:SetAlpha(0.45)
                if ub.useLabel then
                  ub.useLabel:SetAlpha(0.45)
                end
              end

              y = y + C.ITEM_ROW_H + C.ROW_GAP
            end
          end
        end
      end

      for _, stack in ipairs(q.requiredStacks) do
        if not completed and not objectiveCompleted then
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
            local still = addon:GetShoppingIngredientStillNeed(q.questId, itemId, need)
            local progressShopping = q.shoppingObjectiveItemId or q.shoppingConsumedByQuestItemId
            local displayNeed = progressShopping and (have + still) or need

            local ingredientName = addon:GetItemNameByIDCompat(itemId) or def.name
            irow.nameFs:SetText(ingredientName)
            addon:SetItemIconTexture(irow.icon, itemId)
            if irow.iconHit then
              irow.iconHit.dtdItemId = itemId
              irow.iconHit.dtdItemName = ingredientName
            end
            irow.cntFs:SetText(("%d/%d"):format(math.min(have, displayNeed), displayNeed))
            colorCount(irow.cntFs, have, displayNeed)

            irow.bg.dtdItemName = ingredientName
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

            irow.bg:Enable()
            if still > 0 then
              irow.pull:Show()
              irow.buy:Show()
              if addon.QuantityAssist:CanPullIngredient(still) then
                irow.pull:Enable()
              else
                irow.pull:Disable()
              end
              if addon.QuantityAssist:CanBuyIngredient(itemId, still) then
                irow.buy:Enable()
              else
                irow.buy:Disable()
              end
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
    er.fs:SetText(L.PANEL_NO_QUESTS)
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
        self.allDoneBanner:SetText(L.PANEL_SEE_YOU_ON:format(when))
      else
        self.allDoneBanner:SetText(L.PANEL_SEE_YOU_NEXT)
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
