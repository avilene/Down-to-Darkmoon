local addonName, addon = ...

local VendorRouting = {}
addon.VendorRouting = VendorRouting

local function normalizeFaction(f)
  if not f or f == "Any" then
    return nil
  end
  return f
end

function VendorRouting:PlayerFactionKey()
  local g = UnitFactionGroup("player")
  if g == "Alliance" then
    return "Alliance"
  elseif g == "Horde" then
    return "Horde"
  end
  return nil
end

function VendorRouting:VendorEligible(vendor)
  local vf = normalizeFaction(vendor.faction)
  if not vf then
    return true
  end
  local pf = self:PlayerFactionKey()
  if not pf then
    return true
  end
  return vf == pf
end

function VendorRouting:FilterVendors(vendors)
  local out = {}
  for _, v in ipairs(vendors) do
    if self:VendorEligible(v) then
      out[#out + 1] = v
    end
  end
  return out
end

local function worldPosFromMap(mapId, xPct, yPct)
  if not mapId or not xPct or not yPct then
    return nil
  end
  local pos = CreateVector2D(xPct / 100, yPct / 100)
  local _, w = C_Map.GetWorldPosFromMapPos(mapId, pos)
  if w and w.GetXY then
    return w:GetXY()
  end
  return nil, nil
end

function VendorRouting:DistanceSqBetweenMaps(mapIdA, xPctA, yPctA, mapIdB, xPctB, yPctB)
  local ax, ay = worldPosFromMap(mapIdA, xPctA, yPctA)
  local bx, by = worldPosFromMap(mapIdB, xPctB, yPctB)
  if ax and ay and bx and by then
    local dx = ax - bx
    local dy = ay - by
    return dx * dx + dy * dy
  end
  if mapIdA == mapIdB then
    local dx = (xPctA - xPctB) / 100
    local dy = (yPctA - yPctB) / 100
    return dx * dx + dy * dy
  end
  return math.huge
end

function VendorRouting:GetClosestVendor(vendors)
  local list = self:FilterVendors(vendors)
  if #list == 0 then
    return vendors[1]
  end
  local pm = C_Map.GetBestMapForUnit("player")
  if not pm then
    return list[1]
  end
  local pp = C_Map.GetPlayerMapPosition(pm, "player")
  if not pp then
    return list[1]
  end
  local px, py = pp:GetXY()
  px, py = px * 100, py * 100
  local best = list[1]
  local bestD = self:DistanceSqBetweenMaps(pm, px, py, best.mapId, best.x, best.y)
  for i = 2, #list do
    local v = list[i]
    local d = self:DistanceSqBetweenMaps(pm, px, py, v.mapId, v.x, v.y)
    if d < bestD then
      bestD = d
      best = v
    end
  end
  return best
end
