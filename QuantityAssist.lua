local addonName, addon = ...
local L = addon.L

local QuantityAssist = {}
addon.QuantityAssist = QuantityAssist

local BANK_ID = Enum.BagIndex and Enum.BagIndex.Bank or -1
local REAGENT_ID = Enum.BagIndex and Enum.BagIndex.Reagentbank or -3

--- Character bank tab bags + Warband (account) bank tab bags are separate container IDs from legacy bank (-1).
local EXTRA_BANK_BAG_INDICES = {}
do
  local seen = {}
  local function add(id)
    if type(id) == "number" and id ~= 0 and not seen[id] then
      seen[id] = true
      EXTRA_BANK_BAG_INDICES[#EXTRA_BANK_BAG_INDICES + 1] = id
    end
  end
  local E = Enum.BagIndex
  if E then
    for i = 1, 6 do
      add(E["CharacterBankTab_" .. i])
    end
    for i = 1, 5 do
      add(E["AccountBankTab_" .. i])
    end
  end
  -- Retail Warband tabs (AccountBankTab_1–5 ≈ 12–16); harmless duplicates removed by add()
  for id = 12, 16 do
    add(id)
  end
  if not E or not E.CharacterBankTab_1 then
    for id = 6, 11 do
      add(id)
    end
  end
end

function QuantityAssist:IsBankInventoryAccessible()
  if BankFrame and BankFrame:IsShown() then
    return true
  end
  local bp = _G.BankPanel
  if bp and bp.IsShown and bp:IsShown() then
    return true
  end
  local abp = _G.AccountBankPanel
  if abp and abp.IsShown and abp:IsShown() then
    return true
  end
  local C = C_PlayerInteractionManager
  local Pit = Enum.PlayerInteractionType
  if C and Pit and type(C.IsInteractingWithNpcOfType) == "function" then
    if Pit.Banker and C.IsInteractingWithNpcOfType(Pit.Banker) then
      return true
    end
    if Pit.CharacterBanker and C.IsInteractingWithNpcOfType(Pit.CharacterBanker) then
      return true
    end
    if Pit.AccountBanker and C.IsInteractingWithNpcOfType(Pit.AccountBanker) then
      return true
    end
  end
  return false
end

--- Retail often opens vendors via PlayerInteractionManager; trade NPCs may use |cffff5555Vendor|r not Merchant, and |cffff5555MerchantFrame:IsShown()|r can be false while buying is valid.
function QuantityAssist:IsMerchantUIOpen()
  if MerchantFrame and MerchantFrame:IsShown() then
    return true
  end
  if MerchantFrame and MerchantFrame.IsVisible and MerchantFrame:IsVisible() then
    return true
  end
  local C = C_PlayerInteractionManager
  local Pit = Enum.PlayerInteractionType
  if C and Pit and type(C.IsInteractingWithNpcOfType) == "function" then
    if Pit.Merchant and C.IsInteractingWithNpcOfType(Pit.Merchant) then
      return true
    end
    if Pit.Vendor and C.IsInteractingWithNpcOfType(Pit.Vendor) then
      return true
    end
  end
  --- Listing is populated while the buy UI is usable; frame visibility / interaction type can lie (new vendor UI).
  local n = GetMerchantNumItems and GetMerchantNumItems() or 0
  if n > 0 then
    return true
  end
  return false
end

local function itemIdFromMerchantLink(link)
  if type(link) ~= "string" then
    return nil
  end
  return tonumber(link:match("Hitem:(%d+)") or link:match("item:(%d+)"))
end

--- Retail exposes listing fields via C_MerchantFrame; legacy globals may be nil.
local function getMerchantItemSaleFields(index)
  if not index then
    return nil, nil, nil
  end
  if C_MerchantFrame and type(C_MerchantFrame.GetItemInfo) == "function" then
    local ok, info = pcall(C_MerchantFrame.GetItemInfo, index)
    if ok and type(info) == "table" then
      return info.price, info.stackCount, info.numAvailable
    end
  end
  if type(GetMerchantItemInfo) == "function" then
    local _, _, price, stackCount, numAvailable = GetMerchantItemInfo(index)
    return price, stackCount, numAvailable
  end
  return nil, nil, nil
end

local function pickupContainerItem(bag, slot)
  if C_Container and C_Container.PickupContainerItem then
    C_Container.PickupContainerItem(bag, slot)
  else
    PickupContainerItem(bag, slot)
  end
end

local function splitContainerItem(bag, slot, count)
  if C_Container and C_Container.SplitContainerItem then
    C_Container.SplitContainerItem(bag, slot, count)
  else
    SplitContainerItem(bag, slot, count)
  end
end

function QuantityAssist:GetStillNeed(itemId, requiredTotal)
  if not itemId or not requiredTotal then
    return 0
  end
  local have = addon:GetItemCountCompat(itemId)
  return math.max(0, requiredTotal - have)
end

local function findFirstEmptyInventorySlot()
  for bag = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
    local n = C_Container.GetContainerNumSlots(bag)
    if n and n > 0 then
      for slot = 1, n do
        local info = C_Container.GetContainerItemInfo(bag, slot)
        if not info then
          return bag, slot
        end
      end
    end
  end
  return nil, nil
end

function QuantityAssist:ScanBankForItem(itemId)
  local stacks = {}
  if not itemId or not self:IsBankInventoryAccessible() then
    return stacks
  end
  local function scan(containerId)
    local n = C_Container.GetContainerNumSlots(containerId)
    if not n or n <= 0 then
      return
    end
    for slot = 1, n do
      local info = C_Container.GetContainerItemInfo(containerId, slot)
      if info and info.itemID == itemId and info.stackCount and info.stackCount > 0 then
        stacks[#stacks + 1] = {
          bag = containerId,
          slot = slot,
          count = info.stackCount,
        }
      end
    end
  end
  scan(BANK_ID)
  if REAGENT_ID and C_Container.GetContainerNumSlots(REAGENT_ID) then
    scan(REAGENT_ID)
  end
  local bankBags = GetNumBankSlots and GetNumBankSlots() or 0
  for i = 1, bankBags do
    scan(NUM_BAG_SLOTS + i)
  end
  for _, bagId in ipairs(EXTRA_BANK_BAG_INDICES) do
    scan(bagId)
  end
  return stacks
end

function QuantityAssist:GetBankCount(itemId)
  local total = 0
  for _, s in ipairs(self:ScanBankForItem(itemId)) do
    total = total + s.count
  end
  return total
end

---Secure execution path: withdraw up to `take` from first matching bank stack into bags.
function QuantityAssist:WithdrawFromBank(itemId, take, silent)
  if InCombatLockdown() then
    if not silent then
      print(L.MSG_CANNOT_WITHDRAW_COMBAT)
    end
    return false
  end
  if not self:IsBankInventoryAccessible() then
    return false
  end
  if not itemId or not take or take <= 0 then
    return false
  end
  local stacks = self:ScanBankForItem(itemId)
  if #stacks == 0 then
    if not silent then
      print(L.MSG_NO_BANK_STACKS)
    end
    return false
  end
  local bagSlot, invSlot = findFirstEmptyInventorySlot()
  if not bagSlot then
    if not silent then
      print(L.MSG_NO_BAG_SPACE)
    end
    return false
  end
  local stack = stacks[1]
  local move = math.min(take, stack.count)
  local b, s = stack.bag, stack.slot
  ClearCursor()
  if move < stack.count then
    splitContainerItem(b, s, move)
  else
    pickupContainerItem(b, s)
  end
  pickupContainerItem(bagSlot, invSlot)
  ClearCursor()
  return true
end

function QuantityAssist:FindMerchantIndex(itemId)
  if not itemId or not self:IsMerchantUIOpen() then
    return nil
  end
  local n = GetMerchantNumItems and GetMerchantNumItems() or 0
  for i = 1, n do
    if C_MerchantFrame and type(C_MerchantFrame.GetItemInfo) == "function" then
      local ok, info = pcall(C_MerchantFrame.GetItemInfo, i)
      if ok and type(info) == "table" then
        local cid = info.itemID or info.itemId
        if cid == itemId then
          return i
        end
      end
    end
    local mid = GetMerchantItemID and GetMerchantItemID(i)
    if mid == itemId then
      return i
    end
    local link = GetMerchantItemLink and GetMerchantItemLink(i)
    local fromLink = itemIdFromMerchantLink(link)
    if fromLink == itemId then
      return i
    end
  end
  return nil
end

function QuantityAssist:GetAffordableBuyQty(merchantIndex, wantQty)
  if not merchantIndex or not wantQty or wantQty <= 0 then
    return 0
  end
  local price, stackCount, numAvailable = getMerchantItemSaleFields(merchantIndex)
  if price == nil and stackCount == nil and numAvailable == nil then
    return 0
  end
  if not price or price <= 0 then
    local q = wantQty
    if numAvailable and numAvailable > -1 then
      q = math.min(q, numAvailable)
    end
    return q
  end
  local gold = GetMoney()
  local maxByGold = math.floor(gold / price)
  if maxByGold <= 0 then
    return 0
  end
  --- `BuyMerchantItem(index, qty)` accepts full desired quantity; stackCount is packaging, not a hard click cap.
  local q = math.min(wantQty, maxByGold)
  if numAvailable and numAvailable > -1 then
    q = math.min(q, numAvailable)
  end
  return q
end

function QuantityAssist:BuyFromMerchant(merchantIndex, qty)
  if InCombatLockdown() then
    print(L.MSG_CANNOT_BUY_COMBAT)
    return false
  end
  if not self:IsMerchantUIOpen() or not merchantIndex or not qty or qty <= 0 then
    return false
  end
  BuyMerchantItem(merchantIndex, qty)
  return true
end

function QuantityAssist:CanPullIngredient(need)
  if InCombatLockdown() or not need or need <= 0 then
    return false
  end
  return self:IsBankInventoryAccessible()
end

function QuantityAssist:CanBuyIngredient(itemId, need)
  if InCombatLockdown() or not need or need <= 0 then
    return false
  end
  return self:FindMerchantIndex(itemId) ~= nil
end

local PULL_QUEUE_DELAY = 0.08

function QuantityAssist:IsPullQueueActive()
  return self._pullQueueActive == true
end

function QuantityAssist:CancelPullQueue(silent)
  self._pullQueueActive = false
  self._pullQueueTimer = nil
  if not silent and self._pullQueueHadWork then
    print(L.MSG_PULL_ALL_STOPPED)
  end
  self._pullQueueHadWork = false
  if addon.UI and addon.UI.UpdateBulkActionButtons then
    addon.UI:UpdateBulkActionButtons()
  end
  if addon.UI and addon.UI.BlizzardHooks and addon.UI.BlizzardHooks.UpdateButtons then
    addon.UI.BlizzardHooks:UpdateButtons()
  end
end

local function stillNeedForItem(itemId)
  local maxStill = 0
  for _, need in ipairs(addon:GetActiveShoppingNeeds()) do
    if need.itemId == itemId and need.still > maxStill then
      maxStill = need.still
    end
  end
  return maxStill
end

function QuantityAssist:ProcessPullQueueTick()
  if not self._pullQueueActive then
    return
  end
  if InCombatLockdown() or not self:IsBankInventoryAccessible() then
    self:CancelPullQueue(false)
    return
  end
  local needs = addon:GetActiveShoppingNeeds()
  if #needs == 0 then
    self._pullQueueActive = false
    self._pullQueueHadWork = false
    print(L.MSG_PULL_ALL_DONE)
    if addon.UI and addon.UI.mainFrame and addon.UI.mainFrame:IsShown() then
      addon.UI:Refresh()
    end
    if addon.UI and addon.UI.UpdateBulkActionButtons then
      addon.UI:UpdateBulkActionButtons()
    end
    if addon.UI and addon.UI.BlizzardHooks and addon.UI.BlizzardHooks.UpdateButtons then
      addon.UI.BlizzardHooks:UpdateButtons()
    end
    return
  end
  for _, need in ipairs(needs) do
    local still = stillNeedForItem(need.itemId)
    if still > 0 and self:GetBankCount(need.itemId) > 0 then
      local ok = self:WithdrawFromBank(need.itemId, still, true)
      if ok then
        self._pullQueueHadWork = true
        self._pullQueueTimer = C_Timer.After(PULL_QUEUE_DELAY, function()
          QuantityAssist:ProcessPullQueueTick()
        end)
        if addon.UI and addon.UI.UpdateBulkActionButtons then
          addon.UI:UpdateBulkActionButtons()
        end
        if addon.UI and addon.UI.BlizzardHooks and addon.UI.BlizzardHooks.UpdateButtons then
          addon.UI.BlizzardHooks:UpdateButtons()
        end
        return
      end
      self._pullQueueActive = false
      if self._pullQueueHadWork then
        print(L.MSG_PULL_ALL_DONE)
      else
        print(L.MSG_PULL_ALL_STOPPED)
      end
      self._pullQueueHadWork = false
      if addon.UI and addon.UI.mainFrame and addon.UI.mainFrame:IsShown() then
        addon.UI:Refresh()
      end
      if addon.UI and addon.UI.UpdateBulkActionButtons then
        addon.UI:UpdateBulkActionButtons()
      end
      if addon.UI and addon.UI.BlizzardHooks and addon.UI.BlizzardHooks.UpdateButtons then
        addon.UI.BlizzardHooks:UpdateButtons()
      end
      return
    end
  end
  self._pullQueueActive = false
  if self._pullQueueHadWork then
    print(L.MSG_PULL_ALL_DONE)
  else
    print(L.MSG_PULL_ALL_STOPPED)
  end
  self._pullQueueHadWork = false
  if addon.UI and addon.UI.mainFrame and addon.UI.mainFrame:IsShown() then
    addon.UI:Refresh()
  end
  if addon.UI and addon.UI.UpdateBulkActionButtons then
    addon.UI:UpdateBulkActionButtons()
  end
  if addon.UI and addon.UI.BlizzardHooks and addon.UI.BlizzardHooks.UpdateButtons then
    addon.UI.BlizzardHooks:UpdateButtons()
  end
end

function QuantityAssist:PullAllFromBank()
  if InCombatLockdown() then
    print(L.MSG_CANNOT_PULL_COMBAT)
    return false
  end
  if not self:IsBankInventoryAccessible() then
    print(L.MSG_OPEN_BANK_PULL)
    return false
  end
  if self:IsPullQueueActive() then
    return false
  end
  if not self:CanPullAll() then
    return false
  end
  self._pullQueueActive = true
  self._pullQueueHadWork = false
  self:ProcessPullQueueTick()
  return true
end

function QuantityAssist:BuyAllFromMerchant()
  if InCombatLockdown() then
    print(L.MSG_CANNOT_BUY_COMBAT)
    return false
  end
  if not self:IsMerchantUIOpen() then
    return false
  end
  local bought = 0
  for _, need in ipairs(addon:GetActiveShoppingNeeds()) do
    local still = stillNeedForItem(need.itemId)
    if still > 0 then
      local midx = self:FindMerchantIndex(need.itemId)
      if midx then
        local qty = self:GetAffordableBuyQty(midx, still)
        if qty and qty > 0 then
          if self:BuyFromMerchant(midx, qty) then
            bought = bought + 1
          end
        end
      end
    end
  end
  if bought > 0 then
    print(L.MSG_BUY_ALL_DONE:format(bought))
  else
    print(L.MSG_BUY_ALL_NONE)
  end
  if addon.UI and addon.UI.mainFrame and addon.UI.mainFrame:IsShown() then
    addon.UI:Refresh()
  end
  if addon.UI and addon.UI.UpdateBulkActionButtons then
    addon.UI:UpdateBulkActionButtons()
  end
  if addon.UI and addon.UI.BlizzardHooks and addon.UI.BlizzardHooks.UpdateButtons then
    addon.UI.BlizzardHooks:UpdateButtons()
  end
  return bought > 0
end

function QuantityAssist:CanBuyAll()
  if InCombatLockdown() or not self:IsMerchantUIOpen() then
    return false
  end
  for _, need in ipairs(addon:GetActiveShoppingNeeds()) do
    local still = stillNeedForItem(need.itemId)
    if still > 0 then
      local midx = self:FindMerchantIndex(need.itemId)
      if midx and self:GetAffordableBuyQty(midx, still) > 0 then
        return true
      end
    end
  end
  return false
end

function QuantityAssist:CanPullAll()
  if InCombatLockdown() or not self:IsBankInventoryAccessible() or self:IsPullQueueActive() then
    return false
  end
  for _, need in ipairs(addon:GetActiveShoppingNeeds()) do
    local still = stillNeedForItem(need.itemId)
    if still > 0 and self:GetBankCount(need.itemId) > 0 then
      return true
    end
  end
  return false
end

function QuantityAssist:HasAnyShoppingNeeds()
  return #(addon:GetActiveShoppingNeeds()) > 0
end

---@param buttons table[]? list of { buy?: Button, pull?: Button }
function QuantityAssist:UpdateBulkButtonState(buttons)
  if type(buttons) ~= "table" then
    return
  end
  local hasNeeds = self:HasAnyShoppingNeeds()
  local merchantOpen = self:IsMerchantUIOpen()
  local bankOpen = self:IsBankInventoryAccessible()
  local canBuy = self:CanBuyAll()
  local canPull = self:CanPullAll()
  local pullActive = self:IsPullQueueActive()
  for _, entry in ipairs(buttons) do
    if entry.buy then
      local show = merchantOpen and hasNeeds
      entry.buy:SetShown(show)
      if show then
        if canBuy then
          entry.buy:Enable()
        else
          entry.buy:Disable()
        end
      end
    end
    if entry.pull then
      local show = bankOpen and hasNeeds
      entry.pull:SetShown(show)
      if show then
        if pullActive then
          entry.pull:Disable()
        elseif canPull then
          entry.pull:Enable()
        else
          entry.pull:Disable()
        end
      end
    end
  end
end
