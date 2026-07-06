local _, addon = ...

local UI = addon.UI
local C = UI.C
local L = addon.L

UI.BlizzardHooks = UI.BlizzardHooks or {}
local Hooks = UI.BlizzardHooks

local function attachBuyAllTooltip(btn)
  btn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(L.TIP_BUY_ALL_HEADER, 1, 0.95, 0.7)
    local qa = addon.QuantityAssist
    if InCombatLockdown() then
      GameTooltip:AddLine(L.TIP_BUY_ALL_COMBAT, 1, 0.35, 0.35, true)
    elseif not qa:IsMerchantUIOpen() then
      GameTooltip:AddLine(L.TIP_BUY_ALL_NO_VENDOR, 0.75, 0.75, 0.8, true)
    elseif not qa:HasAnyShoppingNeeds() then
      GameTooltip:AddLine(L.TIP_BUY_ALL_NOTHING, 0.55, 0.55, 0.55, true)
    elseif not qa:CanBuyAll() then
      GameTooltip:AddLine(L.TIP_BUY_ALL_NONE_AFFORD, 0.9, 0.75, 0.55, true)
    else
      GameTooltip:AddLine(L.TIP_BUY_ALL_CAN, 0.85, 0.85, 0.9, true)
    end
    GameTooltip:Show()
  end)
  btn:SetScript("OnLeave", GameTooltip_Hide)
end

local function attachPullAllTooltip(btn)
  btn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(L.TIP_PULL_ALL_HEADER, 1, 0.95, 0.7)
    local qa = addon.QuantityAssist
    if InCombatLockdown() then
      GameTooltip:AddLine(L.TIP_PULL_ALL_COMBAT, 1, 0.35, 0.35, true)
    elseif qa:IsPullQueueActive() then
      GameTooltip:AddLine(L.TIP_PULL_ALL_IN_PROGRESS, 0.75, 0.75, 0.8, true)
    elseif not qa:IsBankInventoryAccessible() then
      GameTooltip:AddLine(L.TIP_PULL_ALL_NO_BANK, 0.75, 0.75, 0.8, true)
    elseif not qa:HasAnyShoppingNeeds() then
      GameTooltip:AddLine(L.TIP_PULL_ALL_NOTHING, 0.55, 0.55, 0.55, true)
    elseif not qa:CanPullAll() then
      GameTooltip:AddLine(L.TIP_PULL_ALL_NONE_IN_BANK, 0.9, 0.75, 0.55, true)
    else
      GameTooltip:AddLine(L.TIP_PULL_ALL_CAN, 0.85, 0.85, 0.9, true)
    end
    GameTooltip:Show()
  end)
  btn:SetScript("OnLeave", GameTooltip_Hide)
end

local function createBulkButton(parent, label, onClick, tooltipFn)
  local btn = UI:CreateAddonActionButton(parent, label)
  btn:SetSize(C.BULK_ACTION_BTN_W, C.ACTION_BTN_H)
  btn:SetFrameStrata(parent:GetFrameStrata())
  btn:SetFrameLevel(parent:GetFrameLevel() + 10)
  btn:SetScript("OnClick", onClick)
  tooltipFn(btn)
  btn:Hide()
  return btn
end

function Hooks:EnsureMerchantButton()
  if self.merchantBuyAll then
    return
  end
  local parent = _G.MerchantFrame
  if not parent then
    return
  end
  self.merchantBuyAll = createBulkButton(parent, L.BTN_BUY_ALL, function()
    addon.QuantityAssist:BuyAllFromMerchant()
  end, attachBuyAllTooltip)
  local btn = self.merchantBuyAll
  local close = _G.MerchantFrameCloseButton or parent.CloseButton
  if close then
    btn:SetPoint("RIGHT", close, "LEFT", -6, 0)
  else
    btn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, -28)
  end
end

function Hooks:EnsureBankPullButton(key, parent, anchorFn)
  if self[key] then
    return
  end
  if not parent then
    return
  end
  self[key] = createBulkButton(parent, L.BTN_PULL_ALL, function()
    addon.QuantityAssist:PullAllFromBank()
  end, attachPullAllTooltip)
  anchorFn(self[key], parent)
end

function Hooks:EnsureBankButtons()
  self:EnsureBankPullButton("bankFramePullAll", _G.BankFrame, function(btn, parent)
    local search = _G.BankItemSearchBox
    if search then
      btn:SetPoint("TOPRIGHT", search, "TOPLEFT", -8, 0)
    else
      btn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -60, -44)
    end
  end)
  self:EnsureBankPullButton("bankPanelPullAll", _G.BankPanel, function(btn, parent)
    local sort = parent.AutoSortButton
    if sort then
      btn:SetPoint("RIGHT", sort, "LEFT", -8, 0)
    else
      btn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, -8)
    end
  end)
  self:EnsureBankPullButton("accountBankPullAll", _G.AccountBankPanel, function(btn, parent)
    local sort = parent.AutoSortButton
    if sort then
      btn:SetPoint("RIGHT", sort, "LEFT", -8, 0)
    else
      btn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, -8)
    end
  end)
end

function Hooks:UpdateButtons()
  if not self._initialized then
    return
  end
  self:EnsureMerchantButton()
  self:EnsureBankButtons()
  local entries = {}
  if self.merchantBuyAll then
    entries[#entries + 1] = { buy = self.merchantBuyAll }
  end
  if self.bankFramePullAll then
    entries[#entries + 1] = { pull = self.bankFramePullAll }
  end
  if self.bankPanelPullAll then
    entries[#entries + 1] = { pull = self.bankPanelPullAll }
  end
  if self.accountBankPullAll then
    entries[#entries + 1] = { pull = self.accountBankPullAll }
  end
  addon.QuantityAssist:UpdateBulkButtonState(entries)
  self:SyncFrameButtonVisibility()
end

function Hooks:SyncFrameButtonVisibility()
  local qa = addon.QuantityAssist
  if self.merchantBuyAll and self.merchantBuyAll:IsShown() and not qa:IsMerchantUIOpen() then
    self.merchantBuyAll:Hide()
  end
  local function syncPull(btn, parent)
    if not btn or not btn:IsShown() then
      return
    end
    if parent and parent.IsShown and not parent:IsShown() then
      btn:Hide()
    end
  end
  syncPull(self.bankFramePullAll, _G.BankFrame)
  syncPull(self.bankPanelPullAll, _G.BankPanel)
  syncPull(self.accountBankPullAll, _G.AccountBankPanel)
end

function Hooks:ScheduleUpdate()
  C_Timer.After(0, function()
    Hooks:UpdateButtons()
  end)
end

local function isMerchantInteraction(interactionType)
  local Pit = Enum.PlayerInteractionType
  if not Pit or not interactionType then
    return false
  end
  return interactionType == Pit.Merchant or interactionType == Pit.Vendor
end

local function isBankInteraction(interactionType)
  local Pit = Enum.PlayerInteractionType
  if not Pit or not interactionType then
    return false
  end
  return interactionType == Pit.Banker
    or interactionType == Pit.CharacterBanker
    or interactionType == Pit.AccountBanker
end

function Hooks:OnEvent(event, arg1)
  if event == "PLAYER_REGEN_DISABLED" then
    addon.QuantityAssist:CancelPullQueue(true)
    return
  end
  if event == "BANKFRAME_CLOSED" or event == "MERCHANT_CLOSED" then
    addon.QuantityAssist:CancelPullQueue(true)
  end
  if event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
    if isMerchantInteraction(arg1) or isBankInteraction(arg1) then
      addon.QuantityAssist:CancelPullQueue(true)
    end
  end
  self:ScheduleUpdate()
  if addon.UI and addon.UI.UpdateBulkActionButtons then
    addon.UI:UpdateBulkActionButtons()
  end
end

function UI:InitBlizzardHooks()
  if Hooks._initialized then
    return
  end
  Hooks._initialized = true
  local f = CreateFrame("Frame")
  Hooks.eventFrame = f
  f:RegisterEvent("MERCHANT_SHOW")
  f:RegisterEvent("MERCHANT_CLOSED")
  f:RegisterEvent("MERCHANT_UPDATE")
  f:RegisterEvent("BANKFRAME_OPENED")
  f:RegisterEvent("BANKFRAME_CLOSED")
  f:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
  f:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE")
  f:RegisterEvent("PLAYER_REGEN_DISABLED")
  f:SetScript("OnEvent", function(_, event, ...)
    Hooks:OnEvent(event, ...)
  end)
end
