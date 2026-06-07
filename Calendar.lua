local addonName, addon = ...

local Calendar = {
  active = false,
}
addon.Calendar = Calendar

--- While on the faire grounds, BestMap is a floor uiMap whose parent is the Darkmoon overview (407).
local DARKMOON_OVERVIEW_UIMAP = 407

--- Retail schedule: first Sunday of each month, one week (realm midnight).
local SUNDAY_WEEKDAY = 1 -- 1 = Sunday … 7 = Saturday (WoW / os.date convention)
local DARKMOON_FAIRE_DAYS = 7

--- Calendar day as YYYYMMDD for simple inclusive range checks.
local function dateKey(ct)
  if not ct then
    return 0
  end
  return (ct.year or 0) * 10000 + (ct.month or 0) * 100 + (ct.monthDay or 0)
end

--- Gregorian weekday for a calendar date (1 = Sunday … 7 = Saturday).
local function calendarWeekday(year, month, day)
  local y = year
  local m = month
  if m < 3 then
    m = m + 12
    y = y - 1
  end
  local k = y % 100
  local j = math.floor(y / 100)
  local h = (day + math.floor(13 * (m + 1) / 5) + k + math.floor(k / 4) + math.floor(j / 4) + 5 * j) % 7
  local map = { [0] = 7, [1] = 1, [2] = 2, [3] = 3, [4] = 4, [5] = 5, [6] = 6 }
  return map[h]
end

local function firstSundayDayOfMonth(year, month)
  for day = 1, 7 do
    if calendarWeekday(year, month, day) == SUNDAY_WEEKDAY then
      return day
    end
  end
  return nil
end

local function makeCalendarTime(year, month, monthDay, hour, minute)
  local weekday = calendarWeekday(year, month, monthDay)
  if C_DateAndTime and type(C_DateAndTime.CreateCalendarTime) == "function" then
    local ok, ct = pcall(C_DateAndTime.CreateCalendarTime, {
      year = year,
      month = month,
      monthDay = monthDay,
      weekday = weekday,
      hour = hour or 0,
      minute = minute or 0,
    })
    if ok and ct then
      if not ct.weekday then
        ct.weekday = weekday
      end
      return ct
    end
  end
  return {
    year = year,
    month = month,
    monthDay = monthDay,
    weekday = weekday,
    hour = hour or 0,
    minute = minute or 0,
  }
end

local function advanceCalendarMonth(year, month)
  if month >= 12 then
    return year + 1, 1
  end
  return year, month + 1
end

local function adjustCalendarTimeByDays(ct, days)
  if not ct or not C_DateAndTime or not C_DateAndTime.AdjustTimeByDays then
    return nil
  end
  local ok, shifted = pcall(C_DateAndTime.AdjustTimeByDays, ct, days)
  if ok then
    return shifted
  end
  return nil
end

local function getCurrentCalendarTime()
  if not C_DateAndTime or not C_DateAndTime.GetCurrentCalendarTime then
    return nil
  end
  return C_DateAndTime.GetCurrentCalendarTime()
end

local function isDarkmoonFaireWeek(now)
  if not now or not now.year or not now.month then
    return false
  end
  local startDay = firstSundayDayOfMonth(now.year, now.month)
  if not startDay then
    return false
  end
  local startCt = makeCalendarTime(now.year, now.month, startDay, 0, 0)
  local startKey = dateKey(startCt)
  local nowKey = dateKey(now)
  local endCt = adjustCalendarTimeByDays(startCt, DARKMOON_FAIRE_DAYS - 1)
  if endCt then
    return nowKey >= startKey and nowKey <= dateKey(endCt)
  end
  return nowKey >= startKey and (nowKey - startKey) < DARKMOON_FAIRE_DAYS
end

local function getNextFirstSundayStartAfterNow(now)
  if not now or not now.year or not now.month then
    return nil
  end
  --- Compare by calendar date only — on Faire start day we want *next* month, not “today”.
  local nowKey = dateKey(now)
  local year, month = now.year, now.month
  for _ = 1, 14 do
    local sunDay = firstSundayDayOfMonth(year, month)
    if sunDay then
      local ct = makeCalendarTime(year, month, sunDay, 0, 0)
      if dateKey(ct) > nowKey then
        return ct
      end
    end
    year, month = advanceCalendarMonth(year, month)
  end
  return nil
end

local function playerAtDarkmoonIsland()
  local mapId = C_Map.GetBestMapForUnit("player")
  if not mapId then
    return false
  end
  if mapId == DARKMOON_OVERVIEW_UIMAP then
    return true
  end
  if C_Map and C_Map.GetMapInfo then
    local ok, info = pcall(C_Map.GetMapInfo, mapId)
    if ok and type(info) == "table" and info.parentMapID == DARKMOON_OVERVIEW_UIMAP then
      return true
    end
  end
  return false
end

function Calendar:RefreshActiveState()
  self._hasRefreshedStateOnce = true

  if playerAtDarkmoonIsland() then
    self.active = true
    return
  end

  local now = getCurrentCalendarTime()
  self.active = now and isDarkmoonFaireWeek(now) or false
end

function Calendar:ScheduleRefresh(delay)
  if self._pendingTimer then
    self._pendingTimer:Cancel()
    self._pendingTimer = nil
  end
  self._pendingTimer = C_Timer.NewTimer(delay or 0.2, function()
    self._pendingTimer = nil
    self:RefreshActiveState()
    if addon.UI and addon.UI.mainFrame and addon.UI.mainFrame:IsShown() then
      addon.UI:Refresh()
    end
    if addon.Minimap and addon.Minimap.RefreshTooltip then
      addon.Minimap:RefreshTooltip()
    end
  end)
end

function Calendar:Init()
  if self._inited then
    return
  end
  self._inited = true

  local f = CreateFrame("Frame")
  f:RegisterEvent("PLAYER_ENTERING_WORLD")
  f:SetScript("OnEvent", function()
    self:ScheduleRefresh(0.5)
  end)

  self:ScheduleRefresh(0)
end

--- Earliest Darkmoon Faire **start** strictly after `now` (first Sunday of the month).
function Calendar:GetNextDarkmoonStartAfterNow()
  local now = getCurrentCalendarTime()
  if not now then
    return nil
  end
  return getNextFirstSundayStartAfterNow(now)
end

function Calendar:FormatCalendarDate(ct)
  if not ct or not ct.year or not ct.month or not ct.monthDay then
    return nil
  end
  local months = {
    _G.MONTH_JANUARY,
    _G.MONTH_FEBRUARY,
    _G.MONTH_MARCH,
    _G.MONTH_APRIL,
    _G.MONTH_MAY,
    _G.MONTH_JUNE,
    _G.MONTH_JULY,
    _G.MONTH_AUGUST,
    _G.MONTH_SEPTEMBER,
    _G.MONTH_OCTOBER,
    _G.MONTH_NOVEMBER,
    _G.MONTH_DECEMBER,
  }
  local name = months[ct.month]
  if type(name) ~= "string" then
    name = tostring(ct.month)
  end
  return string.format("%s %d, %d", name, ct.monthDay, ct.year)
end

--- Dump computed schedule state for troubleshooting (`/dtdm caldebug`).
function Calendar:DumpDarkmoonCalendarDebug()
  local now = getCurrentCalendarTime()
  if not now then
    print("|cffff5555[DTD calendar]|r C_DateAndTime unavailable.")
    return
  end

  print("|cff73d7ff[DTD calendar]|r ========== Computed Darkmoon schedule ==========")
  print(("|cff73d7ff[DTD calendar]|r Now (realm): %s"):format(self:FormatCalendarDate(now) or "?"))
  print(("|cff73d7ff[DTD calendar]|r Active (computed): %s"):format(tostring(isDarkmoonFaireWeek(now))))

  local startDay = firstSundayDayOfMonth(now.year, now.month)
  if startDay then
    local weekStart = makeCalendarTime(now.year, now.month, startDay, 0, 0)
    local weekEnd = adjustCalendarTimeByDays(weekStart, DARKMOON_FAIRE_DAYS - 1)
    print(
      ("|cff73d7ff[DTD calendar]|r This month window: %s — %s"):format(
        self:FormatCalendarDate(weekStart) or "?",
        weekEnd and self:FormatCalendarDate(weekEnd) or "?"
      )
    )
  end

  local nextStart = getNextFirstSundayStartAfterNow(now)
  print(
    ("|cff73d7ff[DTD calendar]|r Next start after now: %s"):format(
      nextStart and self:FormatCalendarDate(nextStart) or "nil"
    )
  )
end

--- Human-readable next Faire start, or nil if date APIs are unavailable.
function addon:GetNextDarkmoonFaireStartDateString()
  local ct = self.Calendar:GetNextDarkmoonStartAfterNow()
  return self.Calendar:FormatCalendarDate(ct)
end

--- Recompute schedule and refresh UI (minimap / slash “refresh” entry).
function addon:InvalidateNextFaireStartCache()
  if self.Calendar and self.Calendar.ScheduleRefresh then
    self.Calendar:ScheduleRefresh(0.25)
  end
  if self.UI and self.UI.mainFrame and self.UI.mainFrame:IsShown() then
    self.UI:Refresh()
  end
  if self.Minimap and self.Minimap.RefreshTooltip then
    self.Minimap:RefreshTooltip()
  end
end

function addon:IsDarkmoonActive()
  return addon.Calendar.active == true
end
