local addonName, addon = ...

local Navigation = {}
addon.Navigation = Navigation

local function waypointDebug(msg)
  local db = addon.GetDB and addon:GetDB()
  if type(db) == "table" and db.debugNavigation then
    print("|cff73d7ff[DTD nav]|r " .. tostring(msg))
  end
end

local function waypointDebugMapInfo(uiMapId, label)
  if not uiMapId then
    waypointDebug((label or "map") .. ": (nil id)")
    return
  end
  if C_Map and C_Map.GetMapInfo then
    local ok, info = pcall(C_Map.GetMapInfo, uiMapId)
    if ok and type(info) == "table" then
      waypointDebug(
        ("%s uiMap %s: name=%q mapType=%s parentMapID=%s flags=%s"):format(
          label or "  ",
          tostring(uiMapId),
          tostring(info.name),
          tostring(info.mapType),
          tostring(info.parentMapID),
          tostring(info.flags)
        )
      )
    else
      waypointDebug(("  GetMapInfo failed for uiMap %s"):format(tostring(uiMapId)))
    end
  end
  if C_Map and C_Map.CanSetUserWaypointOnMap then
    local ok, can = pcall(C_Map.CanSetUserWaypointOnMap, uiMapId)
    if ok then
      waypointDebug(("  CanSetUserWaypointOnMap(%s) = %s (often false on DMF; SetUserWaypoint may still work)"):format(
        tostring(uiMapId),
        tostring(can)
      ))
    end
  end
end

--- Darkmoon overview uiMap (Orphan). Dungeon floors are children (see GetMapChildrenInfo).
local DARKMOON_ORPHAN_MAP_ID = 407

local function uiMapIsDarkmoonIslandFloor(mid)
  if not mid or not C_Map or not C_Map.GetMapInfo then
    return false
  end
  local ok, info = pcall(C_Map.GetMapInfo, mid)
  if ok and type(info) == "table" and info.parentMapID == DARKMOON_ORPHAN_MAP_ID then
    return true
  end
  return false
end

local function mapIdRefersToDarkmoonIsland(mapId)
  if not mapId then
    return false
  end
  if mapId == DARKMOON_ORPHAN_MAP_ID then
    return true
  end
  return uiMapIsDarkmoonIslandFloor(mapId)
end

--- Floor ids from Blizzard data (408 + any GetMapChildrenInfo(407)); avoids shipping stale hardcoded ids (e.g. 2392).
local function getDarkmoonFloorUiMapIds()
  local out = {}
  local seen = {}
  local function add(id)
    if id and not seen[id] then
      seen[id] = true
      out[#out + 1] = id
    end
  end
  add(408)
  if C_Map.GetMapChildrenInfo then
    local ok, ch = pcall(C_Map.GetMapChildrenInfo, DARKMOON_ORPHAN_MAP_ID)
    if ok and type(ch) == "table" then
      for _, c in ipairs(ch) do
        add(c.mapID or c.mapId)
      end
    end
  end
  return out
end

local function clamp01(n)
  if type(n) ~= "number" or n ~= n then
    return nil
  end
  return math.max(0, math.min(1, n))
end

--- Returns instance/continent id and world position for a point as 0-100 map percentages.
--- (GetWorldPosFromMapPos returns continentID, worldPosition — not a boolean success flag.)
local function worldDataFromMapPct(mapId, xPct, yPct)
  if not mapId or not xPct or not yPct then
    return nil, nil
  end
  local pos = CreateVector2D(xPct / 100, yPct / 100)
  local continentID, worldPos = C_Map.GetWorldPosFromMapPos(mapId, pos)
  if not worldPos then
    return nil, nil
  end
  return continentID, worldPos
end

--- Normalized (0-1) coords on `targetUiMapId` for a world position. Third arg to
--- C_Map.GetMapPosFromWorldPos is the target uiMap (e.g. player map or a dungeon child like 408).
local function mapPctOnUiMap(continentID, worldPos, targetUiMapId)
  if not continentID or not worldPos or not targetUiMapId then
    return nil, nil
  end
  local _, mapPos = C_Map.GetMapPosFromWorldPos(continentID, worldPos, targetUiMapId)
  if not mapPos then
    return nil, nil
  end
  if mapPos.GetXY then
    return mapPos:GetXY()
  end
  return mapPos.x, mapPos.y
end

local function createUiMapPoint(mapId, xNorm, yNorm)
  local xC = clamp01(xNorm)
  local yC = clamp01(yNorm)
  if not xC or not yC or not mapId then
    return nil
  end
  if UiMapPoint and UiMapPoint.CreateFromCoordinates then
    return UiMapPoint.CreateFromCoordinates(mapId, xC, yC)
  end
  if UiMapPoint and UiMapPoint.CreateFromVector2D then
    return UiMapPoint.CreateFromVector2D(mapId, CreateVector2D(xC, yC))
  end
  return nil
end

local function addUniqueAttempt(list, mid, nx, ny)
  if not mid or not nx or not ny then
    return
  end
  for _, e in ipairs(list) do
    if e[1] == mid and math.abs(e[2] - nx) < 1e-9 and math.abs(e[3] - ny) < 1e-9 then
      return
    end
  end
  list[#list + 1] = { mid, nx, ny }
end

local function addDarkmoonFloorAliases(attempts, x, y)
  for _, fid in ipairs(getDarkmoonFloorUiMapIds()) do
    addUniqueAttempt(attempts, fid, x, y)
  end
end

--- Ordered candidates: player’s map (via world reprojection), raw POI map, child maps (e.g. 408 under 407).
local function buildWaypointAttempts(mapId, xPct, yPct)
  local attempts = {}
  local x = xPct / 100
  local y = yPct / 100
  local pm = C_Map.GetBestMapForUnit("player")

  --- On the island, raw POI percentages usually match the active floor uiMap — try it before generic aliases.
  if mapIdRefersToDarkmoonIsland(mapId) and pm and uiMapIsDarkmoonIslandFloor(pm) then
    addUniqueAttempt(attempts, pm, x, y)
  end

  --- Dungeon floors for Darkmoon (408 + children of 407 from live data).
  if mapId == DARKMOON_ORPHAN_MAP_ID or uiMapIsDarkmoonIslandFloor(mapId) then
    addDarkmoonFloorAliases(attempts, x, y)
  end

  local continentID, worldPos = worldDataFromMapPct(mapId, xPct, yPct)

  --- Reproject onto the player's current uiMap only for Darkmoon (407/408): there, orphan vs floor
  --- ids need world-space bridging. For normal zones (e.g. Elwynn vendor while you are in Silvermoon),
  --- projecting EK world coords onto Silvermoon's map yields garbage after clamping — prefer raw target map.
  if mapIdRefersToDarkmoonIsland(mapId) and continentID and worldPos and pm then
    local nx, ny = mapPctOnUiMap(continentID, worldPos, pm)
    if nx and ny then
      addUniqueAttempt(attempts, pm, nx, ny)
    end
  end

  addUniqueAttempt(attempts, mapId, x, y)

  --- Always push raw normalized coords onto child maps (e.g. 407→408). World reprojection from Orphan maps is often nil.
  if C_Map.GetMapChildrenInfo then
    local children = C_Map.GetMapChildrenInfo(mapId)
    if children then
      for _, c in ipairs(children) do
        local cid = c.mapID or c.mapId
        if cid then
          if continentID and worldPos then
            local nx, ny = mapPctOnUiMap(continentID, worldPos, cid)
            if nx and ny then
              addUniqueAttempt(attempts, cid, nx, ny)
            end
          end
          addUniqueAttempt(attempts, cid, x, y)
        end
      end
    end
  end

  --- Parent overview uiMap (407): Myu's Knowledge Points Tracker uses this id for DMF pins; matches TomTom + SuperTrack behavior there.
  if mapIdRefersToDarkmoonIsland(mapId) then
    addUniqueAttempt(attempts, DARKMOON_ORPHAN_MAP_ID, x, y)
  end

  --- Blizzard map pins often reject orphan/overview uiMap 407; try dungeon floors (408, …) first, 407 last for SetUserWaypoint.
  if mapIdRefersToDarkmoonIsland(mapId) then
    local prefer, orphan407 = {}, {}
    for _, att in ipairs(attempts) do
      if att[1] == DARKMOON_ORPHAN_MAP_ID then
        orphan407[#orphan407 + 1] = att
      else
        prefer[#prefer + 1] = att
      end
    end
    for i = 1, #orphan407 do
      prefer[#prefer + 1] = orphan407[i]
    end
    attempts = prefer
  end

  local db = addon.GetDB and addon:GetDB()
  if type(db) == "table" and db.debugNavigation then
    waypointDebug(("buildWaypointAttempts(%s, %.2f%%, %.2f%%) → %d candidate(s)"):format(tostring(mapId), xPct, yPct, #attempts))
    for i, att in ipairs(attempts) do
      waypointDebug(("  #%d uiMap=%s x=%.6f y=%.6f"):format(i, tostring(att[1]), att[2], att[3]))
      waypointDebugMapInfo(att[1], "  ")
    end
  end

  return attempts
end

--- Prefer C_AddOns (Retail); matches Myu's Knowledge Points Tracker TomTom gate.
local function isTomTomAddonLoaded()
  local TT = _G.TomTom
  if not TT then
    return false
  end
  if C_AddOns and C_AddOns.IsAddOnLoaded then
    local _, loaded = C_AddOns.IsAddOnLoaded("TomTom")
    return loaded and TT or false
  end
  if type(_G.IsAddOnLoaded) == "function" and _G.IsAddOnLoaded("TomTom") then
    return TT
  end
  return TT
end

function Navigation:IsTomTomLoaded()
  return isTomTomAddonLoaded() and true or false
end

--- Myu's addon calls TomTom:AddWaypoint(uiMap, nx, ny, opts); older TomTom used AddMFWaypoint only.
local function addTomTomWaypoint(mapId, xNorm, yNorm, title)
  local TT = isTomTomAddonLoaded()
  if not TT then
    return false
  end
  local opts = {
    title = title,
    persistent = false,
    minimap = true,
    world = true,
    crazy = true,
    silent = true,
  }
  if type(TT.AddWaypoint) == "function" then
    local ok = pcall(function()
      TT:AddWaypoint(mapId, xNorm, yNorm, opts)
    end)
    if ok then
      return true
    end
  end
  if type(TT.AddMFWaypoint) == "function" then
    return pcall(function()
      TT:AddMFWaypoint(mapId, nil, xNorm, yNorm, opts)
    end)
  end
  return false
end

local function tryBlizzardPinOnce(mid, nx, ny)
  local point = createUiMapPoint(mid, nx, ny)
  if not point then
    return false
  end
  local ok = pcall(C_Map.SetUserWaypoint, point)
  if not ok then
    return false
  end
  if C_Map.HasUserWaypoint then
    local hasOk, has = pcall(C_Map.HasUserWaypoint)
    if hasOk and not has then
      return false
    end
  end
  if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
    pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, true)
  end
  return true
end

function Navigation:SetWaypointPct(mapId, xPct, yPct, title)
  if not mapId or not xPct or not yPct then
    return
  end
  title = title or "Down to Darkmoon"

  local pm = C_Map.GetBestMapForUnit("player")
  waypointDebug(("── SetWaypointPct ── %q"):format(title))
  waypointDebug(("  target: uiMap=%s  x%%=%.2f y%%=%.2f"):format(tostring(mapId), xPct, yPct))
  waypointDebug(("  player: BestMap=%s"):format(tostring(pm)))
  waypointDebugMapInfo(pm, "  player")
  waypointDebug(
    "  Note: CanSetUserWaypointOnMap is often false on Darkmoon; pins still use SetUserWaypoint + optional arrow via tracking."
  )

  local attempts = buildWaypointAttempts(mapId, xPct, yPct)

  if C_Map.ClearUserWaypoint then
    pcall(C_Map.ClearUserWaypoint)
  end

  --- Blizzard pin first, then TomTom (same order as Myu's Knowledge Points Tracker).
  for _, att in ipairs(attempts) do
    local mid, nx, ny = att[1], att[2], att[3]
    nx = clamp01(nx)
    ny = clamp01(ny)
    if nx and ny then
      if tryBlizzardPinOnce(mid, nx, ny) then
        addTomTomWaypoint(mid, nx, ny, title)
        waypointDebug(("  pin+TomTom | uiMap=%s"):format(tostring(mid)))
        print(("|cfffeaa00Down to Darkmoon:|r Map pin — %s"):format(title))
        return
      end
    end
  end

  waypointDebug("  Blizzard pin failed for all candidates; trying TomTom-only…")
  for _, att in ipairs(attempts) do
    local mid, nx, ny = att[1], att[2], att[3]
    nx = clamp01(nx)
    ny = clamp01(ny)
    if nx and ny and addTomTomWaypoint(mid, nx, ny, title) then
      waypointDebug(("  TomTom-only OK | uiMap=%s"):format(tostring(mid)))
      print(("|cfffeaa00Down to Darkmoon:|r Waypoint — %s"):format(title))
      return
    end
  end

  print("|cfffeaa00Down to Darkmoon:|r Install TomTom for arrows, or open a zone map that allows pins.")
  waypointDebug("SetWaypointPct: gave up (TomTom + Blizzard both failed)")
end

function Navigation:SetWaypointPOI(poiId)
  local p = addon.Data.POIS[poiId]
  if not p then
    return
  end
  self:SetWaypointPct(p.mapId, p.x, p.y, p.label)
end

function Navigation:SetWaypointForItem(itemKey)
  local def = addon.Data.ITEMS[itemKey]
  if not def or not def.vendors or #def.vendors == 0 then
    return
  end
  local v = addon.VendorRouting:GetClosestVendor(def.vendors)
  if v then
    self:SetWaypointPct(v.mapId, v.x, v.y, v.label)
  end
end
