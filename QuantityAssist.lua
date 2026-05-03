local addonName, addon = ...

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
  return false
end

local function itemIdFromMerchantLink(link)
  if type(link) ~= "string" then
    return nil
  end
  return tonumber(link:match("Hitem:(%d+)") or link:match("item:(%d+)"))
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
function QuantityAssist:WithdrawFromBank(itemId, take)
  if InCombatLockdown() then
    print("|cfffeaa00Down to Darkmoon:|r Cannot withdraw in combat.")
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
    print("|cfffeaa00Down to Darkmoon:|r No matching stacks in bank.")
    return false
  end
  local bagSlot, invSlot = findFirstEmptyInventorySlot()
  if not bagSlot then
    print("|cfffeaa00Down to Darkmoon:|r No empty bag space.")
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
  local _, _, price, stackCount, numAvailable = GetMerchantItemInfo(merchantIndex)
  if not price or price <= 0 then
    return math.min(wantQty, stackCount or wantQty)
  end
  local gold = GetMoney()
  local maxByGold = math.floor(gold / price)
  if maxByGold <= 0 then
    return 0
  end
  local maxStack = stackCount or wantQty
  local q = math.min(wantQty, maxByGold, maxStack)
  if numAvailable and numAvailable > -1 then
    q = math.min(q, numAvailable)
  end
  return q
end

function QuantityAssist:BuyFromMerchant(merchantIndex, qty)
  if InCombatLockdown() then
    print("|cfffeaa00Down to Darkmoon:|r Cannot buy in combat.")
    return false
  end
  if not self:IsMerchantUIOpen() or not merchantIndex or not qty or qty <= 0 then
    return false
  end
  BuyMerchantItem(merchantIndex, qty)
  return true
end
