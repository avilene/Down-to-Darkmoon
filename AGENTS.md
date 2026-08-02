# Down-to-Darkmoon — Agent Reference

This file is written for AI coding agents. It explains the codebase structure,
key data flows, and gotchas that matter when making changes.

---

## What the addon does

**Down-to-Darkmoon** is a WoW addon that helps players complete the monthly
Darkmoon Faire profession quests. It tracks which vendor materials (dyes, thread,
baubles, flour, parchment, etc.) are still needed, shows how to get them, and can
automatically pull them from the bank or buy them from a merchant.

---

## File map

| File | Purpose |
|---|---|
| `Core.lua` | Addon init, SavedVariables, all non-UI logic: quest state, item counting, shopping-need calculation |
| `Data/Retail.lua` | Static data: quest definitions (`QUESTS`), item definitions (`ITEMS`), vendor locations, NPC pins |
| `QuantityAssist.lua` | Bank scanning/withdrawal, merchant buying, pull-queue state machine |
| `UI/MainFrame.lua` | Main panel frame construction |
| `UI/Refresh.lua` | Panel content refresh logic (row rendering) |
| `UI/Rows.lua` | Individual row widgets |
| `UI/Buttons.lua` | "Pull all" / "Buy all" button creation |
| `UI/BlizzardHooks.lua` | Hooks into BankFrame / MerchantFrame to inject buttons |
| `UI/Settings.lua` | `/dtdm settings` panel |
| `Navigation.lua` | TomTom waypoint helpers |
| `VendorRouting.lua` | Distance/proximity helpers for vendor and interactable locations |
| `MapPins.lua` | World map / minimap pin rendering |
| `Minimap.lua` | LibDBIcon minimap button |
| `Calendar.lua` | Faire open/close detection, login notifications |
| `Locale.lua` | String table (`addon.L`) |
| `Logger.lua` | Debug logging (`/dtdm debug`) |

---

## Data model (`Data/Retail.lua`)

### `ITEMS` table
Each entry is keyed by a short string (e.g. `"blue_dye"`) and has:
```
itemId   – WoW item ID
name     – display name
vendors  – array of { mapId, x, y, label, faction? }
```

### `QUESTS` array (`ProfessionQuest` entries)
Each entry has:
```
questId                       – WoW quest ID
profession / skillLineId      – which profession unlocks this quest
requiredStacks                – array of { itemKey, count }
  count = TOTAL needed for the whole quest (e.g. 5 blue_dye for 5 LW prizes)
useQuestItems                 – quest-item IDs the player uses in the field
shoppingObjectiveItemId       – crafted/hand-in item ID (enables proportional "need now" logic)
shoppingProgressItemId        – progress item when mats are consumed (cooking)
shoppingConsumedByQuestItemId – item that consumes the vendor mat (Plump Frog → flour)
shoppingProgressCreditItemIds – intermediate items that count toward progress (breaded frog)
hideRequiredStacksWhenHaveItemIds – hide shopping rows when player holds any of these
```

`requiredStacks[n].count` is always the **total** for the whole quest objective, NOT per
craft-step. The proportional-need logic (`shoppingStillNeedFromObjectiveProgress`) divides
this by `required` (from the quest objective) to compute how many are needed right now.

---

## Shopping-need calculation

The central question is: **how many of item X does the player still need to pull/buy?**

### `addon:GetShoppingIngredientStillNeed(questId, ingredientItemId, stackNeed)`
Returns the number still needed for a single quest × ingredient pair. Priority:

1. **Objective-progress path** (`shoppingObjectiveItemId` set on quest):
   `shoppingStillNeedFromObjectiveProgress` → proportional to quest progress.
   Formula: `ceil(pairsStill * stackNeed / required) − have_in_bags`
   where `pairsStill = required − fulfilled − objectiveInBags`.
   Returns `nil` if the player is not on the quest (no objective data available).

2. **Consumed-by-quest-item path** (`shoppingConsumedByQuestItemId` set):
   `shoppingStillNeedFromQuestItemConsumption` → counts how many usable quest items
   are in bags versus ingredients already there. Returns `nil` if quest not active.

3. **Fallback**: `QuantityAssist:GetStillNeed(ingredientItemId, stackNeed)`
   → `max(0, stackNeed − GetItemCountCompat(ingredientItemId))`
   Simple bag-count subtraction, no objective awareness.

### `addon:GetActiveShoppingNeeds()` (called by bulk-pull and bulk-buy)
Iterates all QUESTS filtered by:
- player has the profession skill (`PlayerSkillLineSet`)
- quest not completed (`IsProfessionQuestCompleted`)
- quest not in "objective phase complete" (`IsQuestObjectivePhaseComplete`)
- `ShouldShowShoppingIngredientRow` returns true for this ingredient

Then **deduplicates by itemId, keeping the maximum `still` value across all quests**.
Returns an array of `{ itemId, itemKey, still }`.

> **Key implication**: if a player has both Leatherworking (needs 5 blue_dye) and
> Tailoring (needs 1 blue_dye at a time via the objective-progress path), the bulk-pull
> will withdraw `max(5, 1) = 5` blue_dyes because both quests are aggregated.
> This is by design — LW genuinely needs those 5 dyes — but can look surprising when
> the user thinks they are only preparing for tailoring.

### `addon:GetItemCountCompat(itemId)`
Counts items in **character bags only** (no bank, no reagent bank, no warband).
Uses `C_Item.GetItemCount(id, false, false, false, false)` or the legacy `GetItemCount`.

---

## Bank withdrawal flow (`QuantityAssist.lua`)

### Single withdrawal: `WithdrawFromBank(itemId, take, silent)`
1. Checks combat lockdown and bank accessibility.
2. `ScanBankForItem` → scans legacy bank (`-1`), reagent bank (`-3`), extra bank bags,
   and Warband bank tabs for stacks of `itemId`.
3. Finds the first empty inventory slot (`findFirstEmptyInventorySlot`).
4. Takes `move = min(take, firstStack.count)` items:
   - `move < stack.count` → `SplitContainerItem` (picks up a partial stack into cursor)
   - `move == stack.count` → `PickupContainerItem` (picks up the whole stack)
5. `PickupContainerItem(bagSlot, invSlot)` places the cursor into the empty bag slot.
6. `ClearCursor()` — clears any leftover cursor state.
7. Returns `true` on success (does **not** verify the item actually landed in bags).

> **Only one stack movement happens per call.** If you need more than one stack's worth,
> the pull-queue calls `WithdrawFromBank` repeatedly (one per timer tick).

### Pull queue: `ProcessPullQueueTick()`
Timer-driven state machine (`PULL_QUEUE_DELAY = 0.08 s` between ticks):
1. Re-evaluates `GetActiveShoppingNeeds()` fresh every tick.
2. Loops needs; for the **first** item that still has `still > 0` and bank stock > 0,
   calls `WithdrawFromBank(itemId, still)` and **returns** (one item per tick).
3. On the next tick, `still` is recomputed — if inventory was updated it will be lower.
4. Stops when all needs reach `still = 0` or bank is empty.

---

## Objective-progress proportional math (important detail)

For quests with `shoppingObjectiveItemId`:

```
pairsStill      = required - fulfilled - objectiveInBags
needForRemaining = ceil(pairsStill * stackNeed / required)
stillNeed        = max(0, needForRemaining - have_in_bags)
```

- `required` = total objective count (e.g. 5 banners, 5 prizes)
- `fulfilled` = how many objectives are already credited in the quest log
- `objectiveInBags` = crafted items already in bags (not yet used/planted)
- `stackNeed` = `requiredStacks[n].count` = total mats for the whole quest
- `have_in_bags` = `GetItemCountCompat(ingredientItemId)`

For tailoring (5 banners, 1 blue_dye total in data):
  `needForRemaining = ceil(pairsStill * 1 / 5)` — always ≤ 1, i.e. one dye per banner.

For LW (5 prizes, 5 blue_dye total in data):
  `needForRemaining = ceil(pairsStill * 5 / 5) = pairsStill` — full amount up front.

---

## Debugging the "too many items withdrawn" class of bug

When investigating over-withdrawal:

1. **Check `GetActiveShoppingNeeds` output** — does more than one quest contribute to
   the same `itemId`? The max-aggregation may be picking up a larger need from a
   different profession.

2. **Check objective-progress path vs fallback** — `GetShoppingIngredientStillNeed`
   uses the objective-progress formula only when the player is **on the quest**
   (`C_QuestLog.IsOnQuest` returns true). If the player hasn't yet accepted the quest,
   the fallback `GetStillNeed(id, stackNeed)` fires, using the raw total count.
   For ingredients with count = 1 this doesn't matter, but for count = 5 (LW) it means
   `still = 5` even before the quest is accepted.

3. **Check `WithdrawFromBank` `take` parameter** — `take = stillNeedForItem(itemId)`
   which re-calls `GetActiveShoppingNeeds()`. If this is unexpectedly high, the
   aggregation in step 1 is the culprit.

4. **Timer races** — `GetItemCountCompat` reads live data; it should reflect the
   withdrawn item by the next tick (80 ms later). If repeated withdrawals of the same
   item happen, add logging around `stillNeedForItem` return values.

---

## Build / lint / test

This is a pure-Lua WoW addon with no build step. There is no automated test suite.
The GitHub Actions workflow (`release.yml`) packages the addon for CurseForge release.

To validate changes, load the addon in-game (or on a PTR/beta) and exercise the
affected code path manually.
